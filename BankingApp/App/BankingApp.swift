import SwiftUI

@main
struct BankingApp: App {
    init() {
        AppConfig.current.logSummary()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(AppColor.brand)
        }
    }
}
