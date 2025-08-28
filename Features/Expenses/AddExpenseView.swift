import SwiftUI

struct AddExpenseView: View {
    let group: Group
    let store: GroupStore
    
    @State private var title = ""
    @State private var amountOriginal = ""
    @State private var currency = ""
    @State private var rateToGroup = ""
    @State private var payerId: ID = ""
    @State private var included = Set<ID>()
    @State private var splitMode: SplitMode = .equal
    @State private var manualShares: [ID: String] = [:]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            expenseSection
            payerSection
            participantsSection
            splitSection
        }
        .onAppear {
            currency = group.defaultCurrency
            if let me = group.members.first { payerId = me.id }
            included = Set(group.members.map(\.id))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { Task { await save() } }
                    .disabled(title.isEmpty || Decimal(string: amountOriginal) == nil)
            }
        }
        .navigationTitle("Добавить трату")
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var expenseSection: some View {
        Section("Трата") {
            TextField("Название", text: $title)
            
            TextField("Сумма", text: $amountOriginal)
                .keyboardType(.decimalPad)
            
            Picker("Валюта", selection: $currency) {
                ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0).tag($0) }
            }
            
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
    
    // MARK: - Save
    
    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal) else { return }
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
        
        let exp = Expense(
            id: UUID().uuidString,
            groupId: group.id,
            title: title,
            amountOriginal: aOrig,
            currencyOriginal: currency,
            amountInGroupCurrency: aGroup,
            payerId: payerId,
            includedMemberIds: Array(included),
            splitMode: splitMode,
            manualShares: manual,
            createdAt: Date(),
            updatedAt: nil
        )
        do {
            try await store.addExpense(exp)
            await MainActor.run { dismiss() }
        } catch {
            // можно показать alert
        }
    }
}
