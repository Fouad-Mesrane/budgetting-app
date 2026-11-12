import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var month = Date()
    @State private var showEntry = false
    @State private var showBudget = false
    @State private var pendingDelete: LedgerEntry?
    private var budget: MonthBudget { store.ledger.budget(for: month) }
    private var remaining: Int64 { store.ledger.remaining(for: month) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                        Spacer()
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next month")
                    }.buttonStyle(.borderless)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(remaining < 0 ? "OVER MONTHLY BUDGET" : "LEFT TO SPEND").font(.caption.weight(.semibold))
                        Text(Money.display(remaining)).font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(remaining < 0 ? Color.red : Color.primary)
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text("of \(Money.display(budget.limit)) monthly limit").foregroundStyle(.secondary)
                        if remaining < 0 {
                            Label("Monthly limit exceeded by \(Money.display(-remaining))", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }.padding(.vertical, 8)
                    LabeledContent("Expenses", value: Money.display(store.ledger.total(for: month, kind: .expense)))
                    LabeledContent("Income", value: Money.display(store.ledger.total(for: month, kind: .income)))
                    Text("Income is tracked separately and does not raise your spending limit.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Category budgets") {
                    ForEach(budget.categories) { category in
                        let spent = store.ledger.total(for: month, kind: .expense, categoryID: category.id)
                        let left = category.limit - spent
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category.name).font(.headline)
                                Spacer()
                                Text(Money.display(left)).monospacedDigit()
                            }
                            ProgressView(value: min(Double(spent), Double(max(category.limit, 1))), total: Double(max(category.limit, 1)))
                                .tint(left < 0 ? .red : .teal)
                            Text("\(Money.display(spent)) spent of \(Money.display(category.limit))")
                                .font(.caption)
                            if left < 0 {
                                Label("Over budget by \(Money.display(-left))", systemImage: "exclamationmark.triangle.fill").font(.caption)
                            } else { Text("Remaining").font(.caption) }
                        }.foregroundStyle(left < 0 ? Color.red : Color.primary).padding(.vertical, 4)
                    }
                }

                Section("Transactions") {
                    if store.ledger.entries(for: month).isEmpty {
                        ContentUnavailableView("Your month starts here", systemImage: "plus.circle", description: Text("Add your first expense or income entry."))
                    }
                    ForEach(store.ledger.entries(for: month)) { entry in
                        HStack {
                            Image(systemName: entry.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle")
                                .foregroundStyle(entry.kind == .income ? Color.teal : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(entry.note.isEmpty ? entryTitle(entry) : entry.note)
                                Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entryTitle(entry))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.kind == .income ? "+" : "−")\(Money.display(entry.cents))").monospacedDigit()
                        }.swipeActions {
                            Button("Delete", role: .destructive) { pendingDelete = entry }
                        }
                    }
                }
            }
            .navigationTitle("My budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Edit budgets") { showBudget = true } }
                ToolbarItem(placement: .topBarTrailing) { Button { showEntry = true } label: { Label("Add entry", systemImage: "plus") } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    HStack {
                        Text(remaining < 0 ? "Monthly overage" : "Monthly remaining")
                        Spacer()
                        Text(Money.display(remaining < 0 ? -remaining : remaining)).bold().monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundStyle(remaining < 0 ? Color.red : Color.primary)
                    Button { showEntry = true } label: { Label("Add expense or income", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(8) }
                        .buttonStyle(.borderedProminent).tint(.teal)
                }.padding().background(.regularMaterial)
            }
            .sheet(isPresented: $showEntry) { EntryEditor(month: month) }
            .sheet(isPresented: $showBudget) { BudgetEditor(month: month, initial: budget) }
            .alert("Unable to save or load", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .confirmationDialog("Delete this transaction?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete transaction", role: .destructive) {
                    if let entry = pendingDelete { store.update { $0.entries.removeAll { $0.id == entry.id } } }
                    pendingDelete = nil
                }
            }
        }
    }
    private func moveMonth(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: month)!.start
        month = Calendar.current.date(byAdding: .month, value: offset, to: start)!
    }
    private func entryTitle(_ entry: LedgerEntry) -> String {
        entry.kind == .income ? "Income" : budget.categories.first { $0.id == entry.categoryID }?.name ?? "Expense"
    }
}

