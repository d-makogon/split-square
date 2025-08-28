import Foundation

#if canImport(FirebaseFirestore) && canImport(FirebaseDynamicLinks) && canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseFirestore
import FirebaseDynamicLinks
import FirebaseFirestoreSwift
#endif

final class InviteService: InviteHandling {
    private let store: GroupStore

    init(store: GroupStore) {
        self.store = store
    }

    func createInvite(for group: Group) async throws -> String {
        #if canImport(FirebaseFirestore)
        // Сохраняем токен в /invites, включено если Firebase добавлен
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        struct Invite: Codable { var token: String; var groupId: ID; var createdAt: Date; var isActive: Bool }
        let db = Firestore.firestore()
        let inv = Invite(token: token, groupId: group.id, createdAt: Date(), isActive: true)
        try db.collection("invites").document(token).setData(from: inv)
        try db.collection("groups").document(group.id).setData(["activeInviteToken": token], merge: true)
        return token
        #else
        // Локальный режим — просто генерируем токен (не шарится между устройствами)
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        #endif
    }

    func joinGroupByInvite(token: String, pickOrCreateName: String) async throws -> Group {
        #if canImport(FirebaseFirestore)
        struct Invite: Codable { var token: String; var groupId: ID; var createdAt: Date; var isActive: Bool }
        let db = Firestore.firestore()
        let invRef = db.collection("invites").document(token)
        guard let inv = try await invRef.getDocument().data().flatMap({ try? Firestore.Decoder().decode(Invite.self, from: $0) }),
              inv.isActive else { throw NSError(domain: "invite", code: 404) }
        let member = Member(id: Auth.auth().currentUser?.uid ?? UUID().uuidString, displayName: pickOrCreateName)
        let g = try await store.appendMember(groupId: inv.groupId, member: member)
        return g
        #else
        // Локальный режим — требуем, чтобы группа уже была открыта на этом устройстве
        guard let g = try await store.groups().first else { throw NSError(domain: "local", code: 1) }
        _ = try await store.appendMember(groupId: g.id, member: Member(id: UUID().uuidString, displayName: pickOrCreateName))
        return g
        #endif
    }

    func buildInviteURL(token: String) async throws -> URL {
        #if canImport(FirebaseDynamicLinks)
        let link = URL(string: "https://splitsq.app/invite?token=\(token)")!
        let domain = "https://splitsqapp.page.link"
        guard let comps = DynamicLinkComponents(link: link, domainURIPrefix: domain) else { throw URLError(.badURL) }
        comps.iOSParameters = DynamicLinkIOSParameters(bundleID: Bundle.main.bundleIdentifier ?? "")
        comps.socialMetaTagParameters = DynamicLinkSocialMetaTagParameters()
        comps.socialMetaTagParameters?.title = "Приглашение в SplitSquare"
        let (shortURL, _, _) = try await comps.shorten()
        return shortURL
        #else
        // Локально — обычный URL
        return URL(string: "https://splitsq.app/invite?token=\(token)")!
        #endif
    }
}
