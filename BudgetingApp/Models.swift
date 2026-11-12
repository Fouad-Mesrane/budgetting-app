import Foundation

enum Money {
    // Store exact cents, never floating-point balances. Input is capped at $1 billion.
    static func parse(_ text: String, locale: Locale = .current) -> Int64? {
        let separator = locale.decimalSeparator ?? "."
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: #"^[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value <= 1_000_000_000 else { return nil }
        return NSDecimalNumber(decimal: value * 100).int64Value
    }
    static func display(_ cents: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(cents) / 100)) ?? "$0.00"
    }
    static func input(_ cents: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(cents) / 100)) ?? "0"
    }
}

struct BudgetCategory: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var limit: Int64
}

struct MonthBudget: Codable, Equatable {
    var limit: Int64 = 500_000
    var categories: [BudgetCategory] = [
        .init(id: "housing", name: "Housing", limit: 200_000),
        .init(id: "food", name: "Food", limit: 80_000),
        .init(id: "transport", name: "Transport", limit: 50_000),
        .init(id: "bills", name: "Bills", limit: 70_000),
        .init(id: "other", name: "Other", limit: 100_000)
    ]
}

struct LedgerEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable { case expense, income }
    var id = UUID()
    var kind: Kind
    var date: Date
    var cents: Int64
    var categoryID: String?
    var note: String
}

struct Ledger: Codable, Equatable {
    var budgets: [String: MonthBudget] = [:]
    var entries: [LedgerEntry] = []
    static func monthKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year!, parts.month!)
    }
    func budget(for date: Date) -> MonthBudget { budgets[Self.monthKey(date)] ?? MonthBudget() }
    func entries(for date: Date) -> [LedgerEntry] {
        entries.filter { Self.monthKey($0.date) == Self.monthKey(date) }.sorted { $0.date > $1.date }
    }
    func total(for date: Date, kind: LedgerEntry.Kind, categoryID: String? = nil) -> Int64 {
        entries(for: date).filter { $0.kind == kind && (categoryID == nil || $0.categoryID == categoryID) }
            .reduce(0) { $0 + $1.cents }
    }
    func remaining(for date: Date) -> Int64 { budget(for: date).limit - total(for: date, kind: .expense) }
}
