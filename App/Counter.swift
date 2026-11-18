import Foundation

enum Counter {
    static let initialValue = 0

    static func increment(_ value: Int) -> Int {
        value == Int.max ? Int.max : value + 1
    }

    static func reset() -> Int {
        initialValue
    }
}
