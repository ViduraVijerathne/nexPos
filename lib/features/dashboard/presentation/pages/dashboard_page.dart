import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';
import 'backup_page.dart';
import 'customer_page.dart';
import 'expense_page.dart';
import 'extension_page.dart';
import 'grn_page.dart';
import 'insight_page.dart';
import 'invoice_page.dart';
import 'label_printer_page.dart';
import 'pos_page.dart';
import 'product_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'stock_page.dart';
import 'subscription_page.dart';
import 'supplier_page.dart';

enum DashboardSection {
  launcher,
  insight,
  pos,
  products,
  stocks,
  grn,
  supplies,
  customers,
  invoice,
  labelPrinter,
  expenses,
  reports,
  extensions,
  subscription,
  settings,
  backups,
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardSection _selectedSection = DashboardSection.pos;
  bool _isOnlineMode = false;
  bool _isTouchMode = false;
  late final Set<DashboardSection> _loadedSections = <DashboardSection>{
    _selectedSection,
  };
  late final Map<DashboardSection, int> _pageVersions = {
    for (final section in DashboardSection.values) section: 0,
  };

  late final Map<DashboardSection, Widget Function()> _pageBuilders = {
    DashboardSection.launcher: () => _TouchLauncherPage(
      items: _visibleNavItems,
      onSectionSelected: _openSection,
    ),
    DashboardSection.insight: () => const InsightPage(),
    DashboardSection.pos: () => const PosPage(),
    DashboardSection.products: () => const ProductPage(),
    DashboardSection.stocks: () => const StockPage(),
    DashboardSection.grn: () => const GrnPage(),
    DashboardSection.supplies: () => const SupplierPage(),
    DashboardSection.customers: () => const CustomerPage(),
    DashboardSection.invoice: () => const InvoicePage(),
    DashboardSection.labelPrinter: () => const LabelPrinterPage(),
    DashboardSection.expenses: () => const ExpensePage(),
    DashboardSection.reports: () => const ReportPage(),
    DashboardSection.extensions: () => const ExtensionPage(),
    DashboardSection.subscription: () => const SubscriptionPage(),
    DashboardSection.settings: () => const SettingsPage(),
    DashboardSection.backups: () => const BackupPage(),
  };

  static const _navItems = [
    _NavItemData(DashboardSection.insight, Icons.grid_view_rounded, 'Insight'),
    _NavItemData(DashboardSection.pos, Icons.shopping_cart_outlined, 'POS'),
    _NavItemData(
      DashboardSection.products,
      Icons.inventory_2_outlined,
      'Products',
    ),
    _NavItemData(DashboardSection.stocks, Icons.note_alt_outlined, 'Stocks'),
    _NavItemData(DashboardSection.grn, Icons.assignment_outlined, 'GRN'),
    _NavItemData(
      DashboardSection.supplies,
      Icons.local_shipping_outlined,
      'Supplies',
    ),
    _NavItemData(
      DashboardSection.customers,
      Icons.people_outline_rounded,
      'Customers',
    ),
    _NavItemData(
      DashboardSection.invoice,
      Icons.receipt_long_outlined,
      'Invoice',
    ),
    _NavItemData(
      DashboardSection.labelPrinter,
      Icons.local_print_shop_outlined,
      'Label Printer',
    ),
    _NavItemData(
      DashboardSection.expenses,
      Icons.money_off_csred_outlined,
      'Expenses',
    ),
    _NavItemData(DashboardSection.reports, Icons.bar_chart_rounded, 'Reports'),
    _NavItemData(
      DashboardSection.extensions,
      Icons.extension_outlined,
      'Extensions',
    ),
    _NavItemData(
      DashboardSection.subscription,
      Icons.workspace_premium_outlined,
      'Subscription',
    ),
    _NavItemData(
      DashboardSection.settings,
      Icons.settings_outlined,
      'Settings',
    ),
    _NavItemData(DashboardSection.backups, Icons.storage_outlined, 'Backups'),
  ];

