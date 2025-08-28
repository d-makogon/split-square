import SwiftUI

@main
struct SplitSquareApp: App {
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            GroupsListView()
                .environmentObject(appRouter)
                .onOpenURL { url in
                    appRouter.handleIncomingURL(url)
                }
        }
    }
}
