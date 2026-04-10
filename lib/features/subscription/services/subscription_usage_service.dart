import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPricing {
  const SubscriptionPricing({
    required this.mainSubscriptionLkr,
    required this.readsPer100kLkr,
    required this.writesPer100kLkr,
    required this.deletesPer100kLkr,
    required this.networkPerGbMonthLkr,
    required this.storagePerGbMonthLkr,
  });

  final double mainSubscriptionLkr;
  final double readsPer100kLkr;
  final double writesPer100kLkr;
  final double deletesPer100kLkr;
  final double networkPerGbMonthLkr;
  final double storagePerGbMonthLkr;
}

class SubscriptionModuleUsage {
  const SubscriptionModuleUsage({
    required this.module,
    required this.reads,
    required this.writes,
    required this.deletes,
    required this.networkBytes,
    required this.costLkr,
  });

  final String module;
  final int reads;
  final int writes;
  final int deletes;
  final int networkBytes;
  final double costLkr;
}

class SubscriptionBillingHistoryRecord {
  const SubscriptionBillingHistoryRecord({
    required this.monthKey,
    required this.billingMonthLabel,
    required this.periodLabel,
    required this.usageSummary,
    required this.totalAmountLkr,
    required this.paidDateLabel,
    required this.method,
    required this.status,
  });

  final String monthKey;
  final String billingMonthLabel;
  final String periodLabel;
  final String usageSummary;
  final double totalAmountLkr;
  final String paidDateLabel;
  final String method;
  final String status;
}

class SubscriptionDashboardSnapshot {
  const SubscriptionDashboardSnapshot({
    required this.pricing,
    required this.monthKey,
    required this.monthLabel,
    required this.reads,
    required this.writes,
    required this.deletes,
    required this.networkBytes,
    required this.storageBytes,
    required this.readsCostLkr,
    required this.writesCostLkr,
    required this.deletesCostLkr,
    required this.networkCostLkr,
    required this.storageCostLkr,
    required this.mainSubscriptionLkr,
    required this.totalDueLkr,
    required this.moduleBreakdown,
    required this.history,
    required this.updatedAt,
  });

  final SubscriptionPricing pricing;
  final String monthKey;
  final String monthLabel;
  final int reads;
  final int writes;
  final int deletes;
  final int networkBytes;
  final int storageBytes;
  final double readsCostLkr;
  final double writesCostLkr;
  final double deletesCostLkr;
  final double networkCostLkr;
  final double storageCostLkr;
  final double mainSubscriptionLkr;
  final double totalDueLkr;
  final List<SubscriptionModuleUsage> moduleBreakdown;
  final List<SubscriptionBillingHistoryRecord> history;
  final DateTime updatedAt;
}

class SubscriptionUsageService {
  SubscriptionUsageService._();

  static final SubscriptionUsageService instance = SubscriptionUsageService._();

  static const List<String> _trackedCollections = <String>[
    'products',
    'categories',
    'suppliers',
    'customers',
    'grns',
    'stocks',
    'invoices',
    'change_logs',
    'backups',
  ];

  SubscriptionPricing? _pricingCache;
  DateTime? _pricingLoadedAt;

  Future<void> recordRead({
    required String shopId,
    required String module,
    required int documentCount,
    Object? payload,
  }) {
    return _recordUsage(
      shopId: shopId,
      module: module,
      reads: documentCount,
      networkBytes: estimatePayloadBytes(payload),
    );
  }

  Future<void> recordWrite({
    required String shopId,
    required String module,
    int documentCount = 1,
    Object? payload,
  }) {
    return _recordUsage(
      shopId: shopId,
      module: module,
      writes: documentCount,
      networkBytes: estimatePayloadBytes(payload),
    );
  }

  Future<void> recordDelete({
    required String shopId,
    required String module,
    int documentCount = 1,
    Object? payload,
  }) {
    return _recordUsage(
      shopId: shopId,
      module: module,
      deletes: documentCount,
      networkBytes: estimatePayloadBytes(payload),
    );
  }

