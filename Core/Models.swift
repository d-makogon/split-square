import Foundation

public typealias ID = String

public struct Member: Identifiable, Codable, Hashable {
    public var id: ID
    public var displayName: String

    public init(id: ID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct Group: Identifiable, Codable {
    public var id: ID
    public var name: String
    public var defaultCurrency: String
    public var members: [Member]
    public var activeInviteToken: String?
    public var createdAt: Date

    public init(id: ID, name: String, defaultCurrency: String, members: [Member], activeInviteToken: String?, createdAt: Date) {
        self.id = id; self.name = name; self.defaultCurrency = defaultCurrency
        self.members = members; self.activeInviteToken = activeInviteToken; self.createdAt = createdAt
    }
}

public enum SplitMode: String, Codable { case equal, manual }

public struct Expense: Identifiable, Codable {
    public var id: ID
    public var groupId: ID
    public var title: String
    public var amountOriginal: Decimal
    public var currencyOriginal: String
    public var amountInGroupCurrency: Decimal
    public var payerId: ID
    public var includedMemberIds: [ID]
    public var splitMode: SplitMode
    public var manualShares: [ID: Decimal]?
    public var createdAt: Date
    public var updatedAt: Date?

    public init(id: ID, groupId: ID, title: String, amountOriginal: Decimal, currencyOriginal: String,
                amountInGroupCurrency: Decimal, payerId: ID, includedMemberIds: [ID],
                splitMode: SplitMode, manualShares: [ID: Decimal]?, createdAt: Date, updatedAt: Date?) {
        self.id = id; self.groupId = groupId; self.title = title
        self.amountOriginal = amountOriginal; self.currencyOriginal = currencyOriginal
        self.amountInGroupCurrency = amountInGroupCurrency; self.payerId = payerId
        self.includedMemberIds = includedMemberIds; self.splitMode = splitMode
        self.manualShares = manualShares; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct Payment: Identifiable, Codable {
    public var id: ID
    public var groupId: ID
    public var title: String
    public var amountOriginal: Decimal
    public var currencyOriginal: String
    public var amountInGroupCurrency: Decimal
    public var recipientId: ID
    public var splitMode: SplitMode = .manual
    public var contributions: [ID: Decimal]
    public var createdAt: Date
    public var updatedAt: Date?

    public init(id: ID, groupId: ID, title: String, amountOriginal: Decimal, currencyOriginal: String,
                amountInGroupCurrency: Decimal, recipientId: ID, splitMode: SplitMode, contributions: [ID: Decimal], createdAt: Date, updatedAt: Date?) {
        self.id = id; self.groupId = groupId; self.title = title
        self.amountOriginal = amountOriginal; self.currencyOriginal = currencyOriginal
        self.amountInGroupCurrency = amountInGroupCurrency; self.recipientId = recipientId
        self.splitMode = splitMode
        self.contributions = contributions; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
