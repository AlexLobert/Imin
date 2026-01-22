import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var availabilityState: AvailabilityState = .out
    @Published var isUpdatingAvailability = false
    @Published var isLoadingAvailability = false
    @Published var errorMessage: String?

    private let availabilityService: AvailabilityService
    private let availabilityExpiryInterval: TimeInterval

    init(
        availabilityService: AvailabilityService = AvailabilityService(),
        availabilityExpiryInterval: TimeInterval = 60 * 60 * 8
    ) {
        self.availabilityService = availabilityService
        self.availabilityExpiryInterval = availabilityExpiryInterval
    }

    func loadAvailability(session: UserSession) async {
        isLoadingAvailability = true
        errorMessage = nil
        defer { isLoadingAvailability = false }

        do {
#if DEBUG
            print("HomeViewModel loadAvailability start")
#endif
            if let availability = try await availabilityService.fetchAvailability(session: session) {
                availabilityState = availability.state
            }
#if DEBUG
            print("HomeViewModel loadAvailability success: \(availabilityState.rawValue)")
#endif
        } catch {
            errorMessage = error.localizedDescription
#if DEBUG
            print("HomeViewModel loadAvailability error: \(error.localizedDescription)")
#endif
        }
    }

    func updateAvailability(state: AvailabilityState, session: UserSession) async {
        isUpdatingAvailability = true
        errorMessage = nil
        let previousState = availabilityState
        defer { isUpdatingAvailability = false }

        do {
#if DEBUG
            print("HomeViewModel updateAvailability start: \(state.rawValue)")
#endif
            availabilityState = state
            let expiresAt = Date().addingTimeInterval(availabilityExpiryInterval)
            let availability = try await availabilityService.upsertAvailability(
                state: state,
                expiresAt: expiresAt,
                session: session
            )
            availabilityState = availability.state
#if DEBUG
            print("HomeViewModel updateAvailability success: \(availabilityState.rawValue)")
#endif
        } catch {
            errorMessage = error.localizedDescription
#if DEBUG
            print("HomeViewModel updateAvailability error: \(error.localizedDescription)")
#endif
            availabilityState = previousState
        }
    }
}