  Future<void> recordTransaction({
    required String shopId,
    required String module,
    int reads = 0,
    int writes = 0,
    int deletes = 0,
    Object? payload,
  }) {
    return _recordUsage(
      shopId: shopId,
      module: module,
      reads: reads,
      writes: writes,
      deletes: deletes,
      networkBytes: estimatePayloadBytes(payload),
    );
  }

  Future<SubscriptionDashboardSnapshot> loadDashboard(String shopId) async {
    final pricing = await _loadPricing();
    await _refreshStorageUsage(shopId, pricing: pricing);

    final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
    final monthKey = _monthKey(DateTime.now());
    final currentSnapshot = await shopRef
        .collection('subscription_usage')
        .doc(monthKey)
        .get();
    final currentData = _normalizeUsageDocument(
      monthKey: monthKey,
      raw: currentSnapshot.data() ?? const <String, dynamic>{},
      pricing: pricing,
    );

    final historySnapshot = await shopRef
        .collection('subscription_usage')
        .orderBy('monthSort', descending: true)
        .limit(12)
        .get();

    final history = historySnapshot.docs
        .map((doc) => _mapHistoryRecord(doc.id, doc.data(), pricing))
        .toList();

    return SubscriptionDashboardSnapshot(
      pricing: pricing,
      monthKey: monthKey,
      monthLabel: _monthLabel(DateTime.now()),
      reads: currentData.reads,
      writes: currentData.writes,
      deletes: currentData.deletes,
      networkBytes: currentData.networkBytes,
      storageBytes: currentData.storageBytes,
      readsCostLkr: currentData.readsCostLkr,
      writesCostLkr: currentData.writesCostLkr,
      deletesCostLkr: currentData.deletesCostLkr,
      networkCostLkr: currentData.networkCostLkr,
      storageCostLkr: currentData.storageCostLkr,
      mainSubscriptionLkr: currentData.mainSubscriptionLkr,
      totalDueLkr: currentData.totalDueLkr,
      moduleBreakdown: currentData.moduleBreakdown,
      history: history,
      updatedAt: currentData.updatedAt,
    );
  }

  int estimatePayloadBytes(Object? payload) {
    if (payload == null) {
      return 0;
    }
    final safePayload = _normalizeForEncoding(payload);
    try {
      return utf8.encode(jsonEncode(safePayload)).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _recordUsage({
    required String shopId,
    required String module,
    int reads = 0,
    int writes = 0,
    int deletes = 0,
    int networkBytes = 0,
  }) async {
    if (shopId.trim().isEmpty) {
      return;
    }
    if (reads == 0 && writes == 0 && deletes == 0 && networkBytes == 0) {
      return;
    }

    final pricing = await _loadPricing();
    final monthKey = _monthKey(DateTime.now());
    final usageRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('subscription_usage')
        .doc(monthKey);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(usageRef);
      final current = _normalizeUsageDocument(
        monthKey: monthKey,
        raw: snapshot.data() ?? const <String, dynamic>{},
        pricing: pricing,
      );
      final normalizedModule = _normalizeModuleKey(module);
      final moduleBreakdown = <String, Map<String, dynamic>>{
        for (final item in current.moduleBreakdown)
          _normalizeModuleKey(item.module): <String, dynamic>{
            'label': item.module,
            'reads': item.reads,
            'writes': item.writes,
            'deletes': item.deletes,
            'networkBytes': item.networkBytes,
          },
      };

      final moduleData = moduleBreakdown.putIfAbsent(
        normalizedModule,
        () => <String, dynamic>{
          'label': module,
          'reads': 0,
          'writes': 0,
          'deletes': 0,
          'networkBytes': 0,
        },
      );

      moduleData['reads'] = (moduleData['reads'] as int? ?? 0) + reads;
      moduleData['writes'] = (moduleData['writes'] as int? ?? 0) + writes;
      moduleData['deletes'] = (moduleData['deletes'] as int? ?? 0) + deletes;
      moduleData['networkBytes'] =
          (moduleData['networkBytes'] as int? ?? 0) + networkBytes;

      final next = _normalizeUsageDocument(
        monthKey: monthKey,
        raw: <String, dynamic>{
          'reads': current.reads + reads,
          'writes': current.writes + writes,
          'deletes': current.deletes + deletes,
          'networkBytes': current.networkBytes + networkBytes,
          'storageBytes': current.storageBytes,
          'modules': moduleBreakdown,
          'createdAt': current.updatedAt,
        },
        pricing: pricing,
      );

      transaction.set(usageRef, _toFirestoreMap(next), SetOptions(merge: true));
    });
  }

