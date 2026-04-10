import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../setup/services/setup_service.dart';
import '../../../subscription/services/subscription_usage_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isLoading = true;
  SubscriptionDashboardSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final setupState = await SetupService.instance.loadState();
      final shopId = setupState.selectedShopId.trim();
      if (shopId.isEmpty) {
        throw Exception('Online shop is not selected yet.');
      }
      final snapshot = await SubscriptionUsageService.instance.loadDashboard(
        shopId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load subscription data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SubscriptionPageSkeleton();
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(
        child: Text(
          'No subscription data available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8492A6),
          ),
        ),
      );
    }

    final usageCards = <_UsageCardData>[
      _UsageCardData(
        label: 'Write Operations',
        value: _formatCount(snapshot.writes),
        unit: 'writes',
        accent: const Color(0xFF36B4AE),
        tint: const Color(0xFFE7FBF8),
        note: 'LKR ${_formatCurrency(snapshot.writesCostLkr)} this month',
      ),
      _UsageCardData(
        label: 'Read Operations',
        value: _formatCount(snapshot.reads),
        unit: 'reads',
        accent: const Color(0xFF5796FF),
        tint: const Color(0xFFEAF3FF),
        note: 'LKR ${_formatCurrency(snapshot.readsCostLkr)} this month',
      ),
      _UsageCardData(
        label: 'Delete Operations',
        value: _formatCount(snapshot.deletes),
        unit: 'deletes',
        accent: const Color(0xFFF29A38),
        tint: const Color(0xFFFFF3E3),
        note: 'LKR ${_formatCurrency(snapshot.deletesCostLkr)} this month',
      ),
      _UsageCardData(
        label: 'Network Usage',
        value: _formatGigabytes(snapshot.networkBytes),
        unit: 'GB',
        accent: const Color(0xFF8F56E8),
        tint: const Color(0xFFF3EAFF),
        note: 'LKR ${_formatCurrency(snapshot.networkCostLkr)} this month',
      ),
    ];

    final billingItems = <_BillingLineItem>[
      _BillingLineItem(
        'Write usage charge',
        '${_formatCount(snapshot.writes)} ops',
        'LKR ${_formatCurrency(snapshot.writesCostLkr)}',
      ),
      _BillingLineItem(
        'Read usage charge',
        '${_formatCount(snapshot.reads)} ops',
        'LKR ${_formatCurrency(snapshot.readsCostLkr)}',
      ),
      _BillingLineItem(
        'Delete usage charge',
        '${_formatCount(snapshot.deletes)} ops',
        'LKR ${_formatCurrency(snapshot.deletesCostLkr)}',
      ),
      _BillingLineItem(
        'Network transfer',
        _formatGigabytes(snapshot.networkBytes),
        'LKR ${_formatCurrency(snapshot.networkCostLkr)}',
      ),
      _BillingLineItem(
        'Database storage',
        _formatGigabytes(snapshot.storageBytes),
        'LKR ${_formatCurrency(snapshot.storageCostLkr)}',
      ),
      _BillingLineItem(
        'Main subscription',
        'Monthly base plan',
        'LKR ${_formatCurrency(snapshot.mainSubscriptionLkr)}',
      ),
    ];

    final usageBreakdown = snapshot.moduleBreakdown
        .map(
          (row) => _UsageBreakdownRow(
            module: row.module,
            writes: _formatCount(row.writes),
            reads: _formatCount(row.reads),
            deletes: _formatCount(row.deletes),
            network: _formatGigabytes(row.networkBytes),
            cost: 'LKR ${_formatCurrency(row.costLkr)}',
          ),
        )
        .toList();

    final paymentHistory = snapshot.history
        .map(
          (row) => _PaymentHistoryRow(
            billingMonth: row.billingMonthLabel,
            period: row.periodLabel,
            usage: row.usageSummary,
            amount: 'LKR ${_formatCurrency(row.totalAmountLkr)}',
            paidAt: row.paidDateLabel,
            method: row.method,
            status: row.status,
            statusColor: _statusColor(row.status),
            statusTint: _statusTint(row.status),
          ),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubscriptionHeader(onRefresh: _loadData),
          const SizedBox(height: 18),
          _PlanStrip(
            basePriceLabel:
                'LKR ${_formatCurrency(snapshot.mainSubscriptionLkr)} / month',
            estimatedLabel: 'LKR ${_formatCurrency(snapshot.totalDueLkr)}',
            updatedLabel: _formatDateTime(snapshot.updatedAt),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1040;
              if (compact) {
                return Column(
                  children: [
                    _UsageOverviewSection(
                      cards: usageCards,
                      monthLabel: snapshot.monthLabel,
                      projectedCost:
                          'LKR ${_formatCurrency(snapshot.totalDueLkr)}',
                      projectedNetwork: _formatGigabytes(snapshot.networkBytes),
                      averageDailyReads: _formatCount(
                        (snapshot.reads / DateTime.now().day).round(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _CurrentBillSection(
                      items: billingItems,
                      amountDue: 'LKR ${_formatCurrency(snapshot.totalDueLkr)}',
                      dueNote: 'Current month running bill',
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: _UsageOverviewSection(
                      cards: usageCards,
                      monthLabel: snapshot.monthLabel,
                      projectedCost:
                          'LKR ${_formatCurrency(snapshot.totalDueLkr)}',
                      projectedNetwork: _formatGigabytes(snapshot.networkBytes),
                      averageDailyReads: _formatCount(
                        (snapshot.reads / DateTime.now().day).round(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 5,
                    child: _CurrentBillSection(
                      items: billingItems,
                      amountDue: 'LKR ${_formatCurrency(snapshot.totalDueLkr)}',
                      dueNote: 'Current month running bill',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _UsageBreakdownSection(rows: usageBreakdown),
          const SizedBox(height: 18),
          _PaymentHistorySection(rows: paymentHistory),
        ],
      ),
    );
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
    return gb >= 10 ? gb.toStringAsFixed(1) : gb.toStringAsFixed(2);
  }

  String _formatCurrency(double value) => value.toStringAsFixed(2);

  String _formatDateTime(DateTime value) {
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
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} $day, ${value.year} • $hour:$minute $period';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF36B4AE);
      case 'pending':
        return const Color(0xFFF29A38);
      default:
        return const Color(0xFF8F56E8);
    }
  }

  Color _statusTint(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFFE6FBF8);
      case 'pending':
        return const Color(0xFFFFF4E5);
      default:
        return const Color(0xFFF3EAFF);
    }
  }
}

class _SubscriptionPageSkeleton extends StatelessWidget {
  const _SubscriptionPageSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(18),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(72),
          const SizedBox(height: 18),
          block(120),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: block(420)),
              const SizedBox(width: 18),
              Expanded(child: block(420)),
            ],
          ),
          const SizedBox(height: 18),
          block(310),
          const SizedBox(height: 18),
          block(320),
        ],
      ),
    );
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334156),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Monitor monthly usage, estimated billing, and subscription payments for your online store.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8492A6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF36B4AE),
            side: const BorderSide(color: Color(0xFF6CCFC8)),
            minimumSize: const Size(138, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text(
            'Refresh',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PlanStrip extends StatelessWidget {
  const _PlanStrip({
    required this.basePriceLabel,
    required this.estimatedLabel,
    required this.updatedLabel,
  });

  final String basePriceLabel;
  final String estimatedLabel;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C8F89), Color(0xFF36B4AE), Color(0xFF59CEC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1D2CA79E),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Online Subscription Billing',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Monthly bill = usage charges + main subscription. Firebase usage is tracked and stored while the shop works online.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE8FFFD),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              _PlanMetricChip(label: 'Base Plan', value: basePriceLabel),
              _PlanMetricChip(
                label: 'Estimated This Month',
                value: estimatedLabel,
              ),
              _PlanMetricChip(label: 'Last Updated', value: updatedLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanMetricChip extends StatelessWidget {
  const _PlanMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x35FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDFFAF7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageOverviewSection extends StatelessWidget {
  const _UsageOverviewSection({
    required this.cards,
    required this.monthLabel,
    required this.projectedCost,
    required this.projectedNetwork,
    required this.averageDailyReads,
  });

  final List<_UsageCardData> cards;
  final String monthLabel;
  final String projectedCost;
  final String projectedNetwork;
  final String averageDailyReads;

  @override
  Widget build(BuildContext context) {
    return _SurfaceSection(
      title: 'This Month Usage',
      subtitle:
          'Current billing-cycle activity for your online shop workspace.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8FBF8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          monthLabel,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E938D),
          ),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 620;
              if (!twoColumns) {
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      _UsageMetricCard(data: cards[index]),
                      if (index != cards.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: _UsageMetricCard(data: card),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EEF6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InlineUsageInfo(
                    title: 'Projected month-end cost',
                    value: projectedCost,
                    tone: Color(0xFF334156),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InlineUsageInfo(
                    title: 'Projected network transfer',
                    value: projectedNetwork,
                    tone: Color(0xFF8F56E8),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InlineUsageInfo(
                    title: 'Average daily reads',
                    value: averageDailyReads,
                    tone: Color(0xFF5796FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageMetricCard extends StatelessWidget {
  const _UsageMetricCard({required this.data});

  final _UsageCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_graph_rounded, color: data.accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8391A5),
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: data.value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334156),
                  ),
                ),
                TextSpan(
                  text: ' ${data.unit}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: data.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.note,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A98AC),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineUsageInfo extends StatelessWidget {
  const _InlineUsageInfo({
    required this.title,
    required this.value,
    required this.tone,
  });

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A98AC),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: tone,
          ),
        ),
      ],
    );
  }
}

class _CurrentBillSection extends StatelessWidget {
  const _CurrentBillSection({
    required this.items,
    required this.amountDue,
    required this.dueNote,
  });

  final List<_BillingLineItem> items;
  final String amountDue;
  final String dueNote;

  @override
  Widget build(BuildContext context) {
    return _SurfaceSection(
      title: 'Current Bill Estimate',
      subtitle:
          'This running amount combines Firebase usage pricing and the monthly subscription charge.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FBFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2ECF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount due today',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7D8CA1),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  amountDue,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334156),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  dueNote,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A98AC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++) ...[
            _BillLine(row: items[index]),
            if (index != items.length - 1) const Divider(height: 22),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13262A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Estimated total to pay',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  amountDue,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF67E1D7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({required this.row});

  final _BillingLineItem row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344258),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.meta,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A98AC),
                ),
              ),
            ],
          ),
        ),
        Text(
          row.amount,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334156),
          ),
        ),
      ],
    );
  }
}

