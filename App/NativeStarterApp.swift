import AppKit
import SwiftUI

// 단위 테스트는 이 앱을 테스트 호스트로 실행한다. 그때는 창을 띄우거나 앞으로 나오지 않게 해서
// 테스트 중에도 사용자의 작업을 방해하지 않는다. UI 테스트로 실행한 앱에는 이 환경 변수가 없다.
@main
enum AppEntry {
    static func main() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            TestHostApp.main()
        } else {
            NativeStarterApp.main()
        }
    }
}

struct NativeStarterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 760, height: 500)
    }
}

private struct TestHostApp: App {
    @NSApplicationDelegateAdaptor(TestHostDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

private final class TestHostDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Dock에 나타나지 않고 활성화(앞으로 나오기)도 하지 않는다.
        NSApp.setActivationPolicy(.prohibited)
    }
}