  Future<void> _refreshStorageUsage(
    String shopId, {
    required SubscriptionPricing pricing,
  }) async {
    if (shopId.trim().isEmpty) {
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final shopRef = firestore.collection('shops').doc(shopId);
    final monthKey = _monthKey(DateTime.now());
    final usageRef = shopRef.collection('subscription_usage').doc(monthKey);

    final shopSnapshot = await shopRef.get();
    final collectionSnapshots = await Future.wait(
      _trackedCollections.map((name) => shopRef.collection(name).get()),
    );

    var storageBytes = estimatePayloadBytes(shopSnapshot.data());
    for (final snapshot in collectionSnapshots) {
      for (final doc in snapshot.docs) {
        storageBytes += estimatePayloadBytes(doc.data());
      }
    }

    final existingSnapshot = await usageRef.get();
    final current = _normalizeUsageDocument(
      monthKey: monthKey,
      raw: existingSnapshot.data() ?? const <String, dynamic>{},
      pricing: pricing,
    );
    if (current.storageBytes == storageBytes) {
      return;
    }

    final next = _normalizeUsageDocument(
      monthKey: monthKey,
      raw: <String, dynamic>{
        'reads': current.reads,
        'writes': current.writes,
        'deletes': current.deletes,
        'networkBytes': current.networkBytes,
        'storageBytes': storageBytes,
        'modules': {
          for (final module in current.moduleBreakdown)
            _normalizeModuleKey(module.module): <String, dynamic>{
              'label': module.module,
              'reads': module.reads,
              'writes': module.writes,
              'deletes': module.deletes,
              'networkBytes': module.networkBytes,
            },
        },
        'createdAt': current.updatedAt,
      },
      pricing: pricing,
    );

    await usageRef.set(_toFirestoreMap(next), SetOptions(merge: true));
  }

  Future<SubscriptionPricing> _loadPricing() async {
    final cached = _pricingCache;
    final loadedAt = _pricingLoadedAt;
    if (cached != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 10)) {
      return cached;
    }

    final pricingCollection = FirebaseFirestore.instance.collection('pricing');
    final firebasePricing = await pricingCollection
        .doc('firebase_pricing')
        .get();
    final mainSubscription = await pricingCollection
        .doc('main_subcription')
        .get();

    final firebaseData = firebasePricing.data() ?? const <String, dynamic>{};
    final subscriptionData =
        mainSubscription.data() ?? const <String, dynamic>{};

    final pricing = SubscriptionPricing(
      mainSubscriptionLkr:
          (subscriptionData['amount_lkr'] as num?)?.toDouble() ?? 0,
      readsPer100kLkr:
          (firebaseData['reads_per_100k_lkr'] as num?)?.toDouble() ?? 0,
      writesPer100kLkr:
          (firebaseData['writes_per_100k_lkr'] as num?)?.toDouble() ?? 0,
      deletesPer100kLkr:
          (firebaseData['delete_per_100k_lkr'] as num?)?.toDouble() ?? 0,
      networkPerGbMonthLkr:
          (firebaseData['network_per_GB_month_lkr'] as num?)?.toDouble() ?? 0,
      storagePerGbMonthLkr:
          (firebaseData['storage_per_GB_month_lkr'] as num?)?.toDouble() ?? 0,
    );

    _pricingCache = pricing;
    _pricingLoadedAt = DateTime.now();
    return pricing;
  }

