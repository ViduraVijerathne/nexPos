import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_remote_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_local_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/models/models.dart';
import 'package:nex_pos_desktop/features/settings/services/app_settings_service.dart';
import 'package:nex_pos_desktop/features/subscription/services/subscription_usage_service.dart';

class _Usage extends SubscriptionUsageService {
  _Usage(FirebaseFirestore firestore) : super(firestore: firestore);
  int reads = 0;
  @override
  Future<void> recordRead({
    required String shopId,
    required String module,
    required int documentCount,
    Object? payload,
  }) async {
    reads += documentCount;
    await super.recordRead(
      shopId: shopId,
      module: module,
      documentCount: documentCount,
      payload: payload,
    );
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _Usage usage;
  late PosRemoteRepository repository;
  late DocumentReference<Map<String, dynamic>> shop;
  setUp(() async {
    firestore = FakeFirebaseFirestore();
    shop = firestore.collection('shops').doc('shop');
    usage = _Usage(firestore);
    repository = PosRemoteRepository(
      shopId: 'shop',
      firestore: firestore,
      usageService: usage,
    );
    await shop.set({'shopName': 'Test'});
    await shop.collection('products').doc('tea').set({
      'name': 'Tea',
      'barcode': 'tea',
      'category': 'Drinks',
      'isQuickSelling': true,
    });
    await shop.collection('stocks').doc('stock').set({
      'barcode': 'stock',
      'productBarcode': 'tea',
      'productName': 'Tea',
      'availableQuantity': 5,
      'sellingPrice': 10,
      'status': 'active',
    });
    await shop.collection('invoices').doc('old').set({
      'invoiceNumber': 'INV-000042',
      'items': [
        {'name': 'Tea', 'quantity': 3},
      ],
    });
  });

  Future<PosCheckoutResult> sell() => repository.processSale(
    items: const [
      PosCartItem(
        stockCloudId: 'stock',
        stockBarcode: 'stock',
        productBarcode: 'tea',
        productName: 'Tea',
        category: 'Drinks',
        retailPrice: 10,
        wholesalePrice: 10,
        unitPrice: 10,
        availableQty: 5,
        quantity: 1,
      ),
    ],
    customer: PosLocalRepository.walkInCustomer,
    paymentMethod: 'Cash',
    amountPaid: 10,
    cashPaidAmount: 10,
    cardPaidAmount: 0,
    cashierName: 'Test',
    discountAmount: 0,
    taxAmount: 0,
  );

  test(
    'search/category/barcode reuse cache without reading invoice history',
    () async {
      expect((await repository.fetchCatalog()).items.single.availableQty, 5);
      expect(usage.reads, 2);
      expect(
        (await repository.fetchCatalog(searchQuery: 'te')).items.length,
        1,
      );
      expect(
        (await repository.fetchCatalog(category: 'Drinks')).items.length,
        1,
      );
      expect(await repository.findExactCatalogMatch('tea'), isNotNull);
      expect(usage.reads, 2);
      expect(
        (await repository.fetchCatalog(
          loadMode: PosCatalogLoadMode.mostSelling,
        )).items.length,
        1,
      );
      expect(usage.reads, 3);
      await repository.fetchCatalog(loadMode: PosCatalogLoadMode.mostSelling);
      expect(usage.reads, 3);
      repository.invalidateCatalog();
      await repository.fetchCatalog();
      expect(usage.reads, 5);
    },
  );
  test(
    'migrates legacy sequence once and updates cached stock after sale',
    () async {
      await repository.fetchCatalog();
      expect((await sell()).invoiceNumber, 'INV-000043');
      final reads = usage.reads;
      expect((await repository.fetchCatalog()).items.single.availableQty, 4);
      expect(usage.reads, reads);
      expect((await sell()).invoiceNumber, 'INV-000044');
      expect(usage.reads, reads);
      expect((await shop.get()).data()!['invoiceSequence'], 44);
      expect(
        (await shop.collection('stocks').doc('stock').get())
            .data()!['availableQuantity'],
        3,
      );
      expect((await shop.collection('invoices').get()).docs.length, 3);
    },
  );
  test('usage increments preserve other modules and payment status', () async {
    final month =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final ref = shop.collection('subscription_usage').doc(month);
    await ref.set({
      'status': 'Paid',
      'reads': 7,
      'modules': {
        'products': {'reads': 7},
      },
    });
    await usage.recordRead(shopId: 'shop', module: 'pos', documentCount: 3);
    await usage.recordRead(shopId: 'shop', module: 'pos', documentCount: 2);
    final data = (await ref.get()).data()!;
    expect(data['reads'], 12);
    expect(data['status'], 'Paid');
    expect(data['modules']['products']['reads'], 7);
    expect(data['modules']['pos']['reads'], 5);
  });
  test(
    'usage permission failure cannot turn a committed sale into a failure',
    () async {
      firestore = FakeFirebaseFirestore(
        securityRules: '''
service cloud.firestore {
 match /databases/{database}/documents {
  match /shops/{shopId} { allow read, write: if true;
   match /{collection}/{doc} { allow read, write: if collection != 'subscription_usage'; }
  }
 }
}''',
      );
      final ref = firestore.collection('shops').doc('shop');
      await ref.set({'invoiceSequence': 0});
      await ref.collection('stocks').doc('stock').set({
        'availableQuantity': 5,
        'status': 'active',
      });
      repository = PosRemoteRepository(
        shopId: 'shop',
        firestore: firestore,
        usageService: SubscriptionUsageService(firestore: firestore),
      );
      expect((await sell()).invoiceNumber, 'INV-000001');
      expect((await ref.collection('invoices').get()).docs.length, 1);
    },
  );
}
