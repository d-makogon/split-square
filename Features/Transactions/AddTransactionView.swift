import SwiftUI

enum TransactionKind: String, CaseIterable, Identifiable {
    case expense = "Трата"
    case payment = "Выплата"
    var id: String { rawValue }
}

struct AddTransactionView: View {
    let group: Group
    let store: GroupStore
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Общие поля
    @State private var kind: TransactionKind = .expense
    @State private var title = ""
    @State private var amountOriginal = ""
    @State private var currency = ""
    @State private var rateToGroup = "" // хранится как число; при редактировании — показываем

    // Expense
    @State private var payerId: ID = ""
    @State private var includedExpense = Set<ID>()  // кто участвует в делёжке
    @State private var splitModeExpense: SplitMode = .equal
    @State private var manualSharesExpense: [ID: String] = [:] // в валюте группы

    // Payment
    @State private var recipientId: ID = ""
    @State private var includedPayment = Set<ID>() // кто переводил (плательщики)
    @State private var splitModePayment: SplitMode = .equal
    @State private var manualSharesPayment: [ID: String] = [:] // в валюте группы

    var body: some View {
        Form {
            // Переключатель «Трата / Выплата» во всю ширину
            Section {
                Picker("", selection: $kind) {
                    ForEach(TransactionKind.allCases) { k in
                        Text(k.rawValue).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            commonSection

            if kind == .expense {
                expenseSection
                splitExpenseSection
            } else {
                paymentSection
                splitPaymentSection
            }

            Section {
                Button("Добавить") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear {
            currency = group.defaultCurrency
            if let first = group.members.first?.id {
                payerId = first
                recipientId = first
            }
            includedExpense = Set(group.members.map(\.id))
            includedPayment = Set(group.members.map(\.id))
            // по выплатам — по умолчанию исключим получателя из плательщиков
            if let r = group.members.first { includedPayment.remove(r.id) }
        }
        .navigationTitle("Новая запись")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        }
    }

    // MARK: - Общие поля

    @ViewBuilder private var commonSection: some View {
        Section("Общее") {
            TextField("Название", text: $title)
            TextField("Сумма", text: $amountOriginal).keyboardType(.decimalPad)
            Picker("Валюта", selection: $currency) {
                ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0).tag($0) }
            }
            TextField("Курс → \(group.defaultCurrency)", text: $rateToGroup).keyboardType(.decimalPad)
        }
    }

    // MARK: - Expense

    @ViewBuilder private var expenseSection: some View {
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
                        get: { includedExpense.contains(m.id) },
                        set: { newValue in
                            if newValue { _ = includedExpense.insert(m.id) }
                            else { includedExpense.remove(m.id) }
                        }
                    )
                )
            }
        }
    }

    @ViewBuilder private var splitExpenseSection: some View {
        Section("Делёжка") {
            Picker("Способ", selection: $splitModeExpense) {
                Text("Поровну").tag(SplitMode.equal)
                Text("По суммам").tag(SplitMode.manual)
            }
            .pickerStyle(.segmented)

            let ids = group.members.filter { includedExpense.contains($0.id) }

            if splitModeExpense == .equal {
                // Всегда показываем имя + сумму
                let (shareMap, _) = equalSharesPreview(totalInGroupCurrency: totalInGroup(), ids: ids.map(\.id))
                ForEach(ids, id: \.id) { m in
                    HStack {
                        Text(m.displayName)
                        Spacer()
                        Text("\(group.defaultCurrency) \(shareMap[m.id]?.description ?? "0")")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(ids, id: \.id) { m in
                    HStack {
                        Text(m.displayName)
                        TextField("0", text: Binding<String>(
                            get: { manualSharesExpense[m.id, default: ""] },
                            set: { manualSharesExpense[m.id] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        Text(group.defaultCurrency).foregroundStyle(.secondary)
                    }
                }
                manualSumHint(current: manualSharesExpense, ids: ids.map(\.id))
            }
        }
    }

    // MARK: - Payment

    @ViewBuilder private var paymentSection: some View {
        Section("Получатель") {
            Picker("Кому перевели", selection: $recipientId) {
                ForEach(group.members, id: \.id) { m in
                    Text(m.displayName).tag(m.id)
                }
            }
            .onChange(of: recipientId) { _, new in
                // получатель не должен быть в списке плательщиков
                includedPayment.remove(new)
            }
        }
        Section("Кто переводил") {
            ForEach(group.members, id: \.id) { m in
                Toggle(
                    m.displayName,
                    isOn: Binding<Bool>(
                        get: { m.id == recipientId ? false : includedPayment.contains(m.id) },
                        set: { newValue in
                            guard m.id != recipientId else { return }
                            if newValue { _ = includedPayment.insert(m.id) }
                            else { includedPayment.remove(m.id) }
                        }
                    )
                )
                .disabled(m.id == recipientId)
            }
        }
    }

    @ViewBuilder private var splitPaymentSection: some View {
        Section("Разбиение перевода") {
            Picker("Способ", selection: $splitModePayment) {
                Text("Поровну").tag(SplitMode.equal)
                Text("По суммам").tag(SplitMode.manual)
            }
            .pickerStyle(.segmented)

            let ids = group.members.filter { includedPayment.contains($0.id) && $0.id != recipientId }

            if splitModePayment == .equal {
                let (shareMap, _) = equalSharesPreview(totalInGroupCurrency: totalInGroup(), ids: ids.map(\.id))
                ForEach(ids, id: \.id) { m in
                    HStack {
                        Text(m.displayName)
                        Spacer()
                        Text("\(group.defaultCurrency) \(shareMap[m.id]?.description ?? "0")")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(ids, id: \.id) { m in
                    HStack {
                        Text(m.displayName)
                        TextField("0", text: Binding<String>(
                            get: { manualSharesPayment[m.id, default: ""] },
                            set: { manualSharesPayment[m.id] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        Text(group.defaultCurrency).foregroundStyle(.secondary)
                    }
                }
                manualSumHint(current: manualSharesPayment, ids: ids.map(\.id))
            }
        }
    }

    // MARK: - Save

    private func save() async {
        guard let aOrig = Decimal(string: amountOriginal), !title.isEmpty else { return }
        let rate = Decimal(string: rateToGroup) ?? 1
        let amountGroup = rounded(aOrig * rate, currencyCode: group.defaultCurrency)

        switch kind {
        case .expense:
            // Подготовим доли
            let ids = group.members.filter { includedExpense.contains($0.id) }.map(\.id)
            var shares: [ID: Decimal] = [:]
            if splitModeExpense == .equal {
                shares = equalize(total: amountGroup, ids: ids)
            } else {
                shares = normalizeManual(total: amountGroup, raw: manualSharesExpense, ids: ids)
            }
            let e = Expense(
                id: UUID().uuidString,
                groupId: group.id,
                title: title,
                amountOriginal: aOrig,
                currencyOriginal: currency,
                amountInGroupCurrency: amountGroup,
                payerId: payerId,
                includedMemberIds: ids,
                splitMode: splitModeExpense,
                manualShares: shares,
                createdAt: Date(),
                updatedAt: nil
            )
            try? await store.addExpense(e)

        case .payment:
            // Плательщики и суммы
            let ids = group.members
                .filter { includedPayment.contains($0.id) && $0.id != recipientId }
                .map(\.id)
            var contribs: [ID: Decimal] = [:]
            if splitModePayment == .equal {
                contribs = equalize(total: amountGroup, ids: ids)
            } else {
                contribs = normalizeManual(total: amountGroup, raw: manualSharesPayment, ids: ids)
            }
            // Создаём выплату: получатель +, плательщики −
            let p = Payment(
                id: UUID().uuidString,
                groupId: group.id,
                title: title,
                amountOriginal: aOrig,
                currencyOriginal: currency,
                amountInGroupCurrency: amountGroup,
                recipientId: recipientId,
                contributions: contribs,
                createdAt: Date(),
                updatedAt: nil
            )
            try? await store.addPayment(p)
        }

        await MainActor.run {
            onDone()
            dismiss()
        }
    }

    // MARK: - Helpers

    private func totalInGroup() -> Decimal {
        // используем курс для превью
        guard let aOrig = Decimal(string: amountOriginal) else { return 0 }
        let rate = Decimal(string: rateToGroup) ?? 1
        return rounded(aOrig * rate, currencyCode: group.defaultCurrency)
    }

    /// Предпросмотр долей для equal (с суммой, подогнанной к total)
    private func equalSharesPreview(totalInGroupCurrency: Decimal, ids: [ID]) -> ([ID: Decimal], Decimal) {
        let map = equalize(total: totalInGroupCurrency, ids: ids)
        let sum = map.values.reduce(0, +)
        return (map, sum)
    }

    /// Делим поровну, корректируя последнего на копеечную разницу
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

    /// Нормализуем ручные суммы так, чтобы итог совпал с total (фикс п.1 — исключает «+2000»)
    private func normalizeManual(total: Decimal, raw: [ID: String], ids: [ID]) -> [ID: Decimal] {
        var res: [ID: Decimal] = [:]
        for id in ids {
            if let s = raw[id], let v = Decimal(string: s) {
                res[id] = rounded(v, currencyCode: group.defaultCurrency)
            }
        }
        // если пусто — fallback на equal
        if res.isEmpty { return equalize(total: total, ids: ids) }
        // Подгонка суммы
        let sum = res.values.reduce(0, +)
        let diff = rounded(total - sum, currencyCode: group.defaultCurrency)
        if diff != 0, let first = ids.first {
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
