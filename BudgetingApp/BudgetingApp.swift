import SwiftUI

@main
struct BudgetingApp: App {
    @StateObject private var store = BudgetStore()
    var body: some Scene {
        WindowGroup { DashboardView().environmentObject(store) }
    }
}
