import SwiftUI

struct GroupInfoView: View {
    @State private var group: Group
    @State private var expenses: [Expense]
    private let store: GroupStore

    init(group: Group, expenses: [Expense], store: GroupStore) {
        self._group = State(initialValue: group)
        self._expenses = State(initialValue: expenses)
        self.store = store
    }

    var body: some View {
        List {
            Section("Участники") {
                ForEach(group.members) { m in
                    Text(m.displayName)
                }
            }
            Section("Статистика") {
                HStack {
                    Text("Всего трат")
                    Spacer()
                    Text("\(group.defaultCurrency) \(totalGroup.description)")
                        .foregroundStyle(.secondary)
                }
                if let _ = group.members.first {
                    HStack {
                        Text("Мои траты")
                        Spacer()
                        Text("\(group.defaultCurrency) \(myExpenses.description)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("О группе")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: AddMembersView(group: group, store: store)) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .onAppear {
            store.subscribeGroup(groupId: group.id) { g, ex, _ in
                self.group = g
                self.expenses = ex
            }
        }
        .onDisappear { store.stopGroupSubscription() }
    }

    private var totalGroup: Decimal {
        expenses.reduce(0) { $0 + $1.amountInGroupCurrency }
    }

    private var myExpenses: Decimal {
        guard let myId = group.members.first?.id else { return 0 }
        return expenses.filter { $0.payerId == myId }
            .reduce(0) { $0 + $1.amountInGroupCurrency }
    }
}
