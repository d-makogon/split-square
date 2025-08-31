import SwiftUI

struct PaymentDetailView: View {
    @State var payment: Payment
    let store: GroupStore
    let group: Group
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var amountOriginal = ""
    @State private var currency = ""
    @State private var rateToGroup = "" // показываем/редактируем
    @State private var recipientId: ID = ""
    @State private var included = Set<ID>()
    @State private var splitMode: SplitMode = .equal
    @State private var manualShares: [ID: String] = [:]
    @State private var showDistributionAlert = false

    var body: some View {
        Form {
            Section("Выплата") {
                TextField("Название", text: $title)
                TextField("Сумма", text: $amountOriginal).keyboardType(.decimalPad)
                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0).tag($0) }
                }
                TextField("Курс → \(group.defaultCurrency)", text: $rateToGroup)
                    .keyboardType(.decimalPad)
                    .disabled(currency == group.defaultCurrency)
            }
            Section("Получатель") {
                Picker("Кому перевели", selection: $recipientId) {
                    ForEach(group.members, id: \.id) { m in Text(m.displayName).tag(m.id) }
                }
                .onChange(of: recipientId) { _, new in included.remove(new) }
            }
            Section("Кто переводил") {
                ForEach(group.members, id: \.id) { m in
                    Toggle(
                        m.displayName,
                        isOn: Binding<Bool>(
                            get: { m.id == recipientId ? false : included.contains(m.id) },
                            set: { newValue in
                                guard m.id != recipientId else { return }
                                if newValue { _ = included.insert(m.id) }
                                else { included.remove(m.id) }
                            }
                        )
                    )
                    .disabled(m.id == recipientId)
                }
            }
            Section("Разбиение перевода") {
                Picker("Способ", selection: $splitMode) {
                    Text("Поровну").tag(SplitMode.equal)
                    Text("По суммам").tag(SplitMode.manual)
                }
                .pickerStyle(.segmented)

                let ids = group.members.filter { included.contains($0.id) && $0.id != recipientId }

                if splitMode == .equal {
                    let (shareMap, _) = equalSharesPreview(totalInGroupCurrency: totalInGroup(), ids: ids.map(\.id))
                    ForEach(ids, id: \.id) { m in
                        HStack {
                            Text(m.displayName)
                            Spacer()
                            Text("\(group.defaultCurrency) \(shareMap[m.id]?.description ?? "0")")
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
                    manualSumHint(current: manualShares, ids: ids.map(\.id))
                }
            }
        }
        .navigationTitle("Выплата")
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
        title = payment.title
        amountOriginal = payment.amountOriginal.description
        currency = payment.currencyOriginal
        // Вычисляем курс из сохранённых величин (п.5)
        if payment.amountOriginal != 0 {
            let r = payment.amountInGroupCurrency / payment.amountOriginal
            rateToGroup = (currency == group.defaultCurrency ? "1" : r.description)
        } else {
            rateToGroup = currency == group.defaultCurrency ? "1" : ""
        }
        recipientId = payment.recipientId
        included = Set(payment.contributions.keys)
        splitMode = payment.splitMode
        manualShares = payment.splitMode == .manual ? payment.contributions.mapValues { $0.description } : [:]
    }

    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal), !title.isEmpty else { return }
        let rate = Decimal(string: rateToGroup) ?? 1
        let totalGroup = rounded(aOrig * rate, currencyCode: group.defaultCurrency)

        let ids = group.members
            .filter { included.contains($0.id) && $0.id != recipientId }
            .map(\.id)

        var contribs: [ID: Decimal]
        if splitMode == .equal {
            contribs = equalize(total: totalGroup, ids: ids)
        } else {
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
            contribs = tmp
        }

        var p = payment
        p.title = title
        p.amountOriginal = aOrig
        p.currencyOriginal = currency
        p.amountInGroupCurrency = totalGroup
        p.recipientId = recipientId
        p.splitMode = splitMode
        p.contributions = contribs
        p.updatedAt = Date()

        do {
            try await store.updatePayment(p)
            await MainActor.run { dismiss() }
        } catch { }
    }

    // Helpers (те же, что в AddTransactionView)
    private func totalInGroup() -> Decimal {
        guard let aOrig = Decimal(string: amountOriginal) else { return 0 }
        let rate = Decimal(string: rateToGroup) ?? 1
        return rounded(aOrig * rate, currencyCode: group.defaultCurrency)
    }

    private func equalSharesPreview(totalInGroupCurrency: Decimal, ids: [ID]) -> ([ID: Decimal], Decimal) {
        let map = equalize(total: totalInGroupCurrency, ids: ids)
        return (map, map.values.reduce(0, +))
    }

    private func equalize(total: Decimal, ids: [ID]) -> [ID: Decimal] {
        guard !ids.isEmpty else { return [:] }
        let n = Decimal(ids.count)
        let raw = total / n
        let each = rounded(raw, currencyCode: group.defaultCurrency)
        var res = Dictionary(uniqueKeysWithValues: ids.map { ($0, each) })
        let sum = res.values.reduce(0, +)
        let diff = rounded(total - sum, currencyCode: group.defaultCurrency)
        if let first = ids.first, diff != 0 {
            res[first] = rounded((res[first] ?? 0) + diff, currencyCode: group.defaultCurrency)
        }
        return res
    }


    @ViewBuilder
    private func manualSumHint(current: [ID: String], ids: [ID]) -> some View {
        let vals = ids.compactMap { id in Decimal(string: current[id] ?? "") }
        let curSum = vals.reduce(0, +)
        let target = totalInGroup()
        let delta = rounded(target - curSum, currencyCode: group.defaultCurrency)
        if delta != 0 {
            HStack {
                Text("Осталось распределить:")
                Spacer()
                Text("\(group.defaultCurrency) \(delta.description)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
