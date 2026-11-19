import AppKit
import XCTest

/// 창 스크린샷의 둥근 모서리 바깥을 투명하게 지운다.
/// `XCUIElement.screenshot()`은 창의 사각형 영역을 그대로 찍으므로, 둥근 모서리 바깥에
/// 뒤에 있던 다른 앱의 화면(개인 정보가 있을 수 있음)이 섞인다.
/// Xcode 16 SDK에서는 `XCUIScreenshot.image`가 메인 액터 전용이라 메인 액터에서 실행한다
/// (Swift 6 언어 모드에서는 이게 없으면 컴파일 오류).
@MainActor
enum WindowScreenshot {
    /// macOS 26 창 모서리 반지름(포인트)보다 넉넉하게 잡는다. 창 테두리가 조금 깎이는 것은 감수한다.
    static let cornerRadius: CGFloat = 28

    /// 모서리를 지운 PNG. 실패하면 nil(호출한 쪽에서 테스트를 실패시킨다).
    /// `pointWidth`는 찍은 요소의 폭(포인트, `element.frame.width`). 스크린샷 이미지 크기는 픽셀 단위라
    /// 레티나 배율을 여기서 구한다.
    static func maskedPNG(_ screenshot: XCUIScreenshot, pointWidth: CGFloat) -> Data? {
        let image = screenshot.image
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              pointWidth > 0 else { return nil }
        let width = source.width, height = source.height
        let scale = CGFloat(width) / pointWidth
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let radius = cornerRadius * scale
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(source, in: rect)
        guard let masked = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: masked).representation(using: .png, properties: [:])
    }

    /// 네 모서리 안쪽(모서리에서 반지름의 20% 지점)이 투명한지. 이 점은 둥근 모서리 바깥이므로
    /// 배율을 잘못 계산해 일부만 지웠다면 불투명하게 남아 실패한다.
    static func cornersAreTransparent(_ png: Data, pointWidth: CGFloat) -> Bool {
        guard let rep = NSBitmapImageRep(data: png), pointWidth > 0 else { return false }
        let inset = Int(cornerRadius * CGFloat(rep.pixelsWide) / pointWidth * 0.2)
        let maxX = rep.pixelsWide - 1 - inset, maxY = rep.pixelsHigh - 1 - inset
        guard inset > 0, maxX > inset, maxY > inset else { return false }
        let points = [(inset, inset), (maxX, inset), (inset, maxY), (maxX, maxY)]
        return points.allSatisfy { rep.colorAt(x: $0.0, y: $0.1)?.alphaComponent == 0 }
    }
}
