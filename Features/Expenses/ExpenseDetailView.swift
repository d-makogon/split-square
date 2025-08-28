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
    @State private var rateToGroup = ""
    @State private var payerId: ID = ""
    @State private var included = Set<ID>()
    @State private var splitMode: SplitMode = .equal
    @State private var manualShares: [ID: String] = [:]

    var body: some View {
        Form {
            expenseSection
            payerSection
            participantsSection
            splitSection
        }
        .navigationTitle("Трата")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { Task { await save() } }
            }
        }
        .onAppear { loadUI() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var expenseSection: some View {
        Section("Трата") {
            TextField("Название", text: $title)

            TextField("Сумма", text: $amountOriginal)
                .keyboardType(.decimalPad)

            Picker("Валюта", selection: $currency) {
                ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            // Курс нужен, если валюта отличается от валюты группы.
            // Оставим поле всегда видимым для простоты; по умолчанию = 1.
            TextField("Курс → \(group.defaultCurrency)", text: $rateToGroup)
                .keyboardType(.decimalPad)
        }
    }

    @ViewBuilder
    private var payerSection: some View {
        Section("Кто платил") {
            Picker("Плательщик", selection: $payerId) {
                ForEach(group.members, id: \.id) { m in
                    Text(m.displayName).tag(m.id)
                }
            }
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        Section("Кто участвует") {
            ForEach(group.members, id: \.id) { m in
                Toggle(
                    m.displayName,
                    isOn: Binding<Bool>(
                        get: { included.contains(m.id) },
                        set: { newValue in
                            if newValue {
                                _ = included.insert(m.id)
                            } else {
                                included.remove(m.id)
                            }
                        }
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var splitSection: some View {
        Section("Делёжка") {
            Picker("Способ", selection: $splitMode) {
                Text("Поровну").tag(SplitMode.equal)
                Text("По суммам").tag(SplitMode.manual)
            }
            .pickerStyle(.segmented)

            if splitMode == .manual {
                let chosen = group.members.filter { included.contains($0.id) }
                ForEach(chosen, id: \.id) { m in
                    TextField(
                        m.displayName,
                        text: Binding<String>(
                            get: { manualShares[m.id, default: ""] },
                            set: { manualShares[m.id] = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                }
            }
        }
    }

    // MARK: - Logic

    private func loadUI() {
        title = expense.title
        amountOriginal = expense.amountOriginal.description
        currency = expense.currencyOriginal
        rateToGroup = ""  // при необходимости введёт пользователь; по умолчанию 1
        payerId = expense.payerId
        included = Set(expense.includedMemberIds)
        splitMode = expense.splitMode
        manualShares = expense.manualShares?.mapValues { $0.description } ?? [:]
    }

    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal), !title.isEmpty else { return }
        let rate = Decimal(string: rateToGroup) ?? 1
        let aGroup = rounded(aOrig * rate, currencyCode: group.defaultCurrency)

        var manual: [ID: Decimal]? = nil
        if splitMode == .manual {
            var tmp: [ID: Decimal] = [:]
            for id in included {
                if let s = manualShares[id], let v = Decimal(string: s) {
                    tmp[id] = rounded(v, currencyCode: group.defaultCurrency)
                }
            }
            manual = tmp
        }

        var e = expense
        e.title = title
        e.amountOriginal = aOrig
        e.currencyOriginal = currency
        e.amountInGroupCurrency = aGroup
        e.payerId = payerId
        e.includedMemberIds = Array(included)
        e.splitMode = splitMode
        e.manualShares = manual
        e.updatedAt = Date()

        do {
            try await store.updateExpense(e)
            await MainActor.run { dismiss() }
        } catch {
            // Можно показать alert по желанию
        }
    }
}
