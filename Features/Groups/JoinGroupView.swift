import SwiftUI

struct JoinGroupView: View {
    let token: String
    let store: GroupStore
    var onJoined: (Group) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var group: Group?
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum Mode: String, CaseIterable, Identifiable {
        case chooseExisting, addNew
        var id: String { rawValue }
    }
    @State private var mode: Mode = .chooseExisting
    @State private var selectedExistingName: String = ""
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Вступить в группу")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Присоединиться") { Task { await join() } }
                            .disabled(!canJoin)
                    }
                }
                .onAppear { Task { await load() } }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView("Загрузка инвайта…")
        } else if let g = group {
            Form {
                Section("Группа") {
                    Text(g.name)
                    Text("Валюта: \(g.defaultCurrency)")
                        .foregroundStyle(.secondary)
                }
                Section("Как присоединиться") {
                    Picker("Способ", selection: $mode) {
                        Text("Выбрать имя из списка").tag(Mode.chooseExisting)
                        Text("Добавить новое имя").tag(Mode.addNew)
                    }
                    .pickerStyle(.segmented)

                    if mode == .chooseExisting {
                        Picker("Выберите имя", selection: $selectedExistingName) {
                            ForEach(g.members.map(\.displayName), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    } else {
                        TextField("Ваше имя", text: $newName)
                            .textInputAutocapitalization(.words)
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
        } else {
            Text(errorMessage ?? "Не удалось загрузить приглашение.")
                .foregroundStyle(.red)
        }
    }

    private var canJoin: Bool {
        switch mode {
        case .chooseExisting:
            return !selectedExistingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .addNew:
            return !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let invite = InviteService(store: store)
            let g = try await invite.resolveInvite(token: token)
            await MainActor.run {
                self.group = g
                self.selectedExistingName = g.members.first?.displayName ?? ""
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.group = nil
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func join() async {
        guard let _ = group else { return }
        let name = (mode == .chooseExisting)
            ? selectedExistingName.trimmingCharacters(in: .whitespacesAndNewlines)
            : newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let invite = InviteService(store: store)
            let g = try await invite.joinGroupByInvite(token: token, pickOrCreateName: name)
            await MainActor.run {
                onJoined(g)
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
