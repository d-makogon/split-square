import SwiftUI

struct GroupsListView: View {
    @State private var groups: [Group] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    @EnvironmentObject var appRouter: AppRouter
    private let store: GroupStore = makeStore()
    
    // Для Join по инвайту — показываем модальный экран выбора имени
    @State private var inviteTokenForJoin: String?
    
    var body: some View {
        NavigationStack {
            List(groups) { g in
                NavigationLink(destination: GroupDetailView(initialGroup: g, store: store)) {
                    VStack(alignment: .leading) {
                        Text(g.name).font(.headline)
                        Text("Валюта: \(g.defaultCurrency) • участников: \(g.members.count)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("SplitSquare")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                }
            }
            .onAppear { Task { await load() } }
            .onChange(of: appRouter.pendingInviteToken) { _, token in
                guard let token else { return }
                inviteTokenForJoin = token
                appRouter.pendingInviteToken = nil
            }
            .sheet(isPresented: Binding(
                get: { inviteTokenForJoin != nil },
                set: { if !$0 { inviteTokenForJoin = nil } }
            )) {
                if let token = inviteTokenForJoin {
                    JoinGroupView(token: token, store: store) { joined in
                        if !groups.contains(where: { $0.id == joined.id }) {
                            groups.append(joined)
                        } else {
                            // обновим локальный список
                            if let idx = groups.firstIndex(where: { $0.id == joined.id }) {
                                groups[idx] = joined
                            }
                        }
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .sheet(isPresented: $isCreating) {
                NavigationStack {
                    CreateGroupView(store: store) { g in
                        groups.append(g); isCreating = false
                    }
                }
            }
        }
    }
    
    private func load() async {
        do { groups = try await store.groups() } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - CreateGroupView (с добавлением участников сразу)

struct CreateGroupView: View {
    let store: GroupStore
    var onCreated: (Group) -> Void
    
    @State private var name = ""
    @State private var currency = "EUR"
    @State private var displayName = ""
    @State private var extraMembers: [String] = [""]
    @State private var isBusy = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section("Группа") {
                TextField("Название", text: $name)
                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Вы (создатель)") {
                TextField("Ваше имя", text: $displayName)
            }
            Section("Сразу добавить участников (опционально)") {
                ForEach(extraMembers.indices, id: \.self) { i in
                    HStack {
                        TextField("Имя участника", text: Binding(
                            get: { extraMembers[i] },
                            set: { extraMembers[i] = $0 }
                        ))
                        if extraMembers.count > 1 {
                            Button(role: .destructive) {
                                extraMembers.remove(at: i)
                            } label: { Image(systemName: "minus.circle.fill") }
                        }
                    }
                }
                Button {
                    extraMembers.append("")
                } label: {
                    Label("Добавить поле", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Новая группа")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Создать") {
                    Task { await create() }
                }
                .disabled(isBusy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func create() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let g = try await store.createGroup(name: name, defaultCurrency: currency, creatorDisplayName: displayName)
            // добавим остальных по именам
            let existing = Set([displayName.lowercased()])
            let toAdd = extraMembers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { !existing.contains($0.lowercased()) }
            for n in toAdd {
                _ = try? await store.appendMember(groupId: g.id, member: Member(id: UUID().uuidString, displayName: n))
            }
            onCreated(g)
        } catch {
            // можно вывести alert
        }
    }
}
