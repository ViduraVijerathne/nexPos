import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'supplier_repository.dart';

class SupplierLocalRepositoryException implements Exception {
  SupplierLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupplierLocalRepository implements SupplierRepository {
  const SupplierLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    final isar = await AppDatabase.instance;
    await _seedIfNeeded(isar);
  }

  Future<SupplierPageResult> fetchSuppliers({
    required int page,
    String? searchQuery,
  }) async {
    final isar = await AppDatabase.instance;
    final suppliers = await isar.supplierEntitys.where().findAll();
    final grns = await isar.grnEntitys.where().findAll();
    final grnsBySupplier = _groupGrnsBySupplier(grns);

    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';
    final filteredSuppliers =
        suppliers.where((supplier) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return supplier.supplierName.toLowerCase().contains(
                normalizedQuery,
              ) ||
              supplier.companyName.toLowerCase().contains(normalizedQuery) ||
              supplier.email.toLowerCase().contains(normalizedQuery) ||
              supplier.contactNumber.toLowerCase().contains(normalizedQuery) ||
              (supplier.companyContact ?? '').toLowerCase().contains(
                normalizedQuery,
              );
        }).toList()..sort((left, right) {
          final leftDate = left.updatedAt ?? left.createdAt;
          final rightDate = right.updatedAt ?? right.createdAt;
          return rightDate.compareTo(leftDate);
        });

    final totalCount = filteredSuppliers.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <SupplierEntity>[]
        : filteredSuppliers.sublist(start, end);

    return SupplierPageResult(
      suppliers: pageItems
          .map(
            (supplier) => _mapSupplierEntityToRecord(
              supplier,
              grnsBySupplier[supplier.id] ?? const <GrnEntity>[],
            ),
          )
          .toList(),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  Future<SupplierRecord?> fetchSupplierDetails(SupplierRecord supplier) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.supplierEntitys.get(supplier.id);
    if (entity == null) {
      return null;
    }

    final grns = await _fetchGrnsForSupplier(isar, entity);
    return _mapSupplierEntityToRecord(entity, grns);
  }

  Future<SupplierRecord> saveSupplier(SupplierRecord supplier) async {
    final isar = await AppDatabase.instance;

    return isar.writeTxn<SupplierRecord>(() async {
      final existingByEmail = await isar.supplierEntitys
          .filter()
          .emailEqualTo(supplier.email.trim(), caseSensitive: false)
          .findFirst();
      if (existingByEmail != null && existingByEmail.id != supplier.id) {
        throw SupplierLocalRepositoryException(
          'A supplier with this email already exists',
        );
      }

      final existing = supplier.id <= 0
          ? null
          : await isar.supplierEntitys.get(supplier.id);

      if (supplier.id > 0 && existing == null) {
        throw SupplierLocalRepositoryException(
          'Supplier no longer exists. Reload before editing.',
        );
      }
      final now = DateTime.now();
      final entity = SupplierEntity()
        ..id = supplier.id > 0 ? supplier.id : Isar.autoIncrement
        ..supplierName = supplier.supplierName.trim()
        ..companyName = supplier.companyName.trim()
        ..contactNumber = supplier.contactNumber.trim()
        ..companyContact = supplier.companyContact.trim().isEmpty
            ? null
            : supplier.companyContact.trim()
        ..email = supplier.email.trim()
        ..address = supplier.address.trim()
        ..isActive = supplier.isActive
        ..createdAt = existing?.createdAt ?? now
        ..updatedAt = existing == null ? null : now;

      final savedId = await isar.supplierEntitys.put(entity);
      return supplier.copyWith(
        id: savedId,
        supplierName: entity.supplierName,
        companyName: entity.companyName,
        contactNumber: entity.contactNumber,
        companyContact: entity.companyContact ?? '',
        email: entity.email,
        address: entity.address,
      );
    });
  }

  Future<SupplierRecord?> toggleSupplierStatus(SupplierRecord supplier) async {
    final isar = await AppDatabase.instance;
    final changed = await isar.writeTxn<bool>(() async {
      final entity = await isar.supplierEntitys.get(supplier.id);
      if (entity == null) return false;
      entity
        ..isActive = !entity.isActive
        ..updatedAt = DateTime.now();
      await isar.supplierEntitys.put(entity);
      return true;
    });
    if (!changed) return null;

    return fetchSupplierDetails(supplier);
  }

  Future<SupplierRecord?> recordDuePayment({
    required SupplierRecord supplier,
    required String grnId,
    required double amount,
    required String method,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw SupplierLocalRepositoryException('Invalid payment amount');
    }
    final isar = await AppDatabase.instance;
    await isar.writeTxn(() async {
      final grn = await isar.grnEntitys.filter().codeEqualTo(grnId).findFirst();
      if (grn == null) {
        throw SupplierLocalRepositoryException('GRN not found');
      }

      final currentDue = (grn.total - grn.paidAmount).clamp(0, double.infinity);
      if (amount <= 0 || amount > currentDue) {
        throw SupplierLocalRepositoryException('Invalid payment amount');
      }

      final payment = GrnPaymentEmbedded()
        ..paidAt = DateTime.now()
        ..amount = amount
        ..method = method
        ..remainingBalance = (currentDue - amount).clamp(0, double.infinity);

      grn
        ..paidAmount = grn.paidAmount + amount
        ..updatedAt = DateTime.now()
        ..paymentHistory = <GrnPaymentEmbedded>[...grn.paymentHistory, payment];

      await isar.grnEntitys.put(grn);
    });

    return fetchSupplierDetails(supplier);
  }