class _UsageBreakdownSection extends StatelessWidget {
  const _UsageBreakdownSection({required this.rows});

  final List<_UsageBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SurfaceSection(
      title: 'Usage Breakdown by Module',
      subtitle: 'Detailed monthly usage split across operational modules.',
      trailing: OutlinedButton.icon(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF36B4AE),
          side: const BorderSide(color: Color(0xFFCBEFEB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text(
          'Export CSV',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: _TableShell(
        headers: const [
          'Module',
          'Writes',
          'Reads',
          'Deletes',
          'Network',
          'Cost',
        ],
        rows: rows
            .map(
              (row) => [
                _TableText(row.module, strong: true),
                _TableText(row.writes),
                _TableText(row.reads),
                _TableText(row.deletes),
                _TableText(row.network),
                _TableText(row.cost, accent: const Color(0xFF36B4AE)),
              ],
            )
            .toList(),
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({required this.rows});

  final List<_PaymentHistoryRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SurfaceSection(
      title: 'Payment History',
      subtitle:
          'Recent subscription invoices and billing settlements for this shop.',
      child: _TableShell(
        headers: const [
          'Billing Month',
          'Usage',
          'Amount',
          'Paid Date',
          'Method',
          'Status',
        ],
        rows: rows
            .map(
              (row) => [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TableText(row.billingMonth, strong: true),
                    const SizedBox(height: 4),
                    _SecondaryTableText(row.period),
                  ],
                ),
                _TableText(row.usage),
                _TableText(row.amount, accent: const Color(0xFF36B4AE)),
                _TableText(row.paidAt),
                _TableText(row.method),
                _StatusPill(
                  label: row.status,
                  color: row.statusColor,
                  tint: row.statusTint,
                ),
              ],
            )
            .toList(),
      ),
    );
  }
}

class _SurfaceSection extends StatelessWidget {
  const _SurfaceSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334156),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8794A8),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: headers
                  .map(
                    (header) => Expanded(
                      child: Text(
                        header,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8190A5),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5ECF4)),
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows[rowIndex]
                    .map((cell) => Expanded(child: cell))
                    .toList(),
              ),
            ),
            if (rowIndex != rows.length - 1)
              const Divider(height: 1, color: Color(0xFFE9EFF6)),
          ],
        ],
      ),
    );
  }
}

