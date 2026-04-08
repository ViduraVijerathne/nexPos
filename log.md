# Development Log

## 2026-04-08

- Created a reusable theme foundation with `AppColors` and `AppTheme`.
- Added `google_fonts` and applied the Inter text theme across the app.
- Replaced the default Flutter counter screen with a simple POS starter dashboard.
- Updated the widget test to validate the new app shell and starter content.
- Formatted the codebase with `dart format lib test`.
- Verified the project with `flutter test` and confirmed all tests passed.
- Removed the runtime `google_fonts` dependency to prevent offline font loading failures.
- Switched the shared app theme to an offline-safe local text theme with sensible fallbacks.
- Re-synced macOS CocoaPods with `pod install` after the workspace reported `Manifest.lock` was out of sync.
- Verified the desktop target with `flutter build macos --debug` and confirmed the macOS app builds successfully.
- Replaced the starter screen with a login experience closely matching the provided reference.
- Added reusable auth widgets for form fields and the loading login button.
- Built an application-wide toast overlay with success, error, and info variants inspired by React-Toastify.
- Validated the new login flow with `flutter test`.
- Verified the macOS target again with `flutter build macos --debug` after the auth UI update.
- Rebuilt the dashboard to match the provided admin layout with sidebar navigation, top account bar, KPI cards, chart, and stock panels.
- Added reusable dashboard sections and custom-painted visual components for the sales chart and stock allocation chart.
- Validated the updated dashboard with `flutter test` and `flutter build macos --debug`.
- Replaced the dashboard workspace with a point-of-sale screen that matches the provided POS reference layout.
- Added reusable POS sections for product browsing, category filters, order summary, customer selection, and payment method controls.
- Validated the POS page with `flutter test` and `flutter build macos --debug`.
- Updated the POS category chips to display as a horizontal strip directly below the product search field.
- Refactored the dashboard into a navigation shell with separate page files for `insight`, `pos`, and `products`.
- Added file-based placeholder pages for additional dashboard modules so sidebar navigation swaps the right-side workspace correctly.
- Validated the dashboard navigation refactor with `flutter test` and `flutter build macos --debug`.
- Replaced the dummy products page with a full products management screen including search filters, table layout, pagination footer, and edit actions.
- Added add/edit product dialogs with barcode generation, unit and status dropdowns, and category autosuggest with inline new-category creation when no match exists.
- Validated the products module update with `flutter test` and `flutter build macos --debug`.
- Replaced the Stocks placeholder with a full stock management page including summary cards, filters, stock table, details modal, and add/edit stock dialogs.
- Added barcode generation to the stock dialog and autosuggest inputs for both product and GRN selection.
- Validated the stocks module update with `flutter test` and `flutter build macos --debug`.
- Added expand/collapse support for the `Search & Filter Stocks` section.
- Replaced the GRN placeholder with a full goods received notes page including list view, create dialog, details dialog, and due payment dialog.
- Added GRN item building with product autosuggest, totals summary, and payment history/details presentation.
- Validated the GRN module update with `flutter test` and `flutter build macos --debug`.
- Added supplier autosuggest support to the create GRN dialog.

- Replaced the Supplies placeholder with a full supplier management page including searchable supplier cards, add supplier dialog, supplier details modal, and supplier due payment flow.
- Changed the supplier listing from card view to a table view for better desktop readability.
- Replaced the Customers placeholder with a full customer management page including filters, customer table, add/edit dialog, and customer details modal with invoice history.
- Replaced the Invoice placeholder with a full invoice management page including summary cards, filters, paginated invoice table, invoice details dialog, and print actions.
- Extracted shared dashboard data models into `lib/features/dashboard/models/models.dart` and updated the product, stock, GRN, supplier, customer, and invoice UIs to use the shared model layer.
- Added Isar entity classes and schema exports for products, stocks, GRNs, suppliers, customers, and invoices in `lib/core/database/entities`.
- Added a first-launch activation flow with device ID display, copy action, activation key input, and persisted activation state before login.
- Added a debug delete action on the login page to clear stored activation data and return the app to the activation screen.
- Added a first-run setup wizard after activation with version selection, admin account creation, PIN setup, default login method selection, shop information capture, setup resume logic, and login integration with stored credentials/PIN.
