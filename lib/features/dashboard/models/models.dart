class ProductDialogResult {
  const ProductDialogResult({
    required this.product,
    required this.createdCategory,
  });

  final ProductRecord product;
  final bool createdCategory;
}

enum ProductStatus {
  active('Active'),
  inactive('Inactive');

  const ProductStatus(this.label);

  final String label;
}

class ProductRecord {
  const ProductRecord({
    this.id,
    this.cloudId,
    required this.name,
    required this.barcode,
    required this.category,
    required this.unit,
    required this.lowStock,
    required this.status,
  });

  final int? id;
  final String? cloudId;
  final String name;
  final String barcode;
  final String category;
  final String unit;
  final int lowStock;
  final ProductStatus status;

  ProductRecord copyWith({
    int? id,
    String? cloudId,
    String? name,
    String? barcode,
    String? category,
    String? unit,
    int? lowStock,
    ProductStatus? status,
  }) {
    return ProductRecord(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      lowStock: lowStock ?? this.lowStock,
      status: status ?? this.status,
    );
  }
}

class ProductPageResult {
  const ProductPageResult({
    required this.products,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<ProductRecord> products;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

enum StockStatus {
  active('Active'),
  inactive('Inactive');

  const StockStatus(this.label);

  final String label;
}

class StockRecord {
  const StockRecord({
    this.id,
    this.cloudId,
    required this.barcode,
    required this.product,
    required this.initialQty,
    required this.availableQty,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.maxDiscount,
    required this.status,
    required this.grnId,
    this.expiryDate,
  });

  final int? id;
  final String? cloudId;
  final String barcode;
  final String product;
  final int initialQty;
  final int availableQty;
  final double buyingPrice;
  final double sellingPrice;
  final double maxDiscount;
  final StockStatus status;
  final String grnId;
  final String? expiryDate;

  StockRecord copyWith({
    int? id,
    String? cloudId,
    String? barcode,
    String? product,
    int? initialQty,
    int? availableQty,
    double? buyingPrice,
    double? sellingPrice,
    double? maxDiscount,
    StockStatus? status,
    String? grnId,
    String? expiryDate,
  }) {
    return StockRecord(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      barcode: barcode ?? this.barcode,
      product: product ?? this.product,
      initialQty: initialQty ?? this.initialQty,
      availableQty: availableQty ?? this.availableQty,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      status: status ?? this.status,
      grnId: grnId ?? this.grnId,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}

class StockSummary {
  const StockSummary({
    required this.totalStockItems,
    required this.activeStocks,
    required this.lowStockItems,
    required this.inactiveStocks,
  });

  final int totalStockItems;
  final int activeStocks;
  final int lowStockItems;
  final int inactiveStocks;
}

class StockPageResult {
  const StockPageResult({
    required this.stocks,
    required this.summary,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<StockRecord> stocks;
  final StockSummary summary;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

class PosCatalogItem {
  const PosCatalogItem({
    required this.stockId,
    required this.stockBarcode,
    required this.productName,
    required this.productBarcode,
    required this.category,
    required this.availableQty,
    required this.sellingPrice,
  });

  final int stockId;
  final String stockBarcode;
  final String productName;
  final String productBarcode;
  final String category;
  final int availableQty;
  final double sellingPrice;
}

class PosCatalogResult {
  const PosCatalogResult({required this.items, required this.categories});

  final List<PosCatalogItem> items;
  final List<String> categories;
}

class PosCartItem {
  const PosCartItem({
    required this.stockId,
    required this.stockBarcode,
    required this.productBarcode,
    required this.productName,
    required this.category,
    required this.unitPrice,
    required this.availableQty,
    required this.quantity,
  });

  final int stockId;
  final String stockBarcode;
  final String productBarcode;
  final String productName;
  final String category;
  final double unitPrice;
  final int availableQty;
  final int quantity;

  double get subtotal => unitPrice * quantity;

  PosCartItem copyWith({
    int? stockId,
    String? stockBarcode,
    String? productBarcode,
    String? productName,
    String? category,
    double? unitPrice,
    int? availableQty,
    int? quantity,
  }) {
    return PosCartItem(
      stockId: stockId ?? this.stockId,
      stockBarcode: stockBarcode ?? this.stockBarcode,
      productBarcode: productBarcode ?? this.productBarcode,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      availableQty: availableQty ?? this.availableQty,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PosCustomerOption {
  const PosCustomerOption({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.isWalkIn = false,
  });

  final int? id;
  final String name;
  final String phone;
  final String email;
  final bool isWalkIn;

  String get searchLabel {
    if (phone.trim().isEmpty) {
      return name;
    }
    return '$name (${phone.trim()})';
  }
}

class PosCheckoutResult {
  const PosCheckoutResult({
    required this.invoiceNumber,
    required this.changeAmount,
  });

  final String invoiceNumber;
  final double changeAmount;
}

class GrnRecord {
  const GrnRecord({
    required this.id,
    required this.supplier,
    required this.date,
    required this.subTotal,
    required this.discount,
    required this.paidAmount,
    required this.items,
    required this.paymentHistory,
    this.paymentMethod = 'Cash',
  });

  final String id;
  final String supplier;
  final String date;
  final double subTotal;
  final double discount;
  final double paidAmount;
  final List<GrnItem> items;
  final List<PaymentHistory> paymentHistory;
  final String paymentMethod;

  double get total => subTotal - discount;
  double get dueAmount => total - paidAmount;

  GrnRecord copyWith({
    String? supplier,
    String? date,
    double? subTotal,
    double? discount,
    double? paidAmount,
    List<GrnItem>? items,
    List<PaymentHistory>? paymentHistory,
  }) {
    return GrnRecord(
      id: id,
      supplier: supplier ?? this.supplier,
      date: date ?? this.date,
      subTotal: subTotal ?? this.subTotal,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      items: items ?? this.items,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      paymentMethod: paymentMethod,
    );
  }
}

class GrnItem {
  const GrnItem({
    required this.product,
    required this.stockBarcode,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    this.maxDiscount = 0,
    required this.inStock,
  });

  final String product;
  final String stockBarcode;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;
  final double maxDiscount;
  final bool inStock;

  double get subtotal => quantity * buyingPrice;

  GrnItem copyWith({
    String? product,
    String? stockBarcode,
    int? quantity,
    double? buyingPrice,
    double? sellingPrice,
    double? maxDiscount,
    bool? inStock,
  }) {
    return GrnItem(
      product: product ?? this.product,
      stockBarcode: stockBarcode ?? this.stockBarcode,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      inStock: inStock ?? this.inStock,
    );
  }

  GrnItem copyWithInStock(bool value) => copyWith(inStock: value);
}

class PaymentHistory {
  const PaymentHistory({
    required this.dateTime,
    required this.amount,
    required this.method,
    required this.remainingBalance,
  });

  final String dateTime;
  final double amount;
  final String method;
  final double remainingBalance;
}

class PayDueResult {
  const PayDueResult({required this.amount, required this.method});

  final double amount;
  final String method;
}

class GrnPageResult {
  const GrnPageResult({
    required this.records,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<GrnRecord> records;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

class GrnDialogResult {
  const GrnDialogResult({required this.record, required this.addToStock});

  final GrnRecord record;
  final bool addToStock;
}

class SupplierRecord {
  const SupplierRecord({
    required this.id,
    this.cloudId,
    required this.supplierName,
    required this.companyName,
    required this.contactNumber,
    required this.companyContact,
    required this.email,
    required this.address,
    required this.isActive,
    required this.grns,
  });

  final int id;
  final String? cloudId;
  final String supplierName;
  final String companyName;
  final String contactNumber;
  final String companyContact;
  final String email;
  final String address;
  final bool isActive;
  final List<SupplierGrnRecord> grns;

  double get totalPaid => grns.fold(0, (sum, item) => sum + item.paid);
  double get totalDue => grns.fold(0, (sum, item) => sum + item.due);

  SupplierRecord copyWith({
    int? id,
    String? cloudId,
    String? supplierName,
    String? companyName,
    String? contactNumber,
    String? companyContact,
    String? email,
    String? address,
    bool? isActive,
    List<SupplierGrnRecord>? grns,
  }) {
    return SupplierRecord(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      supplierName: supplierName ?? this.supplierName,
      companyName: companyName ?? this.companyName,
      contactNumber: contactNumber ?? this.contactNumber,
      companyContact: companyContact ?? this.companyContact,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      grns: grns ?? this.grns,
    );
  }
}

class SupplierPageResult {
  const SupplierPageResult({
    required this.suppliers,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<SupplierRecord> suppliers;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

class SupplierGrnRecord {
  const SupplierGrnRecord({
    required this.grnId,
    required this.date,
    required this.itemsCount,
    required this.total,
    required this.paid,
    required this.due,
    required this.status,
  });

  final String grnId;
  final String date;
  final int itemsCount;
  final double total;
  final double paid;
  final double due;
  final SupplierGrnStatus status;

  SupplierGrnRecord copyWith({
    String? grnId,
    String? date,
    int? itemsCount,
    double? total,
    double? paid,
    double? due,
    SupplierGrnStatus? status,
  }) {
    return SupplierGrnRecord(
      grnId: grnId ?? this.grnId,
      date: date ?? this.date,
      itemsCount: itemsCount ?? this.itemsCount,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      due: due ?? this.due,
      status: status ?? this.status,
    );
  }
}

enum SupplierGrnStatus {
  paid('Paid'),
  partial('Partial'),
  due('Due');

  const SupplierGrnStatus(this.label);

  final String label;
}

class PaySupplierDueResult {
  const PaySupplierDueResult({required this.amount, required this.method});

  final double amount;
  final String method;
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    this.cloudId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.joinDate,
    required this.invoices,
  });

  final int id;
  final String? cloudId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String joinDate;
  final List<CustomerInvoice> invoices;

  int get ordersCount => invoices.length;
  double get totalSpent =>
      invoices.fold(0, (sum, invoice) => sum + invoice.total);

  String get avatarText {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  CustomerRecord copyWith({
    int? id,
    String? cloudId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? joinDate,
    List<CustomerInvoice>? invoices,
  }) {
    return CustomerRecord(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      joinDate: joinDate ?? this.joinDate,
      invoices: invoices ?? this.invoices,
    );
  }
}

class CustomerInvoice {
  const CustomerInvoice({
    required this.invoiceNumber,
    required this.date,
    required this.itemsCount,
    required this.total,
  });

  final String invoiceNumber;
  final String date;
  final int itemsCount;
  final double total;
}

class CustomerPageResult {
  const CustomerPageResult({
    required this.customers,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<CustomerRecord> customers;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.totalInvoices,
    required this.paidInvoices,
    required this.pendingInvoices,
    required this.overdueInvoices,
  });

  final int totalInvoices;
  final int paidInvoices;
  final int pendingInvoices;
  final int overdueInvoices;

  factory InvoiceSummary.fromInvoices(List<InvoiceRecord> invoices) {
    return InvoiceSummary(
      totalInvoices: invoices.length,
      paidInvoices: invoices
          .where((invoice) => invoice.status == InvoiceStatus.paid)
          .length,
      pendingInvoices: invoices
          .where((invoice) => invoice.status == InvoiceStatus.pending)
          .length,
      overdueInvoices: invoices
          .where((invoice) => invoice.status == InvoiceStatus.overdue)
          .length,
    );
  }
}

class InvoicePageResult {
  const InvoicePageResult({
    required this.invoices,
    required this.summary,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<InvoiceRecord> invoices;
  final InvoiceSummary summary;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return (totalCount / pageSize).ceil();
  }
}

class InvoiceRecord {
  const InvoiceRecord({
    required this.invoiceId,
    required this.customerName,
    required this.customerCode,
    required this.date,
    required this.amount,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.cashierName,
  });

  final String invoiceId;
  final String customerName;
  final String customerCode;
  final String date;
  final double amount;
  final InvoiceStatus status;
  final List<InvoiceLineItem> items;
  final String paymentMethod;
  final String cashierName;

  double get subtotal => amount / 1.10;
  double get tax => amount - subtotal;
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

enum InvoiceStatus {
  paid('Paid'),
  pending('Pending'),
  overdue('Overdue');

  const InvoiceStatus(this.label);

  final String label;
}

class InsightMetricRecord {
  const InsightMetricRecord({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;
}

class InsightSalesPoint {
  const InsightSalesPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class InsightCategoryAllocation {
  const InsightCategoryAllocation({
    required this.label,
    required this.percentage,
  });

  final String label;
  final double percentage;
}

class InsightLowStockItem {
  const InsightLowStockItem({required this.name, required this.status});

  final String name;
  final String status;
}

class InsightExpiredStockItem {
  const InsightExpiredStockItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.expiryDate,
  });

  final int id;
  final String name;
  final String barcode;
  final String expiryDate;
}

class InsightDashboardData {
  const InsightDashboardData({
    required this.totalSales,
    required this.totalOrders,
    required this.activeProducts,
    required this.totalCustomers,
    required this.salesGrowthNote,
    required this.ordersGrowthNote,
    required this.productsNote,
    required this.customersNote,
    required this.salesPoints,
    required this.chartDateFromLabel,
    required this.chartDateToLabel,
    required this.categoryAllocation,
    required this.lowStockItems,
    required this.expiredStockItems,
  });

  final double totalSales;
  final int totalOrders;
  final int activeProducts;
  final int totalCustomers;
  final String salesGrowthNote;
  final String ordersGrowthNote;
  final String productsNote;
  final String customersNote;
  final List<InsightSalesPoint> salesPoints;
  final String chartDateFromLabel;
  final String chartDateToLabel;
  final List<InsightCategoryAllocation> categoryAllocation;
  final List<InsightLowStockItem> lowStockItems;
  final List<InsightExpiredStockItem> expiredStockItems;
}

class ReportSummaryData {
  const ReportSummaryData({
    required this.totalRevenue,
    required this.totalTax,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.stockValue,
    required this.activeProducts,
    required this.lowStockItemsCount,
  });

  final double totalRevenue;
  final double totalTax;
  final int totalOrders;
  final double averageOrderValue;
  final double stockValue;
  final int activeProducts;
  final int lowStockItemsCount;
}

class ReportSalesPoint {
  const ReportSalesPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class ReportLowStockRow {
  const ReportLowStockRow({
    required this.product,
    required this.currentStock,
    required this.minimumRequired,
    required this.status,
  });

  final String product;
  final int currentStock;
  final int minimumRequired;
  final String status;
}

class ReportStockValuationRow {
  const ReportStockValuationRow({
    required this.category,
    required this.totalItems,
    required this.totalValue,
  });

  final String category;
  final int totalItems;
  final double totalValue;
}

class ReportTopCustomerRow {
  const ReportTopCustomerRow({
    required this.rank,
    required this.customer,
    required this.orders,
    required this.totalSpent,
    required this.averageOrder,
  });

  final int rank;
  final String customer;
  final int orders;
  final double totalSpent;
  final double averageOrder;
}

class ReportDashboardData {
  const ReportDashboardData({
    required this.summary,
    required this.salesPoints,
    required this.taxPoints,
    required this.lowStockRows,
    required this.stockValuationRows,
    required this.topCustomers,
    required this.fromDateLabel,
    required this.toDateLabel,
  });

  final ReportSummaryData summary;
  final List<ReportSalesPoint> salesPoints;
  final List<ReportSalesPoint> taxPoints;
  final List<ReportLowStockRow> lowStockRows;
  final List<ReportStockValuationRow> stockValuationRows;
  final List<ReportTopCustomerRow> topCustomers;
  final String fromDateLabel;
  final String toDateLabel;
}
