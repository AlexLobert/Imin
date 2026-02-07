import Foundation
import SwiftUI

@MainActor
final class StatusStore: ObservableObject {
    @AppStorage("status.current") private var statusRaw: String = UserStatus.out.rawValue
    @AppStorage("status.autoResetSetting") private var autoResetRaw: String = AutoResetSetting.hour1.rawValue
    @AppStorage("status.lastBecameInAt") private var lastBecameInAtEpoch: Double = 0
    @AppStorage("status.resetAt") private var resetAtEpoch: Double = 0

    var autoResetSetting: AutoResetSetting {
        get { AutoResetSetting(rawValue: autoResetRaw) ?? .hour1 }
        set { autoResetRaw = newValue.rawValue }
    }

    var currentStatus: UserStatus {
        get { UserStatus(rawValue: statusRaw) ?? .out }
        set { statusRaw = newValue.rawValue }
    }

    var lastBecameInAt: Date? {
        lastBecameInAtEpoch > 0 ? Date(timeIntervalSince1970: lastBecameInAtEpoch) : nil
    }

    var resetAt: Date? {
        resetAtEpoch > 0 ? Date(timeIntervalSince1970: resetAtEpoch) : nil
    }

    func recordStatusChange(_ status: UserStatus) {
        currentStatus = status
        switch status {
        case .in:
            let now = Date()
            lastBecameInAtEpoch = now.timeIntervalSince1970
            if let target = autoResetSetting.resetDate(from: now) {
                resetAtEpoch = target.timeIntervalSince1970
            } else {
                resetAtEpoch = 0
            }
        case .out:
            lastBecameInAtEpoch = 0
            resetAtEpoch = 0
        }
    }

    func updateResetForCurrentStatus(_ status: UserStatus) {
        guard status == .in else { return }
        let start = lastBecameInAt ?? Date()
        if let target = autoResetSetting.resetDate(from: start) {
            resetAtEpoch = target.timeIntervalSince1970
        } else {
            resetAtEpoch = 0
        }
    }

    func shouldAutoReset(status: UserStatus, now: Date = Date()) -> Bool {
        guard status == .in, let resetAt else { return false }
        return now >= resetAt
    }
}