struct EntryEditor: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let month: Date
    @State private var kind: LedgerEntry.Kind = .expense
    @State private var amount = ""
    @State private var categoryID = "housing"
    @State private var note = ""
    @State private var date: Date
    @State private var savedWarning: String?
    @State private var saveError = false

    init(month: Date) {
        self.month = month
        _date = State(initialValue: Ledger.monthKey(month) == Ledger.monthKey(Date()) ? Date() : Calendar.current.dateInterval(of: .month, for: month)!.start)
    }
    private var validAmount: Int64? { Money.parse(amount).flatMap { $0 > 0 ? $0 : nil } }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Expense").tag(LedgerEntry.Kind.expense)
                    Text("Income").tag(LedgerEntry.Kind.income)
                }.pickerStyle(.segmented)
                Section("Amount in USD") {
                    TextField("0.00", text: $amount).keyboardType(.decimalPad)
                    if !amount.isEmpty && validAmount == nil { Text("Enter a positive amount with up to two decimal places (maximum $1 billion).").font(.caption).foregroundStyle(.red) }
                }
                DatePicker("Date", selection: $date, in: monthRange, displayedComponents: .date)
                if kind == .expense {
                    Picker("Category", selection: $categoryID) {
                        ForEach(store.ledger.budget(for: month).categories) { Text($0.name).tag($0.id) }
                    }
                }
                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("New entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(validAmount == nil || savedWarning != nil) }
            }
            .alert("Entry saved · over budget", isPresented: Binding(get: { savedWarning != nil }, set: { if !$0 { dismiss() } })) {
                Button("OK") { dismiss() }
            } message: { Text(savedWarning ?? "") }
            .alert("Entry not saved", isPresented: $saveError) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "Please try again.") }
        }
    }
    private var monthRange: ClosedRange<Date> {
        let interval = Calendar.current.dateInterval(of: .month, for: month)!
        return interval.start...interval.end.addingTimeInterval(-1)
    }
    private func save() {
        guard let cents = validAmount else { return }
        let entry = LedgerEntry(kind: kind, date: date, cents: cents, categoryID: kind == .expense ? categoryID : nil, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        guard store.update({ $0.entries.append(entry) }) else { saveError = true; return }
        var warnings: [String] = []
        if kind == .expense {
            let budget = store.ledger.budget(for: month)
            if let category = budget.categories.first(where: { $0.id == categoryID }) {
                let over = store.ledger.total(for: month, kind: .expense, categoryID: categoryID) - category.limit
                if over > 0 { warnings.append("\(category.name) is over budget by \(Money.display(over)).") }
            }
            let remaining = store.ledger.remaining(for: month)
            if remaining < 0 { warnings.append("Your monthly limit is exceeded by \(Money.display(-remaining)).") }
        }
        if warnings.isEmpty { dismiss() } else { savedWarning = warnings.joined(separator: "\n") }
    }
}

struct BudgetEditor: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let month: Date
    @State private var limit: String
    @State private var categories: [BudgetCategory]
    @State private var amounts: [String: String]
    @State private var saveError = false

    init(month: Date, initial: MonthBudget) {
        self.month = month
        _limit = State(initialValue: Money.input(initial.limit))
        _categories = State(initialValue: initial.categories)
        _amounts = State(initialValue: Dictionary(uniqueKeysWithValues: initial.categories.map { ($0.id, Money.input($0.limit)) }))
    }
    private var valid: Bool {
        Money.parse(limit) != nil && categories.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Money.parse(amounts[$0.id] ?? "") != nil
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("\(month.formatted(.dateTime.month(.wide).year())) · USD") {
                    TextField("Monthly limit", text: $limit).keyboardType(.decimalPad)
                    Text("This limit stays fixed regardless of income. Changes apply only to this month.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Category limits") {
                    ForEach($categories) { $category in
                        VStack(alignment: .leading) {
                            TextField("Category name", text: $category.name)
                            TextField("Budget", text: Binding(get: { amounts[category.id] ?? "" }, set: { amounts[category.id] = $0 }))
                                .keyboardType(.decimalPad).accessibilityLabel("\(category.name) budget")
                        }
                    }
                    Button("Add category") {
                        let id = UUID().uuidString
                        categories.append(.init(id: id, name: "New category", limit: 0))
                        amounts[id] = "0.00"
                    }
                    Text("Category allocations: \(Money.display(categories.reduce(0) { $0 + (Money.parse(amounts[$1.id] ?? "") ?? 0) }))").font(.caption)
                    Text("Category limits and the overall monthly limit are tracked independently.").font(.caption).foregroundStyle(.secondary)
                }
                if !valid { Text("Enter names and nonnegative amounts with up to two decimal places.").foregroundStyle(.red) }
            }
            .navigationTitle("Edit budgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let cents = Money.parse(limit), valid else { return }
                    var updated = MonthBudget()
                    updated.limit = cents
                    updated.categories = categories.map { category in
                        var result = category
                        result.name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        result.limit = Money.parse(amounts[category.id] ?? "")!
                        return result
                    }
                    if store.update({ $0.budgets[Ledger.monthKey(month)] = updated }) { dismiss() } else { saveError = true }
                }.disabled(!valid) }
            }
            .alert("Budget not saved", isPresented: $saveError) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "Please try again.") }
        }
    }
}
