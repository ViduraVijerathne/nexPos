import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/services/report_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';
import '../../data/report_local_repository.dart';
import '../../data/report_remote_repository.dart';
import '../../data/report_repository.dart';
import '../../data/report_repository_factory.dart';
import '../../models/models.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  ReportRepository? _repository;
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isLoading = true;
  ReportDashboardData? _data;
  ReportHeaderSettings _headerSettings = ReportHeaderSettings.defaults;
  ShopInfo _shopInfo = const ShopInfo(
    logoPath: '',
    shopName: '',
    contactEmail: '',
    contactNumber: '',
    address: '',
  );
  _ReportMenuSection _selectedSection = _ReportMenuSection.sales;
  ReportSalesPeriod _selectedSalesPeriod = ReportSalesPeriod.daily;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    _initializePage();
  }

  Future<void> _initializePage() async {
    try {
      final repository = _repository ?? await ReportRepositoryFactory.create();
      await repository.initialize();
      final results = await Future.wait([
        repository.fetchDashboardData(
          fromDate: _fromDate,
          toDate: _toDate,
          salesPeriod: _selectedSalesPeriod,
        ),
        AppSettingsService.instance.loadReportHeaderSettings(),
        SetupService.instance.loadState(),
      ]);
      final data = results[0] as ReportDashboardData;
      final headerSettings = results[1] as ReportHeaderSettings;
      final setupState = results[2] as SetupState;
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _data = data;
        _headerSettings = headerSettings;
        _shopInfo = setupState.shopInfo;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load reports: ${_readableError(error)}');
    }
  }

  String _readableError(Object error) {
    if (error is ReportRemoteRepositoryException) {
      return error.message;
    }
    return '$error';
  }

  Future<void> _pickFromDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _fromDate = selected;
      if (_fromDate.isAfter(_toDate)) {
        _toDate = _fromDate;
      }
      _isLoading = true;
    });
    await _initializePage();
  }

  Future<void> _pickToDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _toDate = selected;
      if (_toDate.isBefore(_fromDate)) {
        _fromDate = _toDate;
      }
      _isLoading = true;
    });
    await _initializePage();
  }

  Future<void> _changeSalesPeriod(ReportSalesPeriod period) async {
    if (_selectedSalesPeriod == period) {
      return;
    }
    setState(() {
      _selectedSalesPeriod = period;
      _isLoading = true;
    });
    await _initializePage();
  }

  Future<void> _exportSection(ReportExportSection section) async {
    final data = _data;
    if (data == null) {
      return;
    }
    try {
      final path = await ReportPrintService.exportReport(
        shopInfo: _shopInfo,
        headerSettings: _headerSettings,
        report: data,
        section: section,
      );
      if (path == null) {
        return;
      }
      AppToast.success('${section.title} exported successfully');
    } catch (error) {
      AppToast.error('Failed to export report: $error');
    }
  }

  Future<void> _printSection(ReportExportSection section) async {
    final data = _data;
    if (data == null) {
      return;
    }
    try {
      await ReportPrintService.printReport(
        shopInfo: _shopInfo,
        headerSettings: _headerSettings,
        report: data,
        section: section,
      );
    } catch (error) {
      AppToast.error('Failed to print report: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _ReportPageSkeleton();
    }

    final data = _data;
    if (data == null) {
      return const Center(
        child: Text(
          'No report data available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8492A6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportsHeader(
            fromDateLabel: data.fromDateLabel,
            toDateLabel: data.toDateLabel,
            shopInfo: _shopInfo,
            settings: _headerSettings,
            onFromTap: _pickFromDate,
            onToTap: _pickToDate,
            onPrintAll: () => _printSection(ReportExportSection.all),
          ),
          const SizedBox(height: 18),
          _ReportSummaryCards(summary: data.summary),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 980;
              final menu = _ReportMenuCard(
                selectedSection: _selectedSection,
                onSelected: (section) {
                  setState(() => _selectedSection = section);
                },
              );
              final content = _ReportSectionContent(
                section: _selectedSection,
                data: data,
                selectedSalesPeriod: _selectedSalesPeriod,
                onSalesPeriodChanged: _changeSalesPeriod,
                onExport: _exportSection,
                onPrint: _printSection,
              );

              if (isCompact) {
                return Column(
                  children: [menu, const SizedBox(height: 18), content],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: menu),
                  const SizedBox(width: 18),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _ReportMenuSection {
  sales('Sales Report', Icons.point_of_sale_outlined),
  tax('Tax Collector Report', Icons.account_balance_wallet_outlined),
  inventory('Inventory Reports', Icons.inventory_2_outlined),
  customer('Customer Reports', Icons.people_outline_rounded),
  expenses('Expenses Report', Icons.receipt_long_outlined);

  const _ReportMenuSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ReportPageSkeleton extends StatelessWidget {
  const _ReportPageSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(72),
          const SizedBox(height: 18),
          Row(
            children: List<Widget>.generate(
              5,
              (index) => Expanded(
                child: Container(
                  height: 118,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          block(72),
          const SizedBox(height: 18),
          block(360),
          const SizedBox(height: 18),
          block(320),
          const SizedBox(height: 22),
          block(72),
          const SizedBox(height: 18),
          block(340),
          const SizedBox(height: 18),
          block(280),
          const SizedBox(height: 22),
          block(72),
          const SizedBox(height: 18),
          block(280),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.shopInfo,
    required this.settings,
    required this.onFromTap,
    required this.onToTap,
    required this.onPrintAll,
  });

  final String fromDateLabel;
  final String toDateLabel;
  final ShopInfo shopInfo;
  final ReportHeaderSettings settings;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onPrintAll;

  bool get _isSinhala => settings.language == InvoiceLanguage.sinhala;

  String _t(String english, String sinhala) => _isSinhala ? sinhala : english;

  TextStyle _style({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = const Color(0xFF334156),
  }) {
    final family = _isSinhala
        ? settings.sinhalaFontFamily
        : settings.englishFontFamily;
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFamily: family.trim().isEmpty ? null : family,
      fontFamilyFallback: _isSinhala
          ? const ['Noto Sans Sinhala', 'Iskoola Pota', 'Nirmala UI']
          : const ['Helvetica', 'Arial', 'Times New Roman', 'Courier New'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = settings.title.trim().isEmpty
        ? _t('Reports & Analytics', 'වාර්තා සහ විශ්ලේෂණ')
        : settings.title.trim();
    final headerSubtitle = settings.subtitle.trim().isEmpty
        ? _t(
            'Comprehensive business reports with real-time data.',
            'තත්‍ය කාලීන දත්ත සමඟ සම්පූර්ණ ව්‍යාපාර වාර්තා.',
          )
        : settings.subtitle.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: settings.marginTop,
              bottom: settings.marginBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.showLogo &&
                    shopInfo.logoPath.trim().isNotEmpty) ...[
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FBF7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(shopInfo.logoPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.storefront_outlined,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: _style(size: 21, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        headerSubtitle,
                        style: _style(
                          size: 13.5,
                          weight: FontWeight.w500,
                          color: const Color(0xFF8492A6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _DatePickerChip(label: fromDateLabel, onTap: onFromTap),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            'to',
            style: TextStyle(
              color: Color(0xFF8A98AC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _DatePickerChip(label: toDateLabel, onTap: onToTap),
        const SizedBox(width: 12),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: onPrintAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF36B4AE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text(
              'Print All',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportMenuCard extends StatelessWidget {
  const _ReportMenuCard({
    required this.selectedSection,
    required this.onSelected,
  });

  final _ReportMenuSection selectedSection;
  final ValueChanged<_ReportMenuSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT MENU',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ..._ReportMenuSection.values.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReportMenuItem(
                section: section,
                isSelected: section == selectedSection,
                onTap: () => onSelected(section),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMenuItem extends StatelessWidget {
  const _ReportMenuItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final _ReportMenuSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              section.icon,
              size: 20,
              color: isSelected
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSectionContent extends StatelessWidget {
  const _ReportSectionContent({
    required this.section,
    required this.data,
    required this.selectedSalesPeriod,
    required this.onSalesPeriodChanged,
    required this.onExport,
    required this.onPrint,
  });

  final _ReportMenuSection section;
  final ReportDashboardData data;
  final ReportSalesPeriod selectedSalesPeriod;
  final ValueChanged<ReportSalesPeriod> onSalesPeriodChanged;
  final ValueChanged<ReportExportSection> onExport;
  final ValueChanged<ReportExportSection> onPrint;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _ReportMenuSection.sales:
        return Column(
          children: [
            const _SectionBanner(
              title: 'Sales Reports',
              subtitle: 'Track sales performance and payment trends',
              background: Color(0xFF36B4AE),
            ),
            const SizedBox(height: 18),
            _SalesPeriodSelector(
              value: selectedSalesPeriod,
              onChanged: onSalesPeriodChanged,
              onPrint: () => onPrint(ReportExportSection.sales),
            ),
            const SizedBox(height: 18),
            _DailySalesSummaryCard(
              points: data.salesPoints,
              title: '${selectedSalesPeriod.label} Sales Summary',
              subtitle: 'Sales and order trends',
              onExport: () => onExport(ReportExportSection.sales),
            ),
            const SizedBox(height: 18),
            _ProductSalesCard(
              rows: data.productSales,
              onExport: () => onExport(ReportExportSection.sales),
            ),
            const SizedBox(height: 18),
            _CategorySalesCard(
              rows: data.categorySales,
              onExport: () => onExport(ReportExportSection.sales),
            ),
          ],
        );
      case _ReportMenuSection.tax:
        return Column(
          children: [
            const _SectionBanner(
              title: 'Tax Collector Report',
              subtitle: 'Track tax collection trends for the selected period',
              background: Color(0xFF9B28BE),
            ),
            const SizedBox(height: 18),
            _SectionActionRow(onPrint: () => onPrint(ReportExportSection.tax)),
            const SizedBox(height: 18),
            _TaxTrendCard(
              points: data.taxPoints,
              onExport: () => onExport(ReportExportSection.tax),
            ),
          ],
        );
      case _ReportMenuSection.inventory:
        return Column(
          children: [
            const _SectionBanner(
              title: 'Inventory Reports',
              subtitle: 'Monitor stock levels and valuation',
              background: Color(0xFFD88F21),
            ),
            const SizedBox(height: 18),
            _SectionActionRow(
              onPrint: () => onPrint(ReportExportSection.inventory),
            ),
            const SizedBox(height: 18),
            _LowStockReportCard(
              rows: data.lowStockRows,
              onExport: () => onExport(ReportExportSection.inventory),
            ),
            const SizedBox(height: 18),
            _StockValuationCard(
              rows: data.stockValuationRows,
              onExport: () => onExport(ReportExportSection.inventory),
            ),
          ],
        );
      case _ReportMenuSection.customer:
        return Column(
          children: [
            const _SectionBanner(
              title: 'Customer Reports',
              subtitle: 'Top customers and purchase patterns',
              background: Color(0xFF9B28BE),
            ),
            const SizedBox(height: 18),
            _SectionActionRow(
              onPrint: () => onPrint(ReportExportSection.customers),
            ),
            const SizedBox(height: 18),
            _TopCustomersCard(
              rows: data.topCustomers,
              onExport: () => onExport(ReportExportSection.customers),
            ),
          ],
        );
      case _ReportMenuSection.expenses:
        return Column(
          children: [
            const _SectionBanner(
              title: 'Expenses Report',
              subtitle: 'Track operational expenses for the selected period',
              background: Color(0xFFDC5F7A),
            ),
            const SizedBox(height: 18),
            _SectionActionRow(
              onPrint: () => onPrint(ReportExportSection.expenses),
            ),
            const SizedBox(height: 18),
            _ExpensesReportCard(
              expenses: data.expenses,
              totalAmount: data.totalExpenseAmount,
              onExport: () => onExport(ReportExportSection.expenses),
            ),
          ],
        );
    }
  }
}

class _ReportSummaryCards extends StatelessWidget {
  const _ReportSummaryCards({required this.summary});

  final ReportSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCardData(
        label: 'Total Revenue',
        value: 'Rs ${summary.totalRevenue.toStringAsFixed(2)}',
        note: '${summary.totalOrders} orders',
      ),
      _SummaryCardData(
        label: 'Tax Collected',
        value: 'Rs ${summary.totalTax.toStringAsFixed(2)}',
        note: 'For selected duration',
      ),
      _SummaryCardData(
        label: 'Avg. Order Value',
        value: 'Rs ${summary.averageOrderValue.toStringAsFixed(2)}',
        note: 'Per transaction',
      ),
      _SummaryCardData(
        label: 'Stock Value',
        value: 'Rs ${summary.stockValue.toStringAsFixed(2)}',
        note: '${summary.activeProducts} active products',
      ),
      _SummaryCardData(
        label: 'Low Stock Items',
        value: '${summary.lowStockItemsCount}',
        note: 'Need attention',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: _SummaryCard(data: cards[i])),
          if (i != cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({
    required this.title,
    required this.subtitle,
    required this.background,
  });

  final String title;
  final String subtitle;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFF1F5F9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionActionRow extends StatelessWidget {
  const _SectionActionRow({required this.onPrint});

  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onPrint,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374457),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.print_outlined, size: 16),
        label: const Text(
          'Print',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SalesPeriodSelector extends StatelessWidget {
  const _SalesPeriodSelector({
    required this.value,
    required this.onChanged,
    required this.onPrint,
  });

  final ReportSalesPeriod value;
  final ValueChanged<ReportSalesPeriod> onChanged;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ReportSalesPeriod.values.map((period) {
              final isSelected = period == value;
              return InkWell(
                onTap: () => onChanged(period),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryTeal
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    period.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primaryTeal
                          : const Color(0xFF4C5A6D),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        _SectionActionRow(onPrint: onPrint),
      ],
    );
  }
}

class _DailySalesSummaryCard extends StatelessWidget {
  const _DailySalesSummaryCard({
    required this.points,
    required this.title,
    required this.subtitle,
    required this.onExport,
  });

  final List<ReportSalesPoint> points;
  final String title;
  final String subtitle;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 260, child: _SalesBarChart(points: points)),
        ],
      ),
    );
  }
}

class _ProductSalesCard extends StatelessWidget {
  const _ProductSalesCard({required this.rows, required this.onExport});

  final List<ReportProductSalesRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: math.min(constraints.maxWidth, 280),
                      maxWidth: constraints.maxWidth - (isCompact ? 0 : 160),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product-wise Sales Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374457),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Products ranked by quantity and sales value',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A97AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ExportButton(onTap: onExport),
                ],
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No product sales data found',
                      style: TextStyle(
                        color: Color(0xFF8A97AA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else if (isCompact) ...[
                for (final row in rows.take(12)) ...[
                  _ProductSalesCompactRow(row: row),
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
                ],
              ] else ...[
                const _ProductSalesTableHeader(),
                const SizedBox(height: 4),
                for (final row in rows.take(12)) ...[
                  _ProductSalesTableRow(row: row),
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategorySalesCard extends StatelessWidget {
  const _CategorySalesCard({required this.rows, required this.onExport});

  final List<ReportCategorySalesRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: math.min(constraints.maxWidth, 280),
                      maxWidth: constraints.maxWidth - (isCompact ? 0 : 160),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category-wise Sales Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374457),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Categories ranked by quantity and sales value',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A97AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ExportButton(onTap: onExport),
                ],
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No category sales data found',
                      style: TextStyle(
                        color: Color(0xFF8A97AA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else if (isCompact) ...[
                for (final row in rows.take(12)) ...[
                  _CategorySalesCompactRow(row: row),
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
                ],
              ] else ...[
                const _CategorySalesTableHeader(),
                const SizedBox(height: 4),
                for (final row in rows.take(12)) ...[
                  _CategorySalesTableRow(row: row),
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TaxTrendCard extends StatelessWidget {
  const _TaxTrendCard({required this.points, required this.onExport});

  final List<ReportSalesPoint> points;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Collection Trend',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tax collected for the selected duration',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: _TrendLineChart(
              points: points,
              lineColor: const Color(0xFF9B28BE),
              fillColor: const Color(0x229B28BE),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockReportCard extends StatelessWidget {
  const _LowStockReportCard({required this.rows, required this.onExport});

  final List<ReportLowStockRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low Stock Alert',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Products requiring immediate attention',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _LowStockTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No low stock items found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows.take(8)) ...[
              _LowStockTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _StockValuationCard extends StatelessWidget {
  const _StockValuationCard({required this.rows, required this.onExport});

  final List<ReportStockValuationRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Valuation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Total inventory value by category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _StockValuationTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No stock valuation data found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows) ...[
              _StockValuationTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _TopCustomersCard extends StatelessWidget {
  const _TopCustomersCard({required this.rows, required this.onExport});

  final List<ReportTopCustomerRow> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Customers',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Customers ranked by total purchases',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _TopCustomersTableHeader(),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No customer report data found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final row in rows) ...[
              _TopCustomersTableRow(row: row),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _ExpensesReportCard extends StatelessWidget {
  const _ExpensesReportCard({
    required this.expenses,
    required this.totalAmount,
    required this.onExport,
  });

  final List<ExpenseRecord> expenses;
  final double totalAmount;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expense Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374457),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total expenses: Rs ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A97AA),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(onTap: onExport),
            ],
          ),
          const SizedBox(height: 14),
          const _ExpenseReportTableHeader(),
          const SizedBox(height: 4),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No expense records found',
                  style: TextStyle(
                    color: Color(0xFF8A97AA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final expense in expenses.take(12)) ...[
              _ExpenseReportTableRow(expense: expense),
              const Divider(height: 1, color: Color(0xFFF0F4F8)),
            ],
        ],
      ),
    );
  }
}

class _DatePickerChip extends StatelessWidget {
  const _DatePickerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E9F1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Color(0xFF5D6A7D),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4C5A6D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A97AA),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.note,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A97AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF374457),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.download_outlined, size: 16),
      label: const Text(
        'Export',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.points});

  final List<ReportSalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final finiteValues = points
        .map((point) => point.value)
        .where((value) => value.isFinite && value >= 0)
        .toList();
    final baseMax = finiteValues.isEmpty ? 0.0 : finiteValues.reduce(math.max);
    final maxValue = math.max(1.0, baseMax * 1.05);

    return CustomPaint(
      painter: _SalesBarChartPainter(points: points, maxValue: maxValue),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({
    required this.points,
    required this.lineColor,
    required this.fillColor,
  });

  final List<ReportSalesPoint> points;
  final Color lineColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final finiteValues = points
        .map((point) => point.value)
        .where((value) => value.isFinite && value >= 0)
        .toList();
    final baseMax = finiteValues.isEmpty ? 0.0 : finiteValues.reduce(math.max);
    final maxValue = math.max(1.0, baseMax * 1.1);

    return CustomPaint(
      painter: _TrendLineChartPainter(
        points: points,
        maxValue: maxValue,
        lineColor: lineColor,
        fillColor: fillColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SalesBarChartPainter extends CustomPainter {
  const _SalesBarChartPainter({required this.points, required this.maxValue});

  final List<ReportSalesPoint> points;
  final double maxValue;

  int _labelStep(double chartWidth) {
    if (points.length <= 1) {
      return 1;
    }

    const minLabelWidth = 56.0;
    final maxVisibleLabels = math.max(2, (chartWidth / minLabelWidth).floor());
    return math.max(1, (points.length / maxVisibleLabels).ceil());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final safeMaxValue = maxValue.isFinite && maxValue > 0 ? maxValue : 1.0;
    final leftPadding = 54.0;
    final bottomPadding = 28.0;
    final topPadding = 10.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE7EDF5)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFB8C4D3)
      ..strokeWidth = 1.2;
    final barPaint = Paint()..color = const Color(0xFF42BFBA);
    const textStyle = TextStyle(
      fontSize: 11.5,
      color: Color(0xFF98A5B8),
      fontWeight: FontWeight.w600,
    );

    final yLabels = [
      safeMaxValue,
      safeMaxValue * 0.75,
      safeMaxValue * 0.50,
      safeMaxValue * 0.25,
      0.0,
    ];

    for (var i = 0; i < yLabels.length; i++) {
      final y = topPadding + (chartHeight * i / (yLabels.length - 1));
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i].toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(leftPadding - painter.width - 8, y - 7));
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(size.width, topPadding + chartHeight),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    final slotWidth = chartWidth / points.length;
    final barWidth = math.min(14.0, slotWidth * 0.35);
    final labelStep = _labelStep(chartWidth);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = leftPadding + (slotWidth * i) + ((slotWidth - barWidth) / 2);
      final barHeight = maxValue <= 0
          ? 0.0
          : (point.value / safeMaxValue) * chartHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          topPadding + chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);

      final shouldDrawLabel =
          i == 0 || i == points.length - 1 || i % labelStep == 0;
      if (!shouldDrawLabel) {
        continue;
      }

      final labelPainter = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth + 10);
      labelPainter.paint(
        canvas,
        Offset(
          leftPadding +
              (slotWidth * i) +
              ((slotWidth - labelPainter.width) / 2),
          size.height - bottomPadding + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesBarChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxValue != maxValue;
  }
}

class _TrendLineChartPainter extends CustomPainter {
  const _TrendLineChartPainter({
    required this.points,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
  });

  final List<ReportSalesPoint> points;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;

  int _labelStep(double chartWidth) {
    if (points.length <= 1) {
      return 1;
    }

    const minLabelWidth = 56.0;
    final maxVisibleLabels = math.max(2, (chartWidth / minLabelWidth).floor());
    return math.max(1, (points.length / maxVisibleLabels).ceil());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final safeMaxValue = maxValue.isFinite && maxValue > 0 ? maxValue : 1.0;
    final leftPadding = 54.0;
    final rightPadding = 16.0;
    final bottomPadding = 28.0;
    final topPadding = 10.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE7EDF5)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFB8C4D3)
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()..color = lineColor;
    const textStyle = TextStyle(
      fontSize: 11.5,
      color: Color(0xFF98A5B8),
      fontWeight: FontWeight.w600,
    );

    final yLabels = [
      safeMaxValue,
      safeMaxValue * 0.75,
      safeMaxValue * 0.50,
      safeMaxValue * 0.25,
      0.0,
    ];

    for (var i = 0; i < yLabels.length; i++) {
      final y = topPadding + (chartHeight * i / (yLabels.length - 1));
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i].toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(leftPadding - painter.width - 8, y - 7));
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(size.width - rightPadding, topPadding + chartHeight),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    final stepX = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final labelStep = _labelStep(chartWidth);
    final linePath = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = leftPadding + (stepX * i);
      final y =
          topPadding +
          chartHeight -
          (((point.value.isFinite ? point.value : 0.0) / safeMaxValue) *
              chartHeight);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, topPadding + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(
      leftPadding + (stepX * (points.length - 1)),
      topPadding + chartHeight,
    );
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = leftPadding + (stepX * i);
      final y =
          topPadding +
          chartHeight -
          (((point.value.isFinite ? point.value : 0.0) / safeMaxValue) *
              chartHeight);
      canvas.drawCircle(Offset(x, y), 4.5, dotPaint);

      final shouldDrawLabel =
          i == 0 || i == points.length - 1 || i % labelStep == 0;
      if (!shouldDrawLabel) {
        continue;
      }

      final labelPainter = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 54);
      labelPainter.paint(
        canvas,
        Offset(x - (labelPainter.width / 2), size.height - bottomPadding + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _LowStockTableHeader extends StatelessWidget {
  const _LowStockTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 40, child: _HeaderText('Product')),
          Expanded(flex: 22, child: _HeaderText('Current Stock')),
          Expanded(flex: 28, child: _HeaderText('Minimum Required')),
          Expanded(flex: 18, child: _HeaderText('Status')),
        ],
      ),
    );
  }
}

class _LowStockTableRow extends StatelessWidget {
  const _LowStockTableRow({required this.row});

  final ReportLowStockRow row;

  @override
  Widget build(BuildContext context) {
    final isCritical = row.status == 'Critical';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Text(
              row.product,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              '${row.currentStock}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isCritical
                    ? const Color(0xFFD88F21)
                    : const Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              '${row.minimumRequired}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.status,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE45A5A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockValuationTableHeader extends StatelessWidget {
  const _StockValuationTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 38, child: _HeaderText('Category')),
          Expanded(flex: 22, child: _HeaderText('Total Items')),
          Expanded(flex: 24, child: _HeaderText('Total Value')),
        ],
      ),
    );
  }
}

class _StockValuationTableRow extends StatelessWidget {
  const _StockValuationTableRow({required this.row});

  final ReportStockValuationRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 38,
            child: Text(
              row.category,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              '${row.totalItems}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              'Rs ${row.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF42BFBA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCustomersTableHeader extends StatelessWidget {
  const _TopCustomersTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 14, child: _HeaderText('Rank')),
          Expanded(flex: 36, child: _HeaderText('Customer')),
          Expanded(flex: 18, child: _HeaderText('Orders')),
          Expanded(flex: 24, child: _HeaderText('Total Spent')),
          Expanded(flex: 22, child: _HeaderText('Avg. Order')),
        ],
      ),
    );
  }
}

class _ProductSalesTableHeader extends StatelessWidget {
  const _ProductSalesTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 46, child: _HeaderText('Product')),
          Expanded(flex: 18, child: _HeaderText('Qty')),
          Expanded(flex: 24, child: _HeaderText('Total Sales')),
        ],
      ),
    );
  }
}

class _ProductSalesTableRow extends StatelessWidget {
  const _ProductSalesTableRow({required this.row});

  final ReportProductSalesRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 46,
            child: Text(
              row.product,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '${row.quantity}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Rs ${row.totalSales.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF36B4AE),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSalesCompactRow extends StatelessWidget {
  const _ProductSalesCompactRow({required this.row});

  final ReportProductSalesRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.product,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C5A6D),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _ReportInfoChip(label: 'Qty', value: '${row.quantity}'),
              _ReportInfoChip(
                label: 'Total Sales',
                value: 'Rs ${row.totalSales.toStringAsFixed(2)}',
                valueColor: const Color(0xFF36B4AE),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategorySalesTableHeader extends StatelessWidget {
  const _CategorySalesTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 46, child: _HeaderText('Category')),
          Expanded(flex: 18, child: _HeaderText('Qty')),
          Expanded(flex: 24, child: _HeaderText('Total Sales')),
        ],
      ),
    );
  }
}

