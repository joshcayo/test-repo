import SwiftUI
import PhotosUI

struct MishThemeEditorView: View {
    @EnvironmentObject private var themeStore: MishThemeStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingTheme: MishTheme?
    @State private var showDeleteConfirmation = false
    @State private var themePendingDeletion: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(themeStore.themes) { theme in
                        Button {
                            themeStore.select(theme.id)
                            editingTheme = theme
                        } label: {
                            HStack(spacing: 12) {
                                themeSwatches(theme)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.name.isEmpty ? "Untitled Theme" : theme.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(theme.motion.title + (theme.backgroundImageFilename == nil ? " · Color background" : " · Custom image"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if themeStore.activeThemeID == theme.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            if themeStore.themes.count > 1 {
                                Button(role: .destructive) {
                                    themePendingDeletion = theme.id
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Your themes")
                } footer: {
                    Text("Choose a theme to make it active, then customize its colors, background, blur, and motion.")
                }

                Section {
                    Button {
                        let id = themeStore.createTheme()
                        editingTheme = themeStore.themes.first(where: { $0.id == id })
                    } label: {
                        Label("Create a theme", systemImage: "plus.circle.fill")
                            .foregroundStyle(themeStore.activeTheme.accentColor)
                    }
                }
            }
            .navigationTitle("Theme Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingTheme) { theme in
                MishThemeDetailEditor(theme: theme)
                    .environmentObject(themeStore)
            }
            .confirmationDialog(
                "Delete this theme?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Theme", role: .destructive) {
                    if let id = themePendingDeletion { themeStore.delete(id) }
                    themePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { themePendingDeletion = nil }
            } message: {
                Text("This removes the theme and its saved background image.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func themeSwatches(_ theme: MishTheme) -> some View {
        HStack(spacing: 0) {
            theme.backgroundColor
            theme.accentColor
            theme.mainColor
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct MishThemeDetailEditor: View {
    @EnvironmentObject private var themeStore: MishThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var theme: MishTheme
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSavingPhoto = false

    init(theme: MishTheme) {
        _theme = State(initialValue: theme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme name") {
                    TextField("Give your theme a name", text: $theme.name)
                        .onChange(of: theme.name) { _, _ in save() }
                }

                Section("Colors") {
                    colorRow("Accent color", hex: $theme.accentHex)
                    colorRow("Main color", hex: $theme.mainHex)
                    colorRow("Background color", hex: $theme.backgroundHex)
                } footer: {
                    Text("Accent is used for highlights and selected states. Main is the primary text and control color.")
                }

                Section("Background picture") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            theme.backgroundImageFilename == nil ? "Choose a picture" : "Replace picture",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                    .disabled(isSavingPhoto)

                    if isSavingPhoto {
                        ProgressView("Saving picture…")
                    }

                    if theme.backgroundImageFilename != nil {
                        Button(role: .destructive) {
                            themeStore.clearBackgroundImage(for: theme.id)
                            theme.backgroundImageFilename = nil
                        } label: {
                            Label("Remove background picture", systemImage: "trash")
                        }
                    }
                } footer: {
                    Text("Your selected image is copied into Mish's private app storage, so it remains available offline.")
                }

                Section("Blur") {
                    Toggle("Enable theme blur", isOn: $theme.blurEnabled)
                        .onChange(of: theme.blurEnabled) { _, _ in save() }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blur amount")
                            Spacer()
                            Text("\(Int(theme.blurRadius))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $theme.blurRadius, in: 0...100, step: 1)
                            .disabled(!theme.blurEnabled)
                            .onChange(of: theme.blurRadius) { _, _ in save() }
                    }

                    Toggle("Override album-art blur", isOn: $theme.overridesAlbumArtBlur)
                        .onChange(of: theme.overridesAlbumArtBlur) { _, _ in save() }
                } footer: {
                    Text("When override is enabled, this theme's blur amount replaces the normal album-art background blur setting.")
                }

                Section("Background tint") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tint strength")
                            Spacer()
                            Text("\(Int(theme.overlayOpacity * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $theme.overlayOpacity, in: 0...0.9, step: 0.01)
                            .onChange(of: theme.overlayOpacity) { _, _ in save() }
                    }
                }

                Section("Animation") {
                    Picker("Background motion", selection: $theme.motion) {
                        ForEach(MishTheme.BackgroundMotion.allCases) { motion in
                            Text(motion.title).tag(motion)
                        }
                    }
                    .onChange(of: theme.motion) { _, _ in save() }

                    Text(theme.motion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    themePreview
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Edit Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await importPhoto(item) }
            }
            .onDisappear { save() }
        }
        .preferredColorScheme(.dark)
    }

    private var themePreview: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundColor, theme.backgroundColor.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Text("mish")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.mainColor)
                Text("NOW PLAYING")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(theme.accentColor)
                Capsule()
                    .fill(theme.accentColor)
                    .frame(width: 90, height: 4)
            }
        }
        .frame(height: 126)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(12)
    }

    private func colorRow(_ title: String, hex: Binding<UInt32>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { Color(mishHex: hex.wrappedValue) },
                set: { newColor in
                    hex.wrappedValue = newColor.mishHex
                    save()
                }
            ),
            supportsOpacity: false
        )
    }

    private func save() {
        themeStore.update(theme)
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isSavingPhoto = true
        defer {
            isSavingPhoto = false
            selectedPhoto = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  themeStore.setBackgroundImage(data, for: theme.id) else {
                return
            }
            if let updated = themeStore.themes.first(where: { $0.id == theme.id }) {
                theme.backgroundImageFilename = updated.backgroundImageFilename
            }
        } catch {
            print("Mish theme photo import failed:", error)
        }
    }
}