  Future<void> _seedIfNeeded(Isar isar) async {
    final hasSuppliers = await isar.supplierEntitys.count() > 0;
    if (hasSuppliers) {
      return;
    }

    final now = DateTime.now();
    final supplierSeeds = <SupplierEntity>[
      // SupplierEntity()
      //   ..supplierName = 'apple'
      //   ..companyName = 'Uva wellassa university Sri lanka'
      //   ..contactNumber = '0733'
      //   ..companyContact = '29922'
      //   ..email = 'bet23058@std.uwu.ac.lk'
      //   ..address = 'moroththa,madahapola'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 9)),
      // SupplierEntity()
      //   ..supplierName = 'sahan'
      //   ..companyName = 'unilever'
      //   ..contactNumber = '07667668'
      //   ..companyContact = '+1 234 567 8900'
      //   ..email = 'sahan@gmail.com'
      //   ..address = 'abc'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 8)),
      // SupplierEntity()
      //   ..supplierName = 'global foods'
      //   ..companyName = 'Global Foods Pvt Ltd'
      //   ..contactNumber = '0710000001'
      //   ..companyContact = '0112200110'
      //   ..email = 'hello@globalfoods.lk'
      //   ..address = 'Colombo 05'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 7)),
      // SupplierEntity()
      //   ..supplierName = 'prime traders'
      //   ..companyName = 'Prime Traders'
      //   ..contactNumber = '0710000002'
      //   ..companyContact = '0112200111'
      //   ..email = 'contact@primetraders.lk'
      //   ..address = 'Kandy'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 6)),
      // SupplierEntity()
      //   ..supplierName = 'fresh market'
      //   ..companyName = 'Fresh Market Holdings'
      //   ..contactNumber = '0710000003'
      //   ..companyContact = '0112200112'
      //   ..email = 'sales@freshmarket.lk'
      //   ..address = 'Galle'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 5)),
      // SupplierEntity()
      //   ..supplierName = 'sunrise imports'
      //   ..companyName = 'Sunrise Imports'
      //   ..contactNumber = '0710000004'
      //   ..companyContact = '0112200113'
      //   ..email = 'office@sunriseimports.lk'
      //   ..address = 'Kurunegala'
      //   ..isActive = false
      //   ..createdAt = now.subtract(const Duration(days: 4)),
      // SupplierEntity()
      //   ..supplierName = 'green valley'
      //   ..companyName = 'Green Valley Foods'
      //   ..contactNumber = '0710000005'
      //   ..companyContact = '0112200114'
      //   ..email = 'info@greenvalley.lk'
      //   ..address = 'Matara'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 3)),
      // SupplierEntity()
      //   ..supplierName = 'royal wholesale'
      //   ..companyName = 'Royal Wholesale'
      //   ..contactNumber = '0710000006'
      //   ..companyContact = '0112200115'
      //   ..email = 'support@royalwholesale.lk'
      //   ..address = 'Negombo'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 2)),
      // SupplierEntity()
      //   ..supplierName = 'city distributors'
      //   ..companyName = 'City Distributors'
      //   ..contactNumber = '0710000007'
      //   ..companyContact = '0112200116'
      //   ..email = 'mail@citydistributors.lk'
      //   ..address = 'Badulla'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 2)),
      // SupplierEntity()
      //   ..supplierName = 'oceanic supply'
      //   ..companyName = 'Oceanic Supply Chain'
      //   ..contactNumber = '0710000008'
      //   ..companyContact = '0112200117'
      //   ..email = 'connect@oceanic.lk'
      //   ..address = 'Kalutara'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 2)),
      // SupplierEntity()
      //   ..supplierName = 'mega mart'
      //   ..companyName = 'Mega Mart Lanka'
      //   ..contactNumber = '0710000009'
      //   ..companyContact = '0112200118'
      //   ..email = 'mega@mart.lk'
      //   ..address = 'Anuradhapura'
      //   ..isActive = true
      //   ..createdAt = now.subtract(const Duration(days: 1)),
      // SupplierEntity()
      //   ..supplierName = 'north bridge'
      //   ..companyName = 'North Bridge Distribution'
      //   ..contactNumber = '0710000010'
      //   ..companyContact = '0112200119'
      //   ..email = 'north@bridge.lk'
      //   ..address = 'Jaffna'
      //   ..isActive = true
      //   ..createdAt = now,
    ];

    if (supplierSeeds.isEmpty) {
      return;
    }

    late final List<int> supplierIds;
    await isar.writeTxn(() async {
      supplierIds = await isar.supplierEntitys.putAll(supplierSeeds);
    });

    final grnSeeds = <GrnEntity>[
      if (supplierIds.isNotEmpty)
        _seedGrn(
          code: 'ya5Rw466RR08',
          supplierId: supplierIds[0],
          supplierName: 'apple',
          date: now.subtract(const Duration(days: 2)),
          subTotal: 5929,
          discount: 0,
          paidAmount: 333,
          itemsCount: 1,
        ),
      if (supplierIds.isNotEmpty)
        _seedGrn(
          code: 'EblchgQGfpvBfWjY4hrO',
          supplierId: supplierIds[0],
          supplierName: 'apple',
          date: now.subtract(const Duration(days: 5)),
          subTotal: 693,
          discount: 0,
          paidAmount: 0,
          itemsCount: 2,
        ),
      if (supplierIds.isNotEmpty)
        _seedGrn(
          code: '5r4MH2V6SVrTcnQM73vY',
          supplierId: supplierIds[0],
          supplierName: 'apple',
          date: now.subtract(const Duration(days: 1)),
          subTotal: 59829,
          discount: 0,
          paidAmount: 59829,
          itemsCount: 3,
        ),
      if (supplierIds.length > 1)
        _seedGrn(
          code: 'sup2GRN0001',
          supplierId: supplierIds[1],
          supplierName: 'sahan',
          date: now.subtract(const Duration(days: 3)),
          subTotal: 1200,
          discount: 100,
          paidAmount: 600,
          itemsCount: 2,
        ),
    ];

    if (grnSeeds.isEmpty) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.grnEntitys.putAll(grnSeeds);
    });
  }

  GrnEntity _seedGrn({
    required String code,
    required int supplierId,
    required String supplierName,
    required DateTime date,
    required double subTotal,
    required double discount,
    required double paidAmount,
    required int itemsCount,
  }) {
    final item = GrnItemEmbedded()
      ..productName = 'Sample product'
      ..productBarcode = '8900000000000'
      ..stockBarcode = 'STK-$code'
      ..quantity = itemsCount
      ..buyingPrice = subTotal / itemsCount
      ..sellingPrice = (subTotal / itemsCount) + 10
      ..maxDiscount = 0
      ..inStock = true;

    return GrnEntity()
      ..code = code
      ..supplierDbId = supplierId
      ..supplierName = supplierName
      ..date = date
      ..subTotal = subTotal
      ..discount = discount
      ..paidAmount = paidAmount
      ..paymentMethod = 'Cash'
      ..items = <GrnItemEmbedded>[item]
      ..paymentHistory = <GrnPaymentEmbedded>[]
      ..createdAt = date;
  }

  Map<int, List<GrnEntity>> _groupGrnsBySupplier(List<GrnEntity> grns) {
    final map = <int, List<GrnEntity>>{};
    for (final grn in grns) {
      final supplierId = grn.supplierDbId;
      if (supplierId == null) {
        continue;
      }

      map.putIfAbsent(supplierId, () => <GrnEntity>[]).add(grn);
    }

    for (final entry in map.entries) {
      entry.value.sort((left, right) => right.date.compareTo(left.date));
    }

    return map;
  }

  Future<List<GrnEntity>> _fetchGrnsForSupplier(
    Isar isar,
    SupplierEntity supplier,
  ) async {
    final allGrns = await isar.grnEntitys.where().findAll();
    final grns = allGrns.where((grn) {
      return grn.supplierDbId == supplier.id ||
          grn.supplierName.toLowerCase() == supplier.supplierName.toLowerCase();
    }).toList()..sort((left, right) => right.date.compareTo(left.date));

    return grns;
  }

  SupplierRecord _mapSupplierEntityToRecord(
    SupplierEntity entity,
    List<GrnEntity> grns,
  ) {
    return SupplierRecord(
      id: entity.id,
      cloudId: null,
      supplierName: entity.supplierName,
      companyName: entity.companyName,
      contactNumber: entity.contactNumber,
      companyContact: entity.companyContact ?? '',
      email: entity.email,
      address: entity.address,
      isActive: entity.isActive,
      grns: grns.map(_mapGrnEntityToSupplierGrnRecord).toList(),
    );
  }

  SupplierGrnRecord _mapGrnEntityToSupplierGrnRecord(GrnEntity entity) {
    final due = (entity.total - entity.paidAmount).clamp(0, double.infinity);

    return SupplierGrnRecord(
      grnId: entity.code,
      date: _formatDate(entity.date),
      itemsCount: entity.items.length,
      total: entity.total,
      paid: entity.paidAmount,
      due: due.toDouble(),
      status: _resolveSupplierGrnStatus(due.toDouble(), entity.paidAmount),
    );
  }

  SupplierGrnStatus _resolveSupplierGrnStatus(double due, double paid) {
    if (due <= 0) {
      return SupplierGrnStatus.paid;
    }
    if (paid > 0) {
      return SupplierGrnStatus.partial;
    }
    return SupplierGrnStatus.due;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }
}
