import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var statusStore: StatusStore
    @EnvironmentObject private var privacyStore: PrivacyStore
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var currentName: String?
    @State private var newName = ""
    @State private var currentHandle: String?
    @State private var newHandle = ""
    @State private var handleMessage: String?
    @State private var isLoadingHandle = false
    @State private var showDeleteConfirm = false
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var headerOpacity: Double = 0
    @State private var showAutoResetPicker = false
    private let profileService = ProfileService()
    private let maxNameLength = 50
    private let maxHandleLength = 20

    var body: some View {
        NavigationStack {
            ZStack {
                DesignColors.background
                    .ignoresSafeArea()

                ScrollView {
                    ScrollOffsetReader(coordinateSpace: "profileScroll")
                    VStack(alignment: .leading, spacing: 20) {
                        profileIdentityCard

                        accountSection
                        availabilitySection
                        privacySection
                        logoutSection

                        if isEditing {
                            Button(action: {
                                Task {
                                    await saveProfileChanges()
                                }
                            }) {
                                Text(isSaving ? "Saving..." : "Save changes")
                            }
                            .buttonStyle(AppPillButtonStyle(kind: .mint))
                            .disabled(isSaving || sessionManager.isLoading || isLoadingHandle)
                        }

                        if let handleMessage {
                            Text(handleMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignColors.textSecondary)
                        }

                        if let error = sessionManager.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                }
                .coordinateSpace(name: "profileScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    let progress = min(max((-value) / 14, 0), 1)
                    headerOpacity = progress
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .safeAreaInset(edge: .top) {
                GlassHeaderContainer(opacity: headerOpacity) {
                    HStack {
                        Spacer()
                        Text("Profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            )
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .sheet(isPresented: $showDeleteConfirm) {
                DeleteAccountSheet(
                    onDelete: {
                        Task {
                            await sessionManager.deleteAccount()
                            if sessionManager.session == nil {
                                dismiss()
                            }
                        }
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
            .sheet(isPresented: $showAutoResetPicker) {
                NavigationStack {
                    List {
                        ForEach(AutoResetSetting.allCases) { option in
                            Button {
                                statusStore.autoResetSetting = option
                                statusStore.updateResetForCurrentStatus(statusStore.currentStatus)
                                showAutoResetPicker = false
                            } label: {
                                HStack {
                                    Text(option.title)
                                    Spacer()
                                    if statusStore.autoResetSetting == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color(.systemMint))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationTitle("Auto-reset status")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showAutoResetPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .task(id: sessionManager.session?.userId) {
                await loadHandle()
            }
        }
    }

    @MainActor
    private func loadHandle() async {
        guard AppEnvironment.backend == .supabase else {
            currentHandle = "Unavailable"
            return
        }
        guard let session = await sessionManager.validSession() else { return }
        isLoadingHandle = true
        handleMessage = nil
        defer { isLoadingHandle = false }
        do {
            let profile = try await profileService.fetchProfile(session: session)
            currentHandle = profile.handle
            currentName = profile.name
            if let name = profile.name, !name.isEmpty {
                newName = name
            }
            if let handle = profile.handle, !handle.isEmpty {
                newHandle = handle
            }
            if let email = sessionManager.session?.email {
                newEmail = email
            }
        } catch {
            handleMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateHandle(_ handle: String) async {
        guard AppEnvironment.backend == .supabase else {
            handleMessage = "Handle updates aren't available on this backend."
            return
        }
        let trimmed = limit(handle.trimmingCharacters(in: .whitespacesAndNewlines), max: maxHandleLength)
        guard !trimmed.isEmpty else {
            handleMessage = "Handle can't be empty."
            return
        }
        guard let session = await sessionManager.validSession() else { return }
        isLoadingHandle = true
        handleMessage = nil
        defer { isLoadingHandle = false }
        do {
            let updated = try await profileService.updateProfile(name: nil, handle: trimmed, session: session)
            currentHandle = updated.handle ?? trimmed
            newHandle = ""
            handleMessage = "Handle updated."
        } catch {
            handleMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateName(_ name: String) async {
        guard AppEnvironment.backend == .supabase else {
            handleMessage = "Name updates aren't available on this backend."
            return
        }
        let trimmed = limit(name.trimmingCharacters(in: .whitespacesAndNewlines), max: maxNameLength)
        guard !trimmed.isEmpty else {
            handleMessage = "Name can't be empty."
            return
        }
        guard let session = await sessionManager.validSession() else { return }
        isLoadingHandle = true
        handleMessage = nil
        defer { isLoadingHandle = false }
        do {
            let updated = try await profileService.updateProfile(name: trimmed, handle: nil, session: session)
            currentName = updated.name ?? trimmed
            newName = ""
            handleMessage = "Name updated."
        } catch {
            handleMessage = error.localizedDescription
        }
    }

    private func limit(_ value: String, max: Int) -> String {
        String(value.prefix(max))
    }

    private func toggleEditing() {
        if isEditing {
            resetEdits()
        }
        isEditing.toggle()
        handleMessage = nil
    }

    private func resetEdits() {
        newName = currentName ?? ""
        newHandle = currentHandle ?? ""
        newEmail = sessionManager.session?.email ?? ""
    }

    @MainActor
    private func saveProfileChanges() async {
        guard let session = await sessionManager.validSession() else { return }
        isSaving = true
        handleMessage = nil
        defer { isSaving = false }

        let trimmedName = limit(newName.trimmingCharacters(in: .whitespacesAndNewlines), max: maxNameLength)
        let trimmedHandle = limit(newHandle.trimmingCharacters(in: .whitespacesAndNewlines), max: maxHandleLength)
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if AppEnvironment.backend == .supabase {
                let nameChanged = trimmedName != (currentName ?? "")
                let handleChanged = trimmedHandle != (currentHandle ?? "")
                if nameChanged || handleChanged {
                    let updated = try await profileService.updateProfile(
                        name: nameChanged ? trimmedName : nil,
                        handle: handleChanged ? trimmedHandle : nil,
                        session: session
                    )
                    if nameChanged {
                        currentName = updated.name ?? trimmedName
                    }
                    if handleChanged {
                        currentHandle = updated.handle ?? trimmedHandle
                    }
                }
            }

            if let currentEmail = sessionManager.session?.email,
               !trimmedEmail.isEmpty,
               trimmedEmail != currentEmail {
                await sessionManager.updateEmail(to: trimmedEmail)
            }

            if sessionManager.errorMessage == nil {
                isEditing = false
                resetEdits()
                handleMessage = "Profile updated."
            }
        } catch {
            handleMessage = error.localizedDescription
        }
    }

    private var profileIdentityCard: some View {
        HStack(alignment: .top, spacing: 16) {
            AvatarView(name: displayName, showsStatus: false)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)

                Text(displayHandle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignColors.textSecondary)
            }

            Spacer()

            Button(action: toggleEditing) {
                Image(systemName: isEditing ? "xmark" : "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSaving || isLoadingHandle)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 6)
    }

    private var availabilitySection: some View {
        GlassGroup(title: "Availability") {
            glassRowDivider
            Button {
                showAutoResetPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignColors.textSecondary)

                    Text("Auto-reset status")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)

                    Spacer()

                    Text(statusStore.autoResetSetting.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignColors.textSecondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    private var privacySection: some View {
        GlassGroup(title: "Privacy") {
            glassRowDivider
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.textSecondary)

                Text("Searchable by handle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { privacyStore.searchableByHandle },
                    set: { newVal in
                        Task {
                            guard let session = await sessionManager.validSession() else { return }
                            do {
                                try await privacyStore.setSearchableByHandle(newVal, session: session)
                            } catch {
                                handleMessage = "Couldn't update privacy setting."
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color(.systemMint))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            glassRowDivider

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.textSecondary)

                Text("Controls whether others can find you via @handle search.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignColors.textSecondary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }

    private var accountSection: some View {
        GlassGroup(title: "Account") {
            glassRow(
                title: "Name",
                value: currentName ?? "Not set",
                textField: $newName,
                isEditing: isEditing,
                autocapitalize: .words,
                maxLength: maxNameLength
            )
            glassRowDivider
            glassRow(
                title: "Handle",
                value: currentHandle ?? "Not set",
                textField: $newHandle,
                isEditing: isEditing,
                autocapitalize: .never,
                maxLength: maxHandleLength,
                prefix: "@"
            )
            glassRowDivider
            glassRow(
                title: "Email",
                value: sessionManager.session?.email ?? "Unknown",
                textField: $newEmail,
                isEditing: isEditing,
                autocapitalize: .never,
                maxLength: 120,
                keyboardType: .emailAddress,
                trailingIcon: isEditing ? nil : "lock.fill"
            )
        }
    }

    private var logoutSection: some View {
        GlassGroup(title: "Account") {
            Button {
                Task {
                    await sessionManager.signOut()
                    if sessionManager.session == nil {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    Text("Log out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(sessionManager.isLoading)

            glassRowDivider

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Text("Delete account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    private var displayName: String {
        currentName?.isEmpty == false ? currentName! : "Your Profile"
    }

    private var displayHandle: String {
        let handle = currentHandle?.isEmpty == false ? currentHandle! : "Add a handle"
        return handle.hasPrefix("@") ? handle : "@\(handle)"
    }

    private var glassRowDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.2))
            .padding(.leading, 16)
    }

    private func glassRow(
        title: String,
        value: String,
        textField: Binding<String>,
        isEditing: Bool,
        autocapitalize: TextInputAutocapitalization,
        maxLength: Int,
        prefix: String? = nil,
        keyboardType: UIKeyboardType = .default,
        trailingIcon: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)

            Spacer()

            if isEditing {
                TextField("", text: textField)
                    .textInputAutocapitalization(autocapitalize)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignColors.textPrimary)
                    .onChange(of: textField.wrappedValue) { _, value in
                        textField.wrappedValue = limit(value, max: maxLength)
                    }
            } else {
                HStack(spacing: 6) {
                    if let prefix {
                        Text(prefix + value.replacingOccurrences(of: prefix, with: ""))
                    } else {
                        Text(value)
                    }
                    if let trailingIcon {
                        Image(systemName: trailingIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignColors.textSecondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

private struct GlassGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 6)
        }
    }
}

private struct DeleteAccountSheet: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: 48, height: 5)
                .padding(.top, 8)

            Text("Delete account?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)

            Text("This permanently deletes your account and data.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete account")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(AppPillButtonStyle(kind: .neutral))

                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(AppPillButtonStyle(kind: .neutral))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 24)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// Switched to shared IminLogoBubble in DesignSystem.