class _CategorySalesTableRow extends StatelessWidget {
  const _CategorySalesTableRow({required this.row});

  final ReportCategorySalesRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 46,
            child: Text(
              row.category,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '${row.quantity}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Rs ${row.totalSales.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF36B4AE),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySalesCompactRow extends StatelessWidget {
  const _CategorySalesCompactRow({required this.row});

  final ReportCategorySalesRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.category,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C5A6D),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _ReportInfoChip(label: 'Qty', value: '${row.quantity}'),
              _ReportInfoChip(
                label: 'Total Sales',
                value: 'Rs ${row.totalSales.toStringAsFixed(2)}',
                valueColor: const Color(0xFF36B4AE),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportInfoChip extends StatelessWidget {
  const _ReportInfoChip({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF4C5A6D),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A97AA),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCustomersTableRow extends StatelessWidget {
  const _TopCustomersTableRow({required this.row});

  final ReportTopCustomerRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${row.rank}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9B28BE),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 36,
            child: Text(
              row.customer,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4C5A6D),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '${row.orders}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              'Rs ${row.totalSpent.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB335CF),
              ),
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              'Rs ${row.averageOrder.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseReportTableHeader extends StatelessWidget {
  const _ExpenseReportTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 28, child: _HeaderText('Title')),
          Expanded(flex: 18, child: _HeaderText('Category')),
          Expanded(flex: 16, child: _HeaderText('Method')),
          Expanded(flex: 18, child: _HeaderText('Date')),
          Expanded(flex: 20, child: _HeaderText('Amount')),
        ],
      ),
    );
  }
}

class _ExpenseReportTableRow extends StatelessWidget {
  const _ExpenseReportTableRow({required this.expense});

  final ExpenseRecord expense;

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4C5A6D),
                  ),
                ),
                if (expense.paidFromDrawer)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Paid from drawer',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC5F7A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              expense.category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              expense.paymentMethod,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              _formatDate(expense.date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D8BA0),
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Rs ${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC5F7A),
                ),
              ),
            ),
          ),
        ],
      ),
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

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}
