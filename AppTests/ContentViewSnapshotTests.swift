import XCTest
@testable import NativeStarter

final class ContentViewSnapshotTests: SnapshotTestCase {
    @MainActor
    func testInitialState() {
        XCTAssertEqual(Counter.initialValue, 0)
        snapshot(ContentView(), name: "01-initial-count-0")
    }

    @MainActor
    func testAfterTwoIncrements() {
        let count = Counter.increment(Counter.increment(Counter.initialValue))
        XCTAssertEqual(count, 2)
        snapshot(ContentView(initialCount: count), name: "02-count-2")
    }
}