  _NormalizedUsageDocument _normalizeUsageDocument({
    required String monthKey,
    required Map<String, dynamic> raw,
    required SubscriptionPricing pricing,
  }) {
    final reads = (raw['reads'] as num?)?.toInt() ?? 0;
    final writes = (raw['writes'] as num?)?.toInt() ?? 0;
    final deletes = (raw['deletes'] as num?)?.toInt() ?? 0;
    final networkBytes = (raw['networkBytes'] as num?)?.toInt() ?? 0;
    final storageBytes = (raw['storageBytes'] as num?)?.toInt() ?? 0;
    final modulesRaw = Map<String, dynamic>.from(
      (raw['modules'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
          .map((key, value) => MapEntry(key.toString(), value)),
    );

    final moduleBreakdown = modulesRaw.entries.map((entry) {
      final data = Map<String, dynamic>.from(
        entry.value as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{},
      );
      final moduleReads = (data['reads'] as num?)?.toInt() ?? 0;
      final moduleWrites = (data['writes'] as num?)?.toInt() ?? 0;
      final moduleDeletes = (data['deletes'] as num?)?.toInt() ?? 0;
      final moduleNetworkBytes = (data['networkBytes'] as num?)?.toInt() ?? 0;

      return SubscriptionModuleUsage(
        module: data['label']?.toString() ?? entry.key,
        reads: moduleReads,
        writes: moduleWrites,
        deletes: moduleDeletes,
        networkBytes: moduleNetworkBytes,
        costLkr: _roundCurrency(
          _readsCost(moduleReads, pricing) +
              _writesCost(moduleWrites, pricing) +
              _deletesCost(moduleDeletes, pricing) +
              _networkCost(moduleNetworkBytes, pricing),
        ),
      );
    }).toList()..sort((left, right) => right.costLkr.compareTo(left.costLkr));

    final readsCostLkr = _readsCost(reads, pricing);
    final writesCostLkr = _writesCost(writes, pricing);
    final deletesCostLkr = _deletesCost(deletes, pricing);
    final networkCostLkr = _networkCost(networkBytes, pricing);
    final storageCostLkr = _storageCost(storageBytes, pricing);
    final totalDueLkr = _roundCurrency(
      pricing.mainSubscriptionLkr +
          readsCostLkr +
          writesCostLkr +
          deletesCostLkr +
          networkCostLkr +
          storageCostLkr,
    );

    return _NormalizedUsageDocument(
      monthKey: monthKey,
      reads: reads,
      writes: writes,
      deletes: deletes,
      networkBytes: networkBytes,
      storageBytes: storageBytes,
      readsCostLkr: readsCostLkr,
      writesCostLkr: writesCostLkr,
      deletesCostLkr: deletesCostLkr,
      networkCostLkr: networkCostLkr,
      storageCostLkr: storageCostLkr,
      mainSubscriptionLkr: pricing.mainSubscriptionLkr,
      totalDueLkr: totalDueLkr,
      moduleBreakdown: moduleBreakdown,
      updatedAt:
          _readDateTime(raw['updatedAt'] ?? raw['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _toFirestoreMap(_NormalizedUsageDocument usage) {
    return <String, dynamic>{
      'monthKey': usage.monthKey,
      'monthSort': int.tryParse(usage.monthKey.replaceAll('-', '')) ?? 0,
      'billingMonthLabel': _monthLabel(_parseMonthKey(usage.monthKey)),
      'periodLabel': _periodLabel(usage.monthKey),
      'reads': usage.reads,
      'writes': usage.writes,
      'deletes': usage.deletes,
      'networkBytes': usage.networkBytes,
      'storageBytes': usage.storageBytes,
      'readsCostLkr': usage.readsCostLkr,
      'writesCostLkr': usage.writesCostLkr,
      'deletesCostLkr': usage.deletesCostLkr,
      'networkCostLkr': usage.networkCostLkr,
      'storageCostLkr': usage.storageCostLkr,
      'mainSubscriptionLkr': usage.mainSubscriptionLkr,
      'totalDueLkr': usage.totalDueLkr,
      'updatedAt': usage.updatedAt,
      'modules': {
        for (final module in usage.moduleBreakdown)
          _normalizeModuleKey(module.module): <String, dynamic>{
            'label': module.module,
            'reads': module.reads,
            'writes': module.writes,
            'deletes': module.deletes,
            'networkBytes': module.networkBytes,
            'costLkr': module.costLkr,
          },
      },
      'status': 'Pending',
    };
  }

  SubscriptionBillingHistoryRecord _mapHistoryRecord(
    String docId,
    Map<String, dynamic> data,
    SubscriptionPricing pricing,
  ) {
    final normalized = _normalizeUsageDocument(
      monthKey: data['monthKey']?.toString() ?? docId,
      raw: data,
      pricing: pricing,
    );
    final status = data['status']?.toString().trim().isNotEmpty == true
        ? data['status'].toString()
        : 'Pending';
    final paidAt = _readDateTime(data['paidAt']);
    final paidLabel = paidAt == null ? 'Not paid yet' : _formatDate(paidAt);
    final method = data['paymentMethod']?.toString().trim().isNotEmpty == true
        ? data['paymentMethod'].toString()
        : (status.toLowerCase() == 'paid' ? 'Recorded' : 'Pending');

    return SubscriptionBillingHistoryRecord(
      monthKey: normalized.monthKey,
      billingMonthLabel: _monthLabel(_parseMonthKey(normalized.monthKey)),
      periodLabel: _periodLabel(normalized.monthKey),
      usageSummary:
          '${_formatCount(normalized.reads + normalized.writes + normalized.deletes)} ops / ${_formatGigabytes(normalized.networkBytes)}',
      totalAmountLkr: normalized.totalDueLkr,
      paidDateLabel: paidLabel,
      method: method,
      status: status,
    );
  }

  dynamic _normalizeForEncoding(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Iterable) {
      return value.map(_normalizeForEncoding).toList();
    }
    if (value is Map) {
      return value.map(
        (key, mapValue) =>
            MapEntry(key.toString(), _normalizeForEncoding(mapValue)),
      );
    }
    return value;
  }

  String _normalizeModuleKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  double _readsCost(int count, SubscriptionPricing pricing) =>
      _roundCurrency((count / 100000) * pricing.readsPer100kLkr);

  double _writesCost(int count, SubscriptionPricing pricing) =>
      _roundCurrency((count / 100000) * pricing.writesPer100kLkr);

  double _deletesCost(int count, SubscriptionPricing pricing) =>
      _roundCurrency((count / 100000) * pricing.deletesPer100kLkr);

  double _networkCost(int bytes, SubscriptionPricing pricing) => _roundCurrency(
    ((bytes / (1024 * 1024 * 1024)) * pricing.networkPerGbMonthLkr),
  );

  double _storageCost(int bytes, SubscriptionPricing pricing) => _roundCurrency(
    ((bytes / (1024 * 1024 * 1024)) * pricing.storagePerGbMonthLkr),
  );

  double _roundCurrency(double value) => double.parse(value.toStringAsFixed(2));

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  DateTime _parseMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    final year =
        int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? DateTime.now().year;
    final month =
        int.tryParse(parts.length > 1 ? parts[1] : '') ?? DateTime.now().month;
    return DateTime(year, month);
  }

  String _monthLabel(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _periodLabel(String monthKey) {
    final date = _parseMonthKey(monthKey);
    final month = date.month.toString().padLeft(2, '0');
    final end = DateTime(
      date.year,
      date.month + 1,
      0,
    ).day.toString().padLeft(2, '0');
    return '${date.year}-$month-01 to ${date.year}-$month-$end';
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '${months[date.month - 1]} $day, ${date.year}';
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatCount(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      final reverseIndex = raw.length - index;
      buffer.write(raw[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _formatGigabytes(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} GB';
  }
}

class _NormalizedUsageDocument {
  const _NormalizedUsageDocument({
    required this.monthKey,
    required this.reads,
    required this.writes,
    required this.deletes,
    required this.networkBytes,
    required this.storageBytes,
    required this.readsCostLkr,
    required this.writesCostLkr,
    required this.deletesCostLkr,
    required this.networkCostLkr,
    required this.storageCostLkr,
    required this.mainSubscriptionLkr,
    required this.totalDueLkr,
    required this.moduleBreakdown,
    required this.updatedAt,
  });

  final String monthKey;
  final int reads;
  final int writes;
  final int deletes;
  final int networkBytes;
  final int storageBytes;
  final double readsCostLkr;
  final double writesCostLkr;
  final double deletesCostLkr;
  final double networkCostLkr;
  final double storageCostLkr;
  final double mainSubscriptionLkr;
  final double totalDueLkr;
  final List<SubscriptionModuleUsage> moduleBreakdown;
  final DateTime updatedAt;
}
