import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                        HStack(spacing: 12) {
                            Image("IminLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 40)

                            Text("Profile")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack {
                                Text(sessionManager.session?.email ?? "Unknown")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()
                            }

                            Divider()
                                .background(AppColors.separator)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Change email")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("New email", text: $newEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textFieldStyle(.roundedBorder)

                            Button(action: {
                                let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                Task {
                                    await sessionManager.updateEmail(to: trimmed)
                                    if sessionManager.errorMessage == nil {
                                        newEmail = ""
                                    }
                                }
                            }) {
                                Text("Update email")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppColors.accentGreen)
                                    .cornerRadius(12)
                            }
                            .disabled(sessionManager.isLoading)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Danger zone")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)

                            Button(role: .destructive, action: {
                                showDeleteConfirm = true
                            }) {
                                Text("Delete account")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }

                        if let error = sessionManager.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accentGreen)
                }
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await sessionManager.deleteAccount()
                        if sessionManager.session == nil {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and data.")
            }
        }
    }
}
