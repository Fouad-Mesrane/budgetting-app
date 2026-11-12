// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetCore",
    products: [.library(name: "BudgetCore", targets: ["BudgetCore"])],
    targets: [
        .target(name: "BudgetCore", path: "BudgetingApp", exclude: ["BudgetStore.swift", "BudgetingApp.swift", "DashboardView.swift"], sources: ["Models.swift"]),
        .testTarget(name: "BudgetCoreTests", dependencies: ["BudgetCore"], path: "Tests")
    ]
)
