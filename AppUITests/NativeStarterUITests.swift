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
        // 창 모서리가 둥글어 바깥에 다른 앱 화면이 비친다. 그 부분을 지워서 첨부한다.
        let window = app.windows.firstMatch
        guard let png = WindowScreenshot.maskedPNG(window.screenshot(), pointWidth: window.frame.width) else {
            XCTFail("스크린샷 모서리를 지우지 못했습니다: \(name)")
            return
        }
        XCTAssertTrue(
            WindowScreenshot.cornersAreTransparent(png, pointWidth: window.frame.width),
            "스크린샷 모서리가 지워지지 않았습니다: \(name)"
        )
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
