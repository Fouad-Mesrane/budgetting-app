# Budgeting App for iPhone

A small native SwiftUI app for manual personal budgeting. iOS 17 or later; USD amounts. No account, server, bank connection, analytics, or third-party dependencies.

## First version

- A calendar-month spending limit, initially $5,000, editable separately for each month.
- Editable category names and budgets, plus new categories. Starting allocations: Housing $2,000; Food $800; Transport $500; Bills $700; Other $1,000.
- Dated manual expense and income entries, optional notes, and confirmed transaction deletion.
- Monthly remaining budget = monthly limit minus expenses. Income is summed separately and never increases spending limits.
- Red category/overall warnings and a saved-entry alert when expenses exceed limits. Overspending remains recordable and negative remainders remain visible.
- Previous/next month navigation. New months start with the default allocations; edits do not change other months.
- On-device JSON persistence, atomic writes, and file protection. Failed saves do not change the visible ledger; unreadable existing data is not overwritten.

Category allocations and the overall spending cap are independent; allocating more to categories does not raise the monthly cap. A zero limit is valid. Currency entry accepts the device's decimal separator and up to two decimal places, with a maximum of $1 billion per entry/limit. Amounts are stored as integer cents.

## Run on a Mac

1. Open `BudgetingApp.xcodeproj` in Xcode 15 or later.
2. Choose the **BudgetingApp** scheme and an iPhone simulator, then Run.
3. For your own iPhone, select your Apple development team under Signing & Capabilities and use a unique bundle identifier.

No signing team or credentials are committed. App Store distribution, final branding/app icon, and commercial release preparation are outside this first version.

## Verification

On a Mac with Xcode installed:

```sh
swift test
xcodebuild -project BudgetingApp.xcodeproj -scheme BudgetingApp -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The Swift package tests exercise the same model file used by the iOS app: exact cents, income separation, category/monthly overages, month isolation, deletion, and serialization. Tests do not require external packages.

Manual simulator checks:

1. Add $900 income: remaining stays $5,000.
2. Add $850 Food expense: remaining becomes $4,150; Food shows $50 over and a warning.
3. Add $4,200 Housing expense: monthly remainder becomes −$50, with both category and monthly warnings.
4. Delete the last expense: remaining returns to $4,150.
5. Relaunch: entries and budgets persist.
6. Switch month and edit its limit: prior month's budget remains unchanged.
7. Verify decimal entry, large text, VoiceOver labels, dark mode, and narrow iPhone layouts.

Implementation was authored on Windows, where Swift/Xcode and an iOS simulator were unavailable. GitHub's macOS runner successfully executed all five budget tests and compiled the iPhone simulator app. The [build history](https://github.com/Fouad-Mesrane/budgetting-app/actions/workflows/ios.yml) records those checks. Local project references, shared-scheme XML, and whitespace checks also passed.

An iOS simulator build is a compilation check, not interactive simulator verification. Launching the app, visual/accessibility review, signing, and physical iPhone testing still need to be completed on a Mac/device before release.

Data is local to the app installation. Deleting the app can delete its records. There is no export/sync flow in this version. Dates use the device's calendar/time zone; changing those settings may affect month grouping.
