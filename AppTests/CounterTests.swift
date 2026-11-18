import XCTest
@testable import NativeStarter

final class CounterTests: XCTestCase {
    func testInitialValueIsZero() {
        XCTAssertEqual(Counter.initialValue, 0)
    }

    func testIncrement() {
        XCTAssertEqual(Counter.increment(0), 1)
    }

    func testRepeatedIncrementAccumulates() {
        var value = Counter.initialValue
        for _ in 0..<5 { value = Counter.increment(value) }
        XCTAssertEqual(value, 5)
    }

    func testIncrementFromNegativeValues() {
        XCTAssertEqual(Counter.increment(-1), 0)
        XCTAssertEqual(Counter.increment(Int.min), Int.min + 1)
    }

    func testDoesNotOverflow() {
        XCTAssertEqual(Counter.increment(Int.max - 1), Int.max)
        XCTAssertEqual(Counter.increment(Int.max), Int.max)
    }

    func testResetReturnsInitialValue() {
        XCTAssertEqual(Counter.reset(), Counter.initialValue)
    }
}
