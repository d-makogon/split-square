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
    
    // ─────────────────────────────────────────────────────────────
    // 1) Создание инвайта (как было)
    // ─────────────────────────────────────────────────────────────
    func createInvite(for group: Group) async throws -> String {
        #if canImport(FirebaseFirestore)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        struct Invite: Codable { var token: String; var groupId: ID; var createdAt: Date; var isActive: Bool }
        let db = Firestore.firestore()
        let inv = Invite(token: token, groupId: group.id, createdAt: Date(), isActive: true)
        try db.collection("invites").document(token).setData(from: inv)
        try db.collection("groups").document(group.id).setData(["activeInviteToken": token], merge: true)
        return token
        #else
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        #endif
    }
    
    // ─────────────────────────────────────────────────────────────
    // 2) NEW: resolveInvite — получить группу по токену (для экрана выбора имени)
    // ─────────────────────────────────────────────────────────────
    func resolveInvite(token: String) async throws -> Group {
        #if canImport(FirebaseFirestore)
        struct Invite: Codable { var token: String; var groupId: ID; var createdAt: Date; var isActive: Bool }
        let db = Firestore.firestore()
        let invRef = db.collection("invites").document(token)
        guard let inv = try await invRef.getDocument().data().flatMap({ try? Firestore.Decoder().decode(Invite.self, from: $0) }),
              inv.isActive else { throw NSError(domain: "invite", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invite is invalid"]) }
        if let g = try await store.getGroup(by: inv.groupId) {
            return g
        }
        // запасной путь — напрямую из Firestore:
        let gRef = db.collection("groups").document(inv.groupId)
        guard let group = try await gRef.getDocument().data().flatMap({ try? Firestore.Decoder().decode(Group.self, from: $0) }) else {
            throw NSError(domain: "group", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        return group
        #else
        // Локально: вернём первую попавшуюся (демо)
        if let g = try await store.groups().first { return g }
        throw NSError(domain: "local", code: 1, userInfo: [NSLocalizedDescriptionKey: "No local group"])
        #endif
    }
    
    // ─────────────────────────────────────────────────────────────
    // 3) Join: выбрать существующее имя ИЛИ добавить новое
    //   - Если имя уже есть в группе → привязываем этот слот к текущему uid
    //   - Если нет → добавляем нового участника
    // ─────────────────────────────────────────────────────────────
    func joinGroupByInvite(token: String, pickOrCreateName: String) async throws -> Group {
        #if canImport(FirebaseFirestore)
        struct Invite: Codable { var token: String; var groupId: ID; var createdAt: Date; var isActive: Bool }
        let db = Firestore.firestore()
        let invRef = db.collection("invites").document(token)
        guard let inv = try await invRef.getDocument().data().flatMap({ try? Firestore.Decoder().decode(Invite.self, from: $0) }),
              inv.isActive else { throw NSError(domain: "invite", code: 404) }
        
        let groupRef = db.collection("groups").document(inv.groupId)
        guard var group = try await groupRef.getDocument().data().flatMap({ try? Firestore.Decoder().decode(Group.self, from: $0) }) else {
            throw NSError(domain: "group", code: 404)
        }
        let myUid = Auth.auth().currentUser?.uid ?? UUID().uuidString
        
        // Пытаемся "занять" существующее имя, если такое уже есть
        if let idx = group.members.firstIndex(where: { $0.displayName.caseInsensitiveCompare(pickOrCreateName) == .orderedSame }) {
            // Привязываем этот слот к текущему пользователю
            group.members[idx].id = myUid
        } else {
            // Добавляем нового участника
            group.members.append(Member(id: myUid, displayName: pickOrCreateName))
        }
        try groupRef.setData(from: group, merge: true)
        return group
        #else
        // Локально — просто добавим участника (слоты по имени не "занимаем")
        guard let g = try await store.groups().first else { throw NSError(domain: "local", code: 1) }
        _ = try await store.appendMember(groupId: g.id, member: Member(id: UUID().uuidString, displayName: pickOrCreateName))
        return g
        #endif
    }
    
    // ─────────────────────────────────────────────────────────────
    // 4) Сборка ссылки-приглашения (как было)
    // ─────────────────────────────────────────────────────────────
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
        return URL(string: "https://splitsq.app/invite?token=\(token)")!
        #endif
    }
}
