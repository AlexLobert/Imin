import Foundation

enum APIConfig {
    static var baseURL: URL {
        AppEnvironment.baseURL
    }
}
