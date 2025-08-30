import SwiftUI

struct AddPaymentView: View {
    let group: Group
    let store: GroupStore

    @State private var title = ""
    @State private var amountOriginal = ""
    @State private var currency = ""
    @State private var rateToGroup = ""
    @State private var recipientId: ID = ""
    @State private var contributions: [ID: String] = [:]
    @State private var showDistributionAlert = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Выплата") {
                TextField("Название", text: $title)
                TextField("Сумма", text: $amountOriginal).keyboardType(.decimalPad)
                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0) }
                }
                TextField("Курс → \(group.defaultCurrency)", text: $rateToGroup)
                    .keyboardType(.decimalPad)
                    .disabled(currency == group.defaultCurrency)
            }
            Section("Получатель") {
                Picker("Кому перевели", selection: $recipientId) {
                    ForEach(group.members) { m in Text(m.displayName).tag(m.id) }
                }
            }
            Section("Кто платил (и сколько)") {
                ForEach(group.members) { m in
                    TextField(m.displayName, text: Binding(
                        get: { contributions[m.id, default: ""] },
                        set: { contributions[m.id] = $0 }
                    )).keyboardType(.decimalPad)
                }
            }
        }
        .onAppear {
            currency = group.defaultCurrency
            rateToGroup = "1"
            if let r = group.members.first { recipientId = r.id }
        }
        .onChange(of: currency) { _, new in
            if new == group.defaultCurrency {
                rateToGroup = "1"
            } else if rateToGroup == "1" {
                rateToGroup = ""
            }
        }
        .navigationTitle("Добавить выплату")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { Task { await save() } }
                    .disabled(title.isEmpty || Decimal(string: amountOriginal) == nil)
            }
        }
        .alert("Не все деньги распределены", isPresented: $showDistributionAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal) else { return }
        let rate = Decimal(string: rateToGroup) ?? 1
        let aGroup = rounded(aOrig * rate, currencyCode: group.defaultCurrency)
        var map: [ID: Decimal] = [:]
        for (id, s) in contributions {
            if let d = Decimal(string: s), d > 0 {
                map[id] = rounded(d * rate, currencyCode: group.defaultCurrency)
            }
        }
        let sum = map.values.reduce(0, +)
        if sum != aGroup {
            showDistributionAlert = true
            return
        }
        let pay = Payment(
            id: UUID().uuidString,
            groupId: group.id,
            title: title,
            amountOriginal: aOrig,
            currencyOriginal: currency,
            amountInGroupCurrency: aGroup,
            recipientId: recipientId,
            splitMode: .manual,
            contributions: map,
            createdAt: Date(),
            updatedAt: nil
        )
        do {
            try await store.addPayment(pay)
            await MainActor.run { dismiss() }
        } catch { }
    }
}
