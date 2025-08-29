import SwiftUI

struct ExpenseDetailView: View {
    @State var expense: Expense
    let store: GroupStore
    let group: Group
    @Environment(\.dismiss) var dismiss

    // UI state
    @State private var title = ""
    @State private var amountOriginal = ""
    @State private var currency = ""
    @State private var rateToGroup = "" // теперь показываем вычисленный курс
    @State private var payerId: ID = ""
    @State private var included = Set<ID>()
    @State private var splitMode: SplitMode = .equal
    @State private var manualShares: [ID: String] = [:]
    @State private var showDistributionAlert = false

    var body: some View {
        Form {
            Section("Трата") {
                TextField("Название", text: $title)
                TextField("Сумма", text: $amountOriginal).keyboardType(.decimalPad)
                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0).tag($0) }
                }
                TextField("Курс → \(group.defaultCurrency)", text: $rateToGroup)
                    .keyboardType(.decimalPad)
                    .disabled(currency == group.defaultCurrency)
            }
            Section("Кто платил") {
                Picker("Плательщик", selection: $payerId) {
                    ForEach(group.members, id: \.id) { m in
                        Text(m.displayName).tag(m.id)
                    }
                }
            }
            Section("Кто участвует") {
                ForEach(group.members, id: \.id) { m in
                    Toggle(
                        m.displayName,
                        isOn: Binding<Bool>(
                            get: { included.contains(m.id) },
                            set: { newValue in
                                if newValue { _ = included.insert(m.id) }
                                else { included.remove(m.id) }
                            }
                        )
                    )
                }
            }
            Section("Делёжка") {
                Picker("Способ", selection: $splitMode) {
                    Text("Поровну").tag(SplitMode.equal)
                    Text("По суммам").tag(SplitMode.manual)
                }
                .pickerStyle(.segmented)

                let ids = group.members.filter { included.contains($0.id) }
                if splitMode == .equal {
                    let totalGroup = totalInGroup()
                    let shares = equalize(total: totalGroup, ids: ids.map(\.id))
                    ForEach(ids, id: \.id) { m in
                        HStack {
                            Text(m.displayName)
                            Spacer()
                            Text("\(group.defaultCurrency) \(shares[m.id]?.description ?? "0")")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(ids, id: \.id) { m in
                        HStack {
                            Text(m.displayName)
                            TextField("0", text: Binding<String>(
                                get: { manualShares[m.id, default: ""] },
                                set: { manualShares[m.id] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            Text(group.defaultCurrency).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Трата")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { Task { await save() } }
            }
        }
        .onAppear { loadUI() }
        .onChange(of: currency) { _, new in
            if new == group.defaultCurrency {
                rateToGroup = "1"
            } else if rateToGroup == "1" {
                rateToGroup = ""
            }
        }
        .alert("Не все деньги распределены", isPresented: $showDistributionAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func loadUI() {
        title = expense.title
        amountOriginal = expense.amountOriginal.description
        currency = expense.currencyOriginal
        // Показать курс, вычислив из сохранённых сумм (п.5)
        if expense.amountOriginal != 0 {
            let r = expense.amountInGroupCurrency / expense.amountOriginal
            rateToGroup = (currency == group.defaultCurrency ? "1" : r.description)
        } else {
            rateToGroup = currency == group.defaultCurrency ? "1" : ""
        }
        payerId = expense.payerId
        included = Set(expense.includedMemberIds)
        splitMode = expense.manualShares == nil ? .equal : .manual
        manualShares = expense.manualShares?.mapValues { $0.description } ?? [:]
    }

    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal), !title.isEmpty else { return }
        let rate = Decimal(string: rateToGroup) ?? 1
        let totalGroup = rounded(aOrig * rate, currencyCode: group.defaultCurrency)

        let ids = group.members.filter { included.contains($0.id) }.map(\.id)
        var manual: [ID: Decimal]? = nil
        if splitMode == .manual {
            var tmp: [ID: Decimal] = [:]
            for id in ids {
                if let s = manualShares[id], let v = Decimal(string: s) {
                    tmp[id] = rounded(v, currencyCode: group.defaultCurrency)
                }
            }
            let sum = tmp.values.reduce(0, +)
            if sum != totalGroup {
                showDistributionAlert = true
                return
            }
            manual = tmp
        }

        var e = expense
        e.title = title
        e.amountOriginal = aOrig
        e.currencyOriginal = currency
        e.amountInGroupCurrency = totalGroup
        e.payerId = payerId
        e.includedMemberIds = ids
        e.splitMode = splitMode
        e.manualShares = manual
        e.updatedAt = Date()

        do {
            try await store.updateExpense(e)
            await MainActor.run { dismiss() }
        } catch { }
    }

    private func totalInGroup() -> Decimal {
        guard let aOrig = Decimal(string: amountOriginal) else { return 0 }
        let rate = Decimal(string: rateToGroup) ?? 1
        return rounded(aOrig * rate, currencyCode: group.defaultCurrency)
    }

    private func equalize(total: Decimal, ids: [ID]) -> [ID: Decimal] {
        guard !ids.isEmpty else { return [:] }
        let n = Decimal(ids.count)
        let each = rounded(total / n, currencyCode: group.defaultCurrency)
        var res = Dictionary(uniqueKeysWithValues: ids.map { ($0, each) })
        let sum = res.values.reduce(0, +)
        let diff = rounded(total - sum, currencyCode: group.defaultCurrency)
        if let first = ids.first, diff != 0 {
            res[first] = rounded((res[first] ?? 0) + diff, currencyCode: group.defaultCurrency)
        }
        return res
    }

}
