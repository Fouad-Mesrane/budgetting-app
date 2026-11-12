import XCTest
@testable import BudgetCore

final class BudgetCoreTests: XCTestCase {
    private func date(_ month: Int, _ day: Int = 15) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }
    func testIncomeNeverRaisesRemainingBudget() {
        var ledger = Ledger()
        ledger.entries = [
            .init(kind: .income, date: date(11), cents: 900_000, note: "Salary"),
            .init(kind: .expense, date: date(11), cents: 120_000, categoryID: "housing", note: "Rent")
        ]
        XCTAssertEqual(ledger.remaining(for: date(11)), 380_000)
        XCTAssertEqual(ledger.total(for: date(11), kind: .income), 900_000)
    }
    func testOveragesAreRetainedAndCategoryTotalsAreIndependent() {
        var ledger = Ledger()
        ledger.entries = [
            .init(kind: .expense, date: date(11), cents: 550_000, categoryID: "food", note: ""),
            .init(kind: .expense, date: date(11), cents: 1_001, categoryID: "other", note: "")
        ]
        XCTAssertEqual(ledger.remaining(for: date(11)), -51_001)
        XCTAssertEqual(ledger.total(for: date(11), kind: .expense, categoryID: "food"), 550_000)
    }
    func testMonthlyBudgetsAndTransactionsDoNotLeakAcrossMonths() {
        var ledger = Ledger()
        ledger.budgets[Ledger.monthKey(date(11))] = MonthBudget(limit: 300_000)
        ledger.entries = [.init(kind: .expense, date: date(11, 30), cents: 10_000, categoryID: "food", note: "")]
        XCTAssertEqual(ledger.remaining(for: date(11)), 290_000)
        XCTAssertEqual(ledger.remaining(for: date(12, 1)), 500_000)
    }
    func testExactCentsAndInvalidAmounts() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(Money.parse("0.29", locale: locale), 29)
        XCTAssertEqual(Money.parse("5000", locale: locale), 500_000)
        XCTAssertEqual(Money.parse("0", locale: locale), 0)
        for input in ["-1", "1.001", "NaN", "", "12abc", "1e3", "1000000001"] {
            XCTAssertNil(Money.parse(input, locale: locale), input)
        }
        XCTAssertEqual(Money.parse("12,34", locale: Locale(identifier: "fr_FR")), 1234)
    }
    func testDeletingExpenseRestoresBudgetAndRoundTripPreservesData() throws {
        var ledger = Ledger()
        ledger.entries = [.init(kind: .expense, date: date(11), cents: 1999, categoryID: "food", note: "Lunch")]
        let restored = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored, ledger)
        ledger.entries.removeAll()
        XCTAssertEqual(ledger.remaining(for: date(11)), 500_000)
    }
}
