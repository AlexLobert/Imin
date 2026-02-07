import Foundation

enum BackendTarget: String {
    case supabase
    case kris
}

enum AppEnvironment {
    static var backend: BackendTarget {
        if let raw = stringFromEnvOrInfo("APP_BACKEND")?.lowercased(),
           let value = BackendTarget(rawValue: raw) {
            return value
        }
        return .supabase
    }

    static let baseURL: URL = {
        if let s = stringFromEnvOrInfo("API_BASE_URL"),
           let url = URL(string: s) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }()

    static var isUsingAPIBaseURL: Bool {
        backend == .kris && stringFromEnvOrInfo("API_BASE_URL") != nil
    }

    static var isChatBackendEnabled: Bool {
        if let value = stringFromEnvOrInfo("CHAT_BACKEND_ENABLED") {
            return value == "1"
        }
        return backend == .supabase
    }

    static var supabaseURL: URL? {
        guard let raw = stringFromEnvOrInfo("SUPABASE_URL") else { return nil }
        return URL(string: raw)
    }

    static var supabaseAnonKey: String? {
        stringFromEnvOrInfo("SUPABASE_ANON_KEY")
    }

    private static func stringFromEnvOrInfo(_ key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key] {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return value
        }
        return nil
    }
}
