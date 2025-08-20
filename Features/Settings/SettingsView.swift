import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: PatternSettingsView()) {
                    Label(String(localized: "Patterns"), systemImage: "textformat.abc")
                }
                
                NavigationLink(destination: SearchDomainSettingsView()) {
                    Label(String(localized: "Search Domains"), systemImage: "magnifyingglass")
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

private struct SearchDomainSettingsView: View {
    @ObservedObject private var store = SearchDomainStore.shared
    @State private var showEdit = false
    @State private var editing: SearchDomain?

    var body: some View {
        List {
            ForEach(store.domains) { domain in
                HStack {
                    VStack(alignment: .leading) {
                        Text(domain.name)
                        Text(domain.urlTemplate).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    // Radio button style selection (only one can be enabled)
                    Button(action: {
                        store.setEnabled(domain, enabled: !domain.enabled)
                    }) {
                        Image(systemName: domain.enabled ? "circle.fill" : "circle")
                            .foregroundColor(domain.enabled ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editing = domain
                    showEdit = true
                }
            }
            .onDelete { idx in
                for i in idx { store.delete(store.domains[i]) }
            }
        }
        .navigationTitle(String(localized: "Search Domains"))
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
            EditSearchDomainView(store: store, domain: editing)
        }
    }
}

private struct EditSearchDomainView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SearchDomainStore
    var domain: SearchDomain?

    @State private var name: String
    @State private var urlTemplate: String

    init(store: SearchDomainStore, domain: SearchDomain?) {
        self.store = store
        self.domain = domain
        _name = State(initialValue: domain?.name ?? "")
        _urlTemplate = State(initialValue: domain?.urlTemplate ?? "https://example.com/search?q={q}")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name"), text: $name)
                    TextField(String(localized: "URL Template"), text: $urlTemplate)
                        .autocapitalization(.none)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text(String(localized: "Search Domain"))
                } footer: {
                    Text(String(localized: "Use {q} as placeholder for the search query. Example: https://www.google.com/search?q={q}"))
                }
            }
            .navigationTitle(domain == nil ? String(localized: "Add Search Domain") : String(localized: "Edit Search Domain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        if let existing = domain {
                            store.update(existing, name: name, urlTemplate: urlTemplate)
                        } else {
                            store.add(name: name, urlTemplate: urlTemplate)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || urlTemplate.isEmpty || !urlTemplate.contains("{q}"))
                }
            }
        }
    }
}
