import Foundation

enum AppEnvironment {
    static let baseURL: URL = {
        if let s = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: s) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }()

    static var isUsingAPIBaseURL: Bool {
        ProcessInfo.processInfo.environment["API_BASE_URL"] != nil
    }

    static var isChatBackendEnabled: Bool {
        ProcessInfo.processInfo.environment["CHAT_BACKEND_ENABLED"] == "1"
    }
}
