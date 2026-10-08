# POS reliability and usability review

The `dev` branch improves checkout correctness and speed, reduces repeated cloud reads, and adapts billing and data tables to smaller screens.

## Behavior

- Sales validate payments and stock, aggregate repeated stock lines, round totals to cents, and commit invoice and stock changes atomically.
- Online invoice numbering uses a transactional shop counter. Existing invoice history is scanned once when migrating a shop without a counter.
- Online catalogs reuse stock for 30 seconds, products for five minutes, and customer results for one minute. The Refresh products action invalidates these caches. Checkout always checks current stock in the transaction.
- Invoice history is loaded for the Most Selling catalog mode, rather than every ordinary catalog search.
- Usage counters use atomic increments. Metering failures do not report a committed bill as failed. Storage estimation refreshes at most once per shop every 15 minutes in a process.
- Checkout provides Exact Cash and a receipt toggle, protects a pending checkout against duplicate submission, confirms discarding a cart, and preserves the POS page when navigating between dashboard sections.
- Mobile billing uses Products, Cart and Checkout tabs. Tablets use two columns and desktops three. Short screens scroll; customer, supplier, invoice and GRN tables scroll horizontally and their filters stack.
- Receipt errors identify the bill as saved. Restaurant KOT processing remains available when the receipt toggle is off.
- Offline backup restore stages and validates an Isar backup before replacing the live database. Online restores reject incomplete backups and read the source before changing destination collections.
- Barcode lookup errors leave the cart intact and allow a retry. Stock deactivation reads and writes inside the same transaction so it cannot restore quantities consumed by a concurrent sale.
- Supplier payments are validated and serialized locally. Online GRN creation and pending-stock insertion commit the GRN and stock together; retrying cannot duplicate an already completed insertion.

## Verification

Use Flutter 3.35.7, matching the existing dependency lockfile:

```bash
export CI=true
export XDG_CONFIG_HOME=/workspace/.config
export PUB_CACHE=/workspace/.pub-cache
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.dartServer
/workspace/flutter-sdk/bin/flutter pub get --enforce-lockfile
/workspace/flutter-sdk/bin/flutter test --no-pub
/workspace/flutter-sdk/bin/flutter analyze --no-pub
```

Regression tests cover concurrent local sales/payments, stock rollback, decimal cash, remote cache/counter behavior, remote GRN retry safety, corrupt backup protection, immediate search submission, and duplicate checkout prevention. Billing layout tests exercise 320, 390, 640, 800, 1024, 1440 and 1920 pixel widths, including a short landscape viewport and enlarged text.

Cloud tests use fake Firestore; real security rules, contention retries, printers, and physical devices still require integration testing. The cloud environment has no Android SDK or complete native desktop build toolchain. Existing analyzer warnings and deprecation notices remain. A multi-batch online restore can still be interrupted after some destination writes; take a current backup before restoration. These checks do not certify that every possible bug or device combination has been covered.
