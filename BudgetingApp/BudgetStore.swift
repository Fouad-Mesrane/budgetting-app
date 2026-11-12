import Foundation
import Combine

@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var ledger = Ledger()
    @Published var errorMessage: String?
    private var loadFailed = false
    private let fileURL: URL

    init() {
        fileURL = URL.applicationSupportDirectory.appending(path: "BudgetingApp/ledger.json")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: fileURL))
            }
        } catch {
            loadFailed = true
            errorMessage = "Your saved data could not be opened. Changes are disabled to protect it. Close the app and restore a backup before continuing."
        }
    }

    @discardableResult
    func update(_ mutation: (inout Ledger) -> Void) -> Bool {
        guard !loadFailed else {
            errorMessage = "Saved data could not be loaded. Nothing has been overwritten."
            return false
        }
        var next = ledger
        mutation(&next)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtection])
            ledger = next
            return true
        } catch {
            errorMessage = "Your change could not be saved. Please check available storage and try again."
            return false
        }
    }
}
