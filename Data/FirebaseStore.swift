import Foundation

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Firestore-хранилище. Включается автоматически, если добавлены модули Firebase и useFirebase = true
final class FirebaseStore: GroupStore {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously(completion: { _, _ in })
        }
    }

    func createGroup(name: String, defaultCurrency: String, creatorDisplayName: String) async throws -> Group {
        let gid = UUID().uuidString
        let uid = Auth.auth().currentUser?.uid ?? UUID().uuidString
        let creator = Member(id: uid, displayName: creatorDisplayName)
        let group = Group(id: gid, name: name, defaultCurrency: defaultCurrency, members: [creator], activeInviteToken: nil, createdAt: Date())
        try db.collection("groups").document(gid).setData(from: group)
        return group
    }

    func groups() async throws -> [Group] {
        let snap = try await db.collection("groups").order(by: "createdAt", descending: false).getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Group.self) }
    }

    func subscribeGroup(groupId: ID, onChange: @escaping (Group, [Expense], [Payment]) -> Void) {
        let groupRef = db.collection("groups").document(groupId)
        listener = groupRef.addSnapshotListener { snap, _ in
            guard let group = try? snap?.data(as: Group.self) else { return }
            Task {
                async let ex = groupRef.collection("expenses").order(by: "createdAt", descending: true).getDocuments()
                async let py = groupRef.collection("payments").order(by: "createdAt", descending: true).getDocuments()
                do {
                    let (exS, pyS) = try await (ex, py)
                    let expenses = exS.documents.compactMap { try? $0.data(as: Expense.self) }
                    let payments = pyS.documents.compactMap { try? $0.data(as: Payment.self) }
                    onChange(group, expenses, payments)
                } catch { }
            }
        }
    }

    func stopGroupSubscription() {
        listener?.remove(); listener = nil
    }

    func addExpense(_ e: Expense) async throws {
        try db.collection("groups").document(e.groupId).collection("expenses").document(e.id).setData(from: e)
    }

    func updateExpense(_ e: Expense) async throws {
        try db.collection("groups").document(e.groupId).collection("expenses").document(e.id).setData(from: e, merge: true)
    }

    func addPayment(_ p: Payment) async throws {
        try db.collection("groups").document(p.groupId).collection("payments").document(p.id).setData(from: p)
    }

    func updatePayment(_ p: Payment) async throws {
        try db.collection("groups").document(p.groupId)
            .collection("payments").document(p.id).setData(from: p, merge: true)
    }

    func appendMember(groupId: ID, member: Member) async throws -> Group {
        let ref = db.collection("groups").document(groupId)
        var g = try await ref.getDocument().data().flatMap { try? Firestore.Decoder().decode(Group.self, from: $0) }
        guard var group = g else { throw NSError(domain: "group", code: 404) }
        group.members.append(member)
        try ref.setData(from: group, merge: true)
        return group
    }

    func getGroup(by id: ID) async throws -> Group? {
        try await db.collection("groups").document(id).getDocument().data().flatMap { try? Firestore.Decoder().decode(Group.self, from: $0) }
    }
}

/// Пример правил Firestore (см. консоль Firebase → Rules):
/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthed() { return request.auth != null; }
    match /groups/{groupId} {
      allow read, create: if isAuthed();
      allow update, delete: if isAuthed();
      match /expenses/{expenseId} { allow read, create, update, delete: if isAuthed(); }
      match /payments/{paymentId} { allow read, create, update, delete: if isAuthed(); }
    }
    match /invites/{token} {
      allow read: if true;
      allow create, update: if isAuthed();
    }
  }
}
*/
#endif
