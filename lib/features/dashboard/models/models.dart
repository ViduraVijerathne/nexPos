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
    required this.name,
    required this.barcode,
    required this.category,
    required this.unit,
    required this.lowStock,
    required this.status,
  });

  final String name;
  final String barcode;
  final String category;
  final String unit;
  final int lowStock;
  final ProductStatus status;
}

enum StockStatus {
  active('Active'),
  inactive('Inactive');

  const StockStatus(this.label);

  final String label;
}

class StockRecord {
  const StockRecord({
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
    double? paidAmount,
    List<PaymentHistory>? paymentHistory,
  }) {
    return GrnRecord(
      id: id,
      supplier: supplier,
      date: date,
      subTotal: subTotal,
      discount: discount,
      paidAmount: paidAmount ?? this.paidAmount,
      items: items,
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

class SupplierRecord {
  const SupplierRecord({
    required this.id,
    required this.supplierName,
    required this.companyName,
    required this.contactNumber,
    required this.companyContact,
    required this.email,
    required this.address,
    required this.isActive,
    required this.grns,
  });

  final String id;
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
    String? id,
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
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.joinDate,
    required this.invoices,
  });

  final String id;
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
