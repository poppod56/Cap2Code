import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: PatternSettingsView()) {
                    Label(String(localized: "Patterns"), systemImage: "textformat.abc")
                }
                
                // Future settings categories can be added here
                // NavigationLink(destination: GeneralSettingsView()) {
                //     Label(String(localized: "General"), systemImage: "gear")
                // }
                // NavigationLink(destination: PrivacySettingsView()) {
                //     Label(String(localized: "Privacy"), systemImage: "lock")
                // }
            }
            .navigationTitle(String(localized: "Settings"))
        }
    }
}

private struct PatternSettingsView: View {
    @ObservedObject private var store = PatternStore.shared
    @State private var showEdit = false
    @State private var editing: RegexPattern?

    var body: some View {
        List {
            ForEach(store.patterns) { p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.name)
                        Text(p.pattern).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { p.enabled },
                        set: { store.setEnabled(p, enabled: $0) }
                    ))
                    .labelsHidden()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editing = p
                    showEdit = true
                }
            }
            .onDelete { idx in
                for i in idx { store.delete(store.patterns[i]) }
            }
        }
        .navigationTitle(String(localized: "Patterns"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: {
                editing = nil
                showEdit = true
            }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showEdit) {
            EditPatternView(store: store, pattern: editing)
        }
    }
}

private struct EditPatternView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatternStore
    var pattern: RegexPattern?

    @State private var name: String
    @State private var regex: String

    init(store: PatternStore, pattern: RegexPattern?) {
        self.store = store
        self.pattern = pattern
        _name = State(initialValue: pattern?.name ?? "")
        _regex = State(initialValue: pattern?.pattern ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Name"), text: $name)
                TextField(String(localized: "Pattern"), text: $regex)
                    .autocapitalization(.none)
                    .font(.system(.body, design: .monospaced))
            }
            .navigationTitle(pattern == nil ? String(localized: "Add Pattern") : String(localized: "Edit Pattern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        if let existing = pattern {
                            store.update(existing, name: name, pattern: regex)
                        } else {
                            store.add(name: name, pattern: regex)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
