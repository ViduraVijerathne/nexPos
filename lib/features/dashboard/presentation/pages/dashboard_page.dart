import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'coming_soon_page.dart';
import 'customer_page.dart';
import 'grn_page.dart';
import 'insight_page.dart';
import 'invoice_page.dart';
import 'pos_page.dart';
import 'product_page.dart';
import 'stock_page.dart';
import 'supplier_page.dart';

enum DashboardSection {
  insight,
  pos,
  products,
  stocks,
  grn,
  supplies,
  customers,
  invoice,
  reports,
  extensions,
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

  late final Map<DashboardSection, Widget> _pages = {
    DashboardSection.insight: const InsightPage(),
    DashboardSection.pos: const PosPage(),
    DashboardSection.products: const ProductPage(),
    DashboardSection.stocks: const StockPage(),
    DashboardSection.grn: const GrnPage(),
    DashboardSection.supplies: const SupplierPage(),
    DashboardSection.customers: const CustomerPage(),
    DashboardSection.invoice: const InvoicePage(),
    DashboardSection.reports: const ComingSoonPage(
      title: 'Reports',
      description: 'View sales reports, trends, and operational summaries.',
      icon: Icons.bar_chart_rounded,
    ),
    DashboardSection.extensions: const ComingSoonPage(
      title: 'Extensions',
      description: 'Configure integrations and additional POS capabilities.',
      icon: Icons.extension_outlined,
    ),
    DashboardSection.settings: const ComingSoonPage(
      title: 'Settings',
      description:
          'Control application preferences, roles, and business details.',
      icon: Icons.settings_outlined,
    ),
    DashboardSection.backups: const ComingSoonPage(
      title: 'Backups',
      description:
          'Manage backup schedules and restore points for your store data.',
      icon: Icons.storage_outlined,
    ),
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
    _NavItemData(DashboardSection.reports, Icons.bar_chart_rounded, 'Reports'),
    _NavItemData(
      DashboardSection.extensions,
      Icons.extension_outlined,
      'Extensions',
    ),
    _NavItemData(
      DashboardSection.settings,
      Icons.settings_outlined,
      'Settings',
    ),
    _NavItemData(DashboardSection.backups, Icons.storage_outlined, 'Backups'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: Row(
        children: [
          _DashboardSidebar(
            items: _navItems,
            selectedSection: _selectedSection,
            onSectionSelected: (section) {
              setState(() => _selectedSection = section);
            },
            onLogout: () {
              AppToast.info('Logged out successfully');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          Expanded(
            child: Column(
              children: [
                const _DashboardTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: DashboardSection.values.indexOf(_selectedSection),
                    children: DashboardSection.values
                        .map((section) => _pages[section]!)
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
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: Color(0xFFE4EAF2))),
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
  const _DashboardTopBar();

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
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF36ABA5),
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
          color: isActive ? const Color(0xFF36ABA5) : Colors.transparent,
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
