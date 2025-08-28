import Foundation

protocol GroupStore {
    func createGroup(name: String, defaultCurrency: String, creatorDisplayName: String) async throws -> Group
    func groups() async throws -> [Group]
    func subscribeGroup(groupId: ID, onChange: @escaping (Group, [Expense], [Payment]) -> Void)
    func stopGroupSubscription()
    func addExpense(_ e: Expense) async throws
    func updateExpense(_ e: Expense) async throws
    func addPayment(_ p: Payment) async throws
    func updatePayment(_ p: Payment) async throws
    func appendMember(groupId: ID, member: Member) async throws -> Group
    func getGroup(by id: ID) async throws -> Group?
}

protocol InviteHandling {
    func createInvite(for group: Group) async throws -> String
    func joinGroupByInvite(token: String, pickOrCreateName: String) async throws -> Group
    func buildInviteURL(token: String) async throws -> URL
}
