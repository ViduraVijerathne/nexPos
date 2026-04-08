import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../models/models.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  static const int _pageSize = 10;

  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _amountLessController = TextEditingController();
  final TextEditingController _amountGreaterController =
      TextEditingController();

  String _statusFilter = 'All Status';
  int _currentPage = 0;

  late final List<InvoiceRecord> _invoices = [
    InvoiceRecord(
      invoiceId: 'INV-000018',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-07T02:26:12.607Z',
      amount: 3514.50,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(
          name: 'manchee super cream cracker',
          quantity: 10,
          unitPrice: 290.40,
        ),
        InvoiceLineItem(name: 'apple', quantity: 2, unitPrice: 305.25),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000017',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T18:57:12.670Z',
      amount: 193.60,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'dodam', quantity: 2, unitPrice: 96.80),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000016',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T18:57:11.486Z',
      amount: 193.60,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'dodam', quantity: 2, unitPrice: 96.80),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000015',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T18:56:44.570Z',
      amount: 290.40,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(
          name: 'manchee super cream cracker',
          quantity: 3,
          unitPrice: 96.80,
        ),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000014',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T18:56:41.536Z',
      amount: 290.40,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(
          name: 'manchee super cream cracker',
          quantity: 3,
          unitPrice: 96.80,
        ),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000013',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T18:50:11.731Z',
      amount: 96.80,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'dodam', quantity: 1, unitPrice: 96.80),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000012',
      customerName: 'BET23085 S.G.N.N.Bandara',
      customerCode: 'cust-001',
      date: '2026-04-06T17:44:11.731Z',
      amount: 4799.40,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'apple', quantity: 3, unitPrice: 1599.80),
      ],
      paymentMethod: 'Card',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000011',
      customerName: 'BET23085 S.G.N.N.Bandara',
      customerCode: 'cust-001',
      date: '2026-04-06T17:12:08.620Z',
      amount: 2399.70,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'apple', quantity: 3, unitPrice: 799.90),
      ],
      paymentMethod: 'Card',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000010',
      customerName: 'Kasun Perera',
      customerCode: 'cust-011',
      date: '2026-04-06T16:01:41.536Z',
      amount: 120.00,
      status: InvoiceStatus.paid,
      items: const [InvoiceLineItem(name: '444', quantity: 4, unitPrice: 30)],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000009',
      customerName: 'Nadee Silva',
      customerCode: 'cust-012',
      date: '2026-04-06T15:33:41.536Z',
      amount: 520.00,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'product5', quantity: 5, unitPrice: 104),
      ],
      paymentMethod: 'UPI',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000008',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T14:28:41.536Z',
      amount: 60.00,
      status: InvoiceStatus.paid,
      items: const [InvoiceLineItem(name: '44', quantity: 2, unitPrice: 30)],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000007',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T13:14:41.536Z',
      amount: 88.00,
      status: InvoiceStatus.paid,
      items: const [InvoiceLineItem(name: 'dodam', quantity: 1, unitPrice: 88)],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000006',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T12:04:41.536Z',
      amount: 205.70,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'product5', quantity: 1, unitPrice: 99),
        InvoiceLineItem(name: 'dodam', quantity: 1, unitPrice: 88),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000005',
      customerName: 'Kasun Perera',
      customerCode: 'cust-011',
      date: '2026-04-06T11:44:41.536Z',
      amount: 140.00,
      status: InvoiceStatus.paid,
      items: const [InvoiceLineItem(name: '444', quantity: 2, unitPrice: 70)],
      paymentMethod: 'Card',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000004',
      customerName: 'Nadee Silva',
      customerCode: 'cust-012',
      date: '2026-04-06T10:18:41.536Z',
      amount: 780.00,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'apple', quantity: 3, unitPrice: 260),
      ],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000003',
      customerName: 'Walk-in Customer',
      customerCode: 'walk-in',
      date: '2026-04-06T09:17:41.536Z',
      amount: 154.00,
      status: InvoiceStatus.paid,
      items: const [InvoiceLineItem(name: '44', quantity: 2, unitPrice: 77)],
      paymentMethod: 'Cash',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000002',
      customerName: 'BET23085 S.G.N.N.Bandara',
      customerCode: 'cust-001',
      date: '2026-04-06T08:59:46.437Z',
      amount: 2399.70,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'apple', quantity: 3, unitPrice: 799.90),
      ],
      paymentMethod: 'Card',
      cashierName: 'Admin User',
    ),
    InvoiceRecord(
      invoiceId: 'INV-000001',
      customerName: 'BET23085 S.G.N.N.Bandara',
      customerCode: 'cust-001',
      date: '2026-04-06T08:59:43.617Z',
      amount: 2399.70,
      status: InvoiceStatus.paid,
      items: const [
        InvoiceLineItem(name: 'apple', quantity: 3, unitPrice: 799.90),
      ],
      paymentMethod: 'Card',
      cashierName: 'Admin User',
    ),
  ];

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _customerController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _amountLessController.dispose();
    _amountGreaterController.dispose();
    super.dispose();
  }

  List<InvoiceRecord> get _filteredInvoices {
    final invoiceId = _invoiceIdController.text.trim().toLowerCase();
    final customer = _customerController.text.trim().toLowerCase();
    final dateFrom = _dateFromController.text.trim();
    final dateTo = _dateToController.text.trim();
    final amountLess = double.tryParse(_amountLessController.text.trim());
    final amountGreater = double.tryParse(_amountGreaterController.text.trim());

    return _invoices.where((invoice) {
      if (invoiceId.isNotEmpty &&
          !invoice.invoiceId.toLowerCase().contains(invoiceId)) {
        return false;
      }
      if (customer.isNotEmpty &&
          !invoice.customerName.toLowerCase().contains(customer)) {
        return false;
      }
      if (dateFrom.isNotEmpty && !invoice.date.contains(dateFrom)) {
        return false;
      }
      if (dateTo.isNotEmpty && !invoice.date.contains(dateTo)) {
        return false;
      }
      if (amountLess != null && invoice.amount >= amountLess) {
        return false;
      }
      if (amountGreater != null && invoice.amount <= amountGreater) {
        return false;
      }
      if (_statusFilter != 'All Status' &&
          invoice.status.label != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages {
    final count = _filteredInvoices.length;
    return count == 0 ? 1 : ((count - 1) ~/ _pageSize) + 1;
  }

  List<InvoiceRecord> get _pagedInvoices {
    final filtered = _filteredInvoices;
    final start = (_currentPage * _pageSize).clamp(0, filtered.length);
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  void _refreshFilters() {
    setState(() {
      _currentPage = 0;
    });
  }

  void _showInvoiceDetails(InvoiceRecord invoice) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InvoiceDetailsDialog(
        invoice: invoice,
        onPrint: () {
          Navigator.of(context).pop();
          AppToast.success('Invoice sent to printer');
        },
      ),
    );
  }

  void _printInvoice(InvoiceRecord invoice) {
    AppToast.success('Printing ${invoice.invoiceId}');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInvoices;
    final paged = _pagedInvoices;
    final summary = InvoiceSummary.fromInvoices(_invoices);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InvoiceHeader(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Invoices',
                  value: '${summary.totalInvoices}',
                  valueColor: const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Paid',
                  value: '${summary.paidInvoices}',
                  valueColor: const Color(0xFF36B4AE),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Pending',
                  value: '${summary.pendingInvoices}',
                  valueColor: const Color(0xFFDE9B1F),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Overdue',
                  value: '${summary.overdueInvoices}',
                  valueColor: const Color(0xFFE23A56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InvoiceFilterCard(
            invoiceIdController: _invoiceIdController,
            customerController: _customerController,
            dateFromController: _dateFromController,
            dateToController: _dateToController,
            amountLessController: _amountLessController,
            amountGreaterController: _amountGreaterController,
            selectedStatus: _statusFilter,
            onChanged: _refreshFilters,
            onStatusChanged: (value) {
              setState(() {
                _statusFilter = value;
                _currentPage = 0;
              });
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices found',
                    description:
                        'Try changing the filters to see matching invoices.',
                  )
                : _InvoiceTableCard(
                    invoices: paged,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    totalItems: filtered.length,
                    onPrevious: _currentPage == 0
                        ? null
                        : () => setState(() => _currentPage -= 1),
                    onNext: _currentPage >= _totalPages - 1
                        ? null
                        : () => setState(() => _currentPage += 1),
                    onView: _showInvoiceDetails,
                    onPrint: _printInvoice,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invoices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage and track your sales invoices.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8391A7),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A97AA),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceFilterCard extends StatelessWidget {
  const _InvoiceFilterCard({
    required this.invoiceIdController,
    required this.customerController,
    required this.dateFromController,
    required this.dateToController,
    required this.amountLessController,
    required this.amountGreaterController,
    required this.selectedStatus,
    required this.onChanged,
    required this.onStatusChanged,
  });

  final TextEditingController invoiceIdController;
  final TextEditingController customerController;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final TextEditingController amountLessController;
  final TextEditingController amountGreaterController;
  final String selectedStatus;
  final VoidCallback onChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search & Filter Invoices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF364255),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FieldGroup(
                  label: 'Invoice ID',
                  child: TextField(
                    controller: invoiceIdController,
                    onChanged: (_) => onChanged(),
                    decoration: _fieldDecoration(hintText: 'Search by ID...'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Customer',
                  child: TextField(
                    controller: customerController,
                    onChanged: (_) => onChanged(),
                    decoration: _fieldDecoration(
                      hintText: 'Search by customer...',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Date From',
                  child: TextField(
                    controller: dateFromController,
                    onChanged: (_) => onChanged(),
                    decoration: _fieldDecoration(hintText: 'yyyy-mm-dd'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Date To',
                  child: TextField(
                    controller: dateToController,
                    onChanged: (_) => onChanged(),
                    decoration: _fieldDecoration(hintText: 'yyyy-mm-dd'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FieldGroup(
                  label: 'Amount Less Than',
                  child: TextField(
                    controller: amountLessController,
                    onChanged: (_) => onChanged(),
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(hintText: 'e.g. 100.00'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Amount Greater Than',
                  child: TextField(
                    controller: amountGreaterController,
                    onChanged: (_) => onChanged(),
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(hintText: 'e.g. 50.00'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Status',
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: _fieldDecoration(),
                    items: const ['All Status', 'Paid', 'Pending', 'Overdue']
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onStatusChanged(value);
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceTableCard extends StatelessWidget {
  const _InvoiceTableCard({
    required this.invoices,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPrint,
  });

  final List<InvoiceRecord> invoices;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<InvoiceRecord> onView;
  final ValueChanged<InvoiceRecord> onPrint;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : (currentPage * 10) + 1;
    final end = totalItems == 0 ? 0 : start + invoices.length - 1;

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 18, child: _HeaderText('Invoice ID')),
                Expanded(flex: 28, child: _HeaderText('Customer')),
                Expanded(flex: 28, child: _HeaderText('Date')),
                Expanded(flex: 14, child: _HeaderText('Amount')),
                Expanded(flex: 10, child: _HeaderText('Status')),
                Expanded(flex: 10, child: _HeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 18,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: Color(0xFF55C2BD),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                invoice.invoiceId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF435064),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF435064),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              invoice.customerCode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9AA8BC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 28,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Color(0xFF91A0B4),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                invoice.date,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D7A90),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Text(
                          'Rs ${invoice.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF435064),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: _StatusBadge(status: invoice.status),
                      ),
                      Expanded(
                        flex: 10,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => onView(invoice),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Color(0xFF4B8BD8),
                              ),
                            ),
                            IconButton(
                              onPressed: () => onPrint(invoice),
                              icon: const Icon(
                                Icons.print_outlined,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE9EEF5))),
            ),
            child: Row(
              children: [
                Text(
                  'Showing $start to $end of $totalItems invoices',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B99AD),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onPrevious,
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5EAF2)),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5EAF2)),
                  ),
                  child: Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF566376),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5EAF2)),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceDetailsDialog extends StatelessWidget {
  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.onPrint,
  });

  final InvoiceRecord invoice;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 860,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceId,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sales invoice details',
                          style: const TextStyle(
                            color: Color(0xFFE6FFFA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPrint,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0x55FFFFFF),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Invoice'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.person_outline_rounded,
                            label: 'Customer',
                            value: invoice.customerName,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.payments_outlined,
                            label: 'Amount',
                            value: 'Rs ${invoice.amount.toStringAsFixed(2)}',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value: invoice.date.substring(0, 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Invoice Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4657),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.receipt_long_outlined,
                            label: 'Invoice ID',
                            value: invoice.invoiceId,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.badge_outlined,
                            label: 'Status',
                            value: invoice.status.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.credit_card_outlined,
                            label: 'Payment Method',
                            value: invoice.paymentMethod,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.person_outline_rounded,
                            label: 'Cashier',
                            value: invoice.cashierName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Invoice Items',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4657),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EDF4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FBFD),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 46, child: _HeaderText('Item')),
                                Expanded(flex: 16, child: _HeaderText('Qty')),
                                Expanded(
                                  flex: 20,
                                  child: _HeaderText('Unit Price'),
                                ),
                                Expanded(
                                  flex: 18,
                                  child: _HeaderText('Subtotal'),
                                ),
                              ],
                            ),
                          ),
                          for (final item in invoice.items)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFF0F4F8)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 46,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 16,
                                    child: Text('${item.quantity}'),
                                  ),
                                  Expanded(
                                    flex: 20,
                                    child: Text(
                                      'Rs ${item.unitPrice.toStringAsFixed(2)}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 18,
                                    child: Text(
                                      'Rs ${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _AmountRow(
                              label: 'Subtotal',
                              value:
                                  'Rs ${invoice.subtotal.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            _AmountRow(
                              label: 'Tax',
                              value: 'Rs ${invoice.tax.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 12),
                            _AmountRow(
                              label: 'Total',
                              value: 'Rs ${invoice.amount.toStringAsFixed(2)}',
                              emphasize: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDFBF6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryTeal, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4AAEA6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF91A0B4)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8C99AD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF364255),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF6B7A90),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: emphasize
                ? const Color(0xFF36B4AE)
                : const Color(0xFF445166),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      InvoiceStatus.paid => const Color(0xFF36C3B7),
      InvoiceStatus.pending => const Color(0xFFE3A72C),
      InvoiceStatus.overdue => const Color(0xFFE24B5E),
    };
    final background = switch (status) {
      InvoiceStatus.paid => const Color(0xFFE7FCF8),
      InvoiceStatus.pending => const Color(0xFFFFF3DA),
      InvoiceStatus.overdue => const Color(0xFFFFE8EC),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8A97AA),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8D9AB0),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: const Color(0xFFD4DCE7)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF526174),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF8A97AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA9B5C7),
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.7),
    ),
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE8EDF4)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration _dialogDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(
        color: Color(0x330F172A),
        blurRadius: 28,
        offset: Offset(0, 18),
      ),
    ],
  );
}