  @override
  void initState() {
    super.initState();
    AppThemeController.instance.addListener(_handleThemeChanged);
    AppSettingsService.instance.touchModeNotifier.addListener(
      _handleTouchModeChanged,
    );
    _loadAppMode();
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_handleThemeChanged);
    AppSettingsService.instance.touchModeNotifier.removeListener(
      _handleTouchModeChanged,
    );
    super.dispose();
  }

  void _handleThemeChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleTouchModeChanged() {
    if (!mounted) {
      return;
    }

    final isEnabled = AppSettingsService.instance.touchModeNotifier.value;
    setState(() {
      _isTouchMode = isEnabled;
      if (_isTouchMode) {
        _selectedSection = DashboardSection.launcher;
        _loadedSections.add(DashboardSection.launcher);
        _pageVersions[DashboardSection.launcher] =
            (_pageVersions[DashboardSection.launcher] ?? 0) + 1;
      } else if (_selectedSection == DashboardSection.launcher) {
        _selectedSection = DashboardSection.pos;
        _loadedSections.add(DashboardSection.pos);
        _pageVersions[DashboardSection.pos] =
            (_pageVersions[DashboardSection.pos] ?? 0) + 1;
      }
    });
  }

  Future<void> _loadAppMode() async {
    final state = await SetupService.instance.loadState();
    final touchUiSettings = await AppSettingsService.instance
        .loadTouchUiSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _isOnlineMode = state.mode == AppMode.online;
      _isTouchMode = touchUiSettings.isEnabled;
      if (_isTouchMode) {
        _selectedSection = DashboardSection.launcher;
        _loadedSections.add(DashboardSection.launcher);
        _pageVersions[DashboardSection.launcher] =
            (_pageVersions[DashboardSection.launcher] ?? 0) + 1;
      }
    });
  }

  void _openSection(DashboardSection section) {
    setState(() {
      _selectedSection = section;
      _loadedSections.add(section);
      _pageVersions[section] = (_pageVersions[section] ?? 0) + 1;
    });
  }

  List<_NavItemData> get _visibleNavItems => _navItems
      .where(
        (item) =>
            item.section != DashboardSection.subscription || _isOnlineMode,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final activeSection =
        _isTouchMode &&
            _selectedSection != DashboardSection.launcher &&
            !_loadedSections.contains(_selectedSection)
        ? DashboardSection.launcher
        : _selectedSection;

    return Scaffold(
      backgroundColor: AppThemeController.instance.palette.background,
      body: Row(
        children: [
          if (!_isTouchMode)
            _DashboardSidebar(
              items: _visibleNavItems,
              selectedSection: activeSection,
              onSectionSelected: _openSection,
              onLogout: _logout,
            ),
          Expanded(
            child: Column(
              children: [
                _DashboardTopBar(
                  isTouchMode: _isTouchMode,
                  selectedSection: activeSection,
                  onOpenLauncher: _isTouchMode
                      ? () => _openSection(DashboardSection.launcher)
                      : null,
                ),
                Expanded(
                  child: IndexedStack(
                    index: DashboardSection.values.indexOf(activeSection),
                    children: DashboardSection.values
                        .map(
                          (section) => _loadedSections.contains(section)
                              ? KeyedSubtree(
                                  key: ValueKey<String>(
                                    '${section.name}-${_pageVersions[section]}',
                                  ),
                                  child: _pageBuilders[section]!(),
                                )
                              : const SizedBox.shrink(),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    AppToast.info('Logged out successfully');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.items,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final List<_NavItemData> items;
  final DashboardSection selectedSection;
  final ValueChanged<DashboardSection> onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      decoration: BoxDecoration(
        color: AppThemeController.instance.palette.sidebarBackground,
        border: const Border(right: BorderSide(color: Color(0xFFE4EAF2))),
      ),
      child: Column(
        children: [
          Container(
            height: 82,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EDF4))),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NexPos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3A4D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'POS System',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8C99AD),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  for (final item in items) ...[
                    _SidebarNavItem(
                      item: item,
                      isActive: item.section == selectedSection,
                      onTap: () => onSectionSelected(item.section),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 30),
                side: const BorderSide(color: Color(0xFFE0E7F0)),
                foregroundColor: const Color(0xFF66758B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.isTouchMode,
    required this.selectedSection,
    this.onOpenLauncher,
  });

  final bool isTouchMode;
  final DashboardSection selectedSection;
  final VoidCallback? onOpenLauncher;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5EBF2))),
      ),
      child: Row(
        children: [
          if (isTouchMode) ...[
            FilledButton.icon(
              onPressed: selectedSection == DashboardSection.launcher
                  ? null
                  : onOpenLauncher,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: AppColors.white,
                minimumSize: const Size(124, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.apps_rounded, size: 18),
              label: const Text(
                'Launcher',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'A',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin User',
                style: TextStyle(
                  color: Color(0xFF465366),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Administrator',
                style: TextStyle(
                  color: Color(0xFF94A1B5),
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  AppToast.info('You have 2 new notifications');
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: Color(0xFF5C6B7D),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFC3D4A),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItemData item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? AppColors.white : const Color(0xFF56657A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(item.icon, size: 19, color: textColor),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.section, this.icon, this.label);

  final DashboardSection section;
  final IconData icon;
  final String label;
}

class _TouchLauncherPage extends StatelessWidget {
  const _TouchLauncherPage({
    required this.items,
    required this.onSectionSelected,
  });

  final List<_NavItemData> items;
  final ValueChanged<DashboardSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Touch Launcher',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a module to continue. Large touch-friendly tiles are enabled while touchscreen mode is active.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 1400
                    ? 4
                    : constraints.maxWidth >= 1000
                    ? 3
                    : 2;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _LauncherTile(
                      item: item,
                      onTap: () => onSectionSelected(item.section),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.item, required this.onTap});

  final _NavItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: AppColors.primaryTeal,
                  ),
                ),
                const Spacer(),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Open ${item.label.toLowerCase()} tools',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
