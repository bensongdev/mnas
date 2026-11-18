import XCTest

final class NativeStarterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testInitialIncrementAndResetStatesWithEvidence() {
        let title = app.staticTexts["app.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "메인 창이 나타나지 않았습니다")
        XCTAssertEqual(text(of: title), "Native Starter")
        assertCount(0)
        capture("01-initial-launch")

        let increment = app.buttons["counter.increment"]
        XCTAssertTrue(increment.isEnabled)
        capture("02-before-increment")

        increment.click()
        increment.click()
        assertCount(2)
        capture("03-after-increment")

        app.buttons["counter.reset"].click()
        assertCount(0)
        capture("04-after-reset")
    }

    func testResetAtInitialStateKeepsZero() {
        let reset = app.buttons["counter.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 10))
        reset.click()
        assertCount(0)
    }

    // macOS에서 SwiftUI Text의 문자열은 접근성 label이 아니라 value로 노출된다.
    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    private func assertCount(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let value = app.staticTexts["counter.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(text(of: value), "Count: \(expected)", file: file, line: line)
    }

    private func capture(_ name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