class _TableText extends StatelessWidget {
  const _TableText(this.value, {this.strong = false, this.accent});

  final String value;
  final bool strong;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
        color: accent ?? const Color(0xFF405065),
      ),
    );
  }
}

class _SecondaryTableText extends StatelessWidget {
  const _SecondaryTableText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A98AC),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.tint,
  });

  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _UsageCardData {
  const _UsageCardData({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.tint,
    required this.note,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final Color tint;
  final String note;
}

class _BillingLineItem {
  const _BillingLineItem(this.label, this.meta, this.amount);

  final String label;
  final String meta;
  final String amount;
}

class _UsageBreakdownRow {
  const _UsageBreakdownRow({
    required this.module,
    required this.writes,
    required this.reads,
    required this.deletes,
    required this.network,
    required this.cost,
  });

  final String module;
  final String writes;
  final String reads;
  final String deletes;
  final String network;
  final String cost;
}

class _PaymentHistoryRow {
  const _PaymentHistoryRow({
    required this.billingMonth,
    required this.period,
    required this.usage,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.status,
    required this.statusColor,
    required this.statusTint,
  });

  final String billingMonth;
  final String period;
  final String usage;
  final String amount;
  final String paidAt;
  final String method;
  final String status;
  final Color statusColor;
  final Color statusTint;
}
