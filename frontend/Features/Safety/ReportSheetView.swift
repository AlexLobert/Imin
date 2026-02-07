import SwiftUI

enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case hate
    case sexualContent
    case violence
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .hate: return "Hate speech"
        case .sexualContent: return "Sexual content"
        case .violence: return "Violence / threats"
        case .other: return "Other"
        }
    }
}

struct ReportSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String?
    let onSubmit: (_ reason: ReportReason, _ details: String?) async -> Bool

    @State private var selectedReason: ReportReason = .harassment
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Reason")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.textSecondary)

                Picker("Reason", selection: $selectedReason) {
                    ForEach(ReportReason.allCases) { reason in
                        Text(reason.label).tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(DesignColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Details (optional)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.textSecondary)

                TextEditor(text: $details)
                    .frame(minHeight: 110)
                    .padding(10)
                    .background(DesignColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red.opacity(0.85))
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(AppPillButtonStyle(kind: .neutral))

                Button(isSubmitting ? "Sending..." : "Submit") {
                    Task {
                        await submit()
                    }
                }
                .buttonStyle(AppPillButtonStyle(kind: .mint))
                .disabled(isSubmitting)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(20)
        .glassSheetStyle()
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await onSubmit(selectedReason, trimmed.isEmpty ? nil : trimmed)
        if ok {
            dismiss()
        } else {
            errorMessage = "Couldn't submit your report. Please try again."
        }
    }
}

