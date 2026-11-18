import AppKit
import SwiftUI
import XCTest

// 화면 밖 스냅샷: SwiftUI 뷰를 화면에 표시하지 않는 창에서 그려 PNG로 첨부한다.
// 마우스·키보드를 쓰지 않으므로 사용자가 작업 중이어도 실행할 수 있다.
// 실제 클릭 흐름은 UI 테스트(verify.sh full, CI)가 확인한다.
class SnapshotTestCase: XCTestCase {
    /// `name`은 `NN-상태-설명` 형식. 상태는 이 함수를 부르기 전에 assertion으로 확인한다.
    @MainActor
    func snapshot<V: View>(
        _ view: V,
        name: String,
        size: CGSize = CGSize(width: 760, height: 500),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)
        // 테두리 없는 창에 넣기만 하고 orderFront 하지 않는다: 화면에 나타나지 않는다.
        let window = NSWindow(
            contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("스냅샷 비트맵을 만들지 못했습니다: \(name)", file: file, line: line)
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        XCTAssertFalse(isSingleColor(rep), "빈 화면으로 그려졌습니다: \(name)", file: file, line: line)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG로 변환하지 못했습니다: \(name)", file: file, line: line)
            return
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func isSingleColor(_ rep: NSBitmapImageRep) -> Bool {
        guard let first = rep.colorAt(x: 0, y: 0) else { return true }
        let step = max(1, min(rep.pixelsWide, rep.pixelsHigh) / 40)
        for row in stride(from: 0, to: rep.pixelsHigh, by: step) {
            for col in stride(from: 0, to: rep.pixelsWide, by: step) where rep.colorAt(x: col, y: row) != first {
                return false
            }
        }
        return true
    }
}
