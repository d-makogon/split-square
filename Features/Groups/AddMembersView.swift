import SwiftUI

struct AddMembersView: View {
    let group: Group
    let store: GroupStore
    
    @Environment(\.dismiss) private var dismiss
    @State private var names: [String] = [""]
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section("Новые участники") {
                ForEach(names.indices, id: \.self) { i in
                    HStack {
                        TextField("Имя участника", text: Binding(
                            get: { names[i] },
                            set: { names[i] = $0 }
                        ))
                        if names.count > 1 {
                            Button(role: .destructive) {
                                names.remove(at: i)
                            } label: { Image(systemName: "minus.circle.fill") }
                        }
                    }
                }
                Button {
                    names.append("")
                } label: {
                    Label("Добавить поле", systemImage: "plus.circle.fill")
                }
            }
            
            Section {
                Button("Сохранить") { Task { await save() } }
                    .disabled(!hasValidInput || isSaving)
            }
        }
        .navigationTitle("Добавить участников")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        }
    }
    
    private var hasValidInput: Bool {
        let trimmed = validNewNames()
        return !trimmed.isEmpty
    }
    
    private func validNewNames() -> [String] {
        let existing = Set(group.members.map { $0.displayName.lowercased() })
        let trimmed = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let unique = Array(Set(trimmed.map { $0.lowercased() }))
        // убираем тех, кто уже есть
        let filtered = unique.filter { !existing.contains($0) }
        // восстановим регистр как в первом вхождении
        var restored: [String] = []
        for n in trimmed {
            if filtered.contains(n.lowercased()) && !restored.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
                restored.append(n)
            }
        }
        return restored
    }
    
    private func memberId() -> ID { UUID().uuidString }
    
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let toAdd = validNewNames()
        for name in toAdd {
            _ = try? await store.appendMember(groupId: group.id, member: Member(id: memberId(), displayName: name))
        }
        await MainActor.run { dismiss() }
    }
}
