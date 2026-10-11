import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_pos_desktop/features/dashboard/data/grn_remote_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/models/models.dart';
import 'package:nex_pos_desktop/features/subscription/services/subscription_usage_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GrnRemoteRepository repository;
  const record = GrnRecord(
    id: 'GRN-001',
    supplier: 'Supplier',
    date: '2026-10-08',
    subTotal: 20,
    discount: 0,
    paidAmount: 0,
    paymentHistory: [],
    items: [
      GrnItem(
        product: 'Tea',
        stockBarcode: 'stock-1',
        quantity: 2,
        buyingPrice: 10,
        sellingPrice: 15,
        inStock: false,
      ),
    ],
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    repository = GrnRemoteRepository(
      shopId: 'shop',
      firestore: firestore,
      usageService: SubscriptionUsageService(firestore: firestore),
    );
    await firestore.collection('shops/shop/products').doc('tea').set({
      'name': 'Tea',
      'barcode': 'tea',
    });
  });
  test(
    'saving stock and GRN is atomic and retry cannot create duplicate stock',
    () async {
      await repository.saveGrn(record, addToStock: true);
      await expectLater(
        repository.saveGrn(record, addToStock: true),
        throwsA(isA<GrnRemoteRepositoryException>()),
      );
      final stocks = await firestore.collection('shops/shop/stocks').get();
      expect(stocks.docs, hasLength(1));
      expect(stocks.docs.single.data()['productBarcode'], 'tea');
      expect(
        (await repository.fetchGrnById(record.id))!.items.single.inStock,
        isTrue,
      );
    },
  );
  test('adding pending stock twice creates only one stock entry', () async {
    await repository.saveGrn(record, addToStock: false);
    expect(
      (await firestore.collection('shops/shop/stocks').get()).docs,
      isEmpty,
    );
    await repository.addPendingItemsToStock(record.id);
    await repository.addPendingItemsToStock(record.id);
    final stocks = await firestore.collection('shops/shop/stocks').get();
    expect(stocks.docs, hasLength(1));
    expect(stocks.docs.single.data()['availableQuantity'], 2);
    expect(stocks.docs.single.data()['productBarcode'], 'tea');
  });
}
