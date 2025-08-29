import SwiftUI

struct GroupDetailView: View {
    @State private var group: Group
    @State private var expenses: [Expense] = []
    @State private var payments: [Payment] = []
    private let store: GroupStore

    @State private var errorMessage: String?
    @State private var generatedInviteURL: URL?
    @State private var showInviteAlert = false

    // Показ объединённого экрана добавления
    @State private var showAddSheet = false

    init(initialGroup: Group, store: GroupStore) {
        self._group = State(initialValue: initialGroup)
        self.store = store
    }

    var body: some View {
        ZStack {
            List {
                Section("Траты") {
                    ForEach(expenses) { e in
                        NavigationLink(destination: ExpenseDetailView(expense: e, store: store, group: group)) {
                            VStack(alignment: .leading) {
                                Text(e.title).font(.headline)
                                Text("\(e.currencyOriginal) \(e.amountOriginal.description) • Платил: \(name(e.payerId))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if expenses.isEmpty { Text("Нет трат") }
                }
                Section("Выплаты") {
                    ForEach(payments) { p in
                        NavigationLink(destination: PaymentDetailView(payment: p, store: store, group: group)) {
                            VStack(alignment: .leading) {
                                Text(p.title).font(.headline)
                                Text("Получил: \(name(p.recipientId)) • \(p.currencyOriginal) \(p.amountOriginal.description)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if payments.isEmpty { Text("Нет выплат") }
                }
            }
            // Кнопка по центру снизу: круглый плюс и подпись "Добавить"
            .safeAreaInset(edge: .bottom) {
                Button {
                    showAddSheet = true
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 64, height: 64)
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("Добавить")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(destination: GroupInfoView(group: group, expenses: expenses, store: store)) {
                    Image(systemName: "info.circle")
                }
                // Добавление участников
                NavigationLink(destination: AddMembersView(group: group, store: store)) {
                    Image(systemName: "person.badge.plus")
                }
                // Выплаты-расчёт
                NavigationLink("Выплаты") {
                    SettlementsView(group: group, expenses: expenses, payments: payments)
                }
                // Инвайт
                Button { invite() } label: { Image(systemName: "link") }
            }
        }
        .onAppear {
            store.subscribeGroup(groupId: group.id) { g, ex, py in
                self.group = g; self.expenses = ex; self.payments = py
            }
        }
        .onDisappear { store.stopGroupSubscription() }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddTransactionView(group: group, store: store) {
                    showAddSheet = false
                }
            }
        }
        .alert("Ссылка скопирована", isPresented: $showInviteAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(generatedInviteURL?.absoluteString ?? "") }
        .alert("Ошибка", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func name(_ id: ID) -> String {
        group.members.first(where: { $0.id == id })?.displayName ?? "?"
    }

    private func invite() {
        Task {
            do {
                let inviteSvc = InviteService(store: store)
                let token = try await inviteSvc.createInvite(for: group)
                let url = try await inviteSvc.buildInviteURL(token: token)
                generatedInviteURL = url
                #if canImport(UIKit)
                UIPasteboard.general.url = url
                #endif
                showInviteAlert = true
            } catch {
                errorMessage = "Не удалось создать инвайт: \(error.localizedDescription)"
            }
        }
    }
}
