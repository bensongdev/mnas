import SwiftUI

struct ContentView: View {
    @State private var count = Counter.initialValue

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Native Starter")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("app.title")

            Text("검증 가능한 macOS 앱 개발 템플릿")
                .foregroundStyle(.secondary)

            Text("Count: \(count)")
                .font(.title2.monospacedDigit())
                .accessibilityIdentifier("counter.value")

            HStack {
                Button("Increment") {
                    count = Counter.increment(count)
                }
                .accessibilityIdentifier("counter.increment")

                Button("Reset") {
                    count = Counter.reset()
                }
                .accessibilityIdentifier("counter.reset")
            }
        }
        .padding(36)
        .frame(minWidth: 520, minHeight: 350)
    }
}
