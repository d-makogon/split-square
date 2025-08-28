import Foundation

/// Простое локальное (in-memory) хранилище — для оффлайн и демо
final class LocalStore: GroupStore {
    private var groupsMap: [ID: Group] = [:]
    private var expensesMap: [ID: [Expense]] = [:]
    private var paymentsMap: [ID: [Payment]] = [:]
    private var onChange: ((Group, [Expense], [Payment]) -> Void)?
    private var subscribedGroupId: ID?

    init() {
        // демо-группа
        let gid = UUID().uuidString
        let me = Member(id: UUID().uuidString, displayName: "You")
        let g = Group(id: gid, name: "Demo", defaultCurrency: "EUR", members: [me], activeInviteToken: nil, createdAt: Date())
        groupsMap[gid] = g
        expensesMap[gid] = []
        paymentsMap[gid] = []
    }

    func createGroup(name: String, defaultCurrency: String, creatorDisplayName: String) async throws -> Group {
        let gid = UUID().uuidString
        let me = Member(id: UUID().uuidString, displayName: creatorDisplayName)
        let group = Group(id: gid, name: name, defaultCurrency: defaultCurrency, members: [me], activeInviteToken: nil, createdAt: Date())
        groupsMap[gid] = group
        expensesMap[gid] = []
        paymentsMap[gid] = []
        return group
    }

    func groups() async throws -> [Group] {
        return Array(groupsMap.values).sorted(by: { $0.createdAt < $1.createdAt })
    }

    func subscribeGroup(groupId: ID, onChange: @escaping (Group, [Expense], [Payment]) -> Void) {
        self.onChange = onChange
        self.subscribedGroupId = groupId
        if let g = groupsMap[groupId] {
            onChange(g, expensesMap[groupId] ?? [], paymentsMap[groupId] ?? [])
        }
    }

    func stopGroupSubscription() { onChange = nil; subscribedGroupId = nil }

    func addExpense(_ e: Expense) async throws {
        expensesMap[e.groupId, default: []].insert(e, at: 0)
        if let g = groupsMap[e.groupId] { onChange?(g, expensesMap[e.groupId] ?? [], paymentsMap[e.groupId] ?? []) }
    }

    func updateExpense(_ e: Expense) async throws {
        guard var arr = expensesMap[e.groupId] else { return }
        if let idx = arr.firstIndex(where: { $0.id == e.id }) {
            arr[idx] = e
            expensesMap[e.groupId] = arr
            if let g = groupsMap[e.groupId] { onChange?(g, arr, paymentsMap[e.groupId] ?? []) }
        }
    }

    func addPayment(_ p: Payment) async throws {
        paymentsMap[p.groupId, default: []].insert(p, at: 0)
        if let g = groupsMap[p.groupId] { onChange?(g, expensesMap[p.groupId] ?? [], paymentsMap[p.groupId] ?? []) }
    }

    func appendMember(groupId: ID, member: Member) async throws -> Group {
        guard var g = groupsMap[groupId] else { throw NSError(domain: "group", code: 404) }
        g.members.append(member)
        groupsMap[groupId] = g
        onChange?(g, expensesMap[groupId] ?? [], paymentsMap[groupId] ?? [])
        return g
    }

    func getGroup(by id: ID) async throws -> Group? {
        groupsMap[id]
    }
}
