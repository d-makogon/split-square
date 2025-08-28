import SwiftUI

struct SettlementsView: View {
    let group: Group
    let expenses: [Expense]
    let payments: [Payment]

    var body: some View {
        let balances = computeBalances(groupCurrency: group.defaultCurrency,
                                       members: group.members,
                                       expenses: expenses,
                                       payments: payments)
        let transfers = minimizeTransfers(balances: balances, currencyCode: group.defaultCurrency)

        List {
            Section("Баланс") {
                ForEach(group.members) { m in
                    let v = balances[m.id] ?? 0
                    HStack {
                        Text(m.displayName)
                        Spacer()
                        Text("\(group.defaultCurrency) \(v.description)")
                            .foregroundStyle(v > 0 ? .green : (v < 0 ? .red : .secondary))
                    }
                }
            }
            Section("Предлагаемые переводы") {
                if transfers.isEmpty {
                    Text("Все рассчитано, переводы не требуются.")
                } else {
                    ForEach(transfers) { t in
                        HStack {
                            Text("\(name(of: t.from)) → \(name(of: t.to))")
                            Spacer()
                            Text("\(group.defaultCurrency) \(t.amount.description)").bold()
                        }
                    }
                }
            }
        }
        .navigationTitle("Выплаты")
    }

    private func name(of id: ID) -> String {
        group.members.first(where: { $0.id == id })?.displayName ?? "?"
    }
}
