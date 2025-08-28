import SwiftUI

struct GroupsListView: View {
    @State private var groups: [Group] = []
    @State private var isCreating = false
    @State private var newGroupName = ""
    @State private var newGroupCurrency = "EUR"
    @State private var newDisplayName = ""
    @State private var errorMessage: String?
    @EnvironmentObject var appRouter: AppRouter
    private let store: GroupStore = makeStore()

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
                Task { await joinBy(token: token) }
                appRouter.pendingInviteToken = nil
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

    private func joinBy(token: String) async {
        do {
            let invite = InviteService(store: store)
            let group = try await invite.joinGroupByInvite(token: token, pickOrCreateName: "New Member")
            if !groups.contains(where: {$0.id == group.id}) {
                groups.append(group)
            }
        } catch {
            errorMessage = "Не удалось присоединиться по инвайту: \(error.localizedDescription)"
        }
    }
}

struct CreateGroupView: View {
    let store: GroupStore
    var onCreated: (Group) -> Void

    @State private var name = ""
    @State private var currency = "EUR"
    @State private var displayName = ""
    @State private var isBusy = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Группа") {
                TextField("Название", text: $name)
                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyUtil.allCurrencyCodes, id: \.self) { Text($0) }
                }
            }
            Section("Вы в группе") {
                TextField("Ваше имя", text: $displayName)
            }
        }
        .navigationTitle("Новая группа")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Создать") {
                    Task {
                        guard !name.isEmpty, !displayName.isEmpty else { return }
                        isBusy = true
                        defer { isBusy = false }
                        do {
                            let g = try await store.createGroup(name: name, defaultCurrency: currency, creatorDisplayName: displayName)
                            onCreated(g)
                        } catch {
                            // nothing
                        }
                    }
                }.disabled(isBusy || name.isEmpty || displayName.isEmpty)
            }
        }
    }
}
