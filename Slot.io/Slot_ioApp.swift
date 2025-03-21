import SwiftUI

@main
struct Slot_io: App {
    @StateObject private var gameVM = GameViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(gameVM)
        }
    }
}
