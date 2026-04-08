import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';

class ExtensionPage extends StatefulWidget {
  const ExtensionPage({super.key});

  @override
  State<ExtensionPage> createState() => _ExtensionPageState();
}

class _ExtensionPageState extends State<ExtensionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';

  static const List<_ExtensionItem> _extensions = <_ExtensionItem>[
    _ExtensionItem(
      name: 'Point of Sale',
      description: 'Core billing and checkout workflow for cashier operations.',
      version: 'v3.0.1',
      rating: 5.0,
      downloads: '18.4k',
      installed: true,
      icon: Icons.point_of_sale_rounded,
    ),
    _ExtensionItem(
      name: 'Customer Management',
      description: 'Manage customer details, purchases, and interactions.',
      version: 'v2.4.0',
      rating: 4.9,
      downloads: '11.2k',
      installed: true,
      icon: Icons.people_outline_rounded,
    ),
    _ExtensionItem(
      name: 'Report Extension',
      description: 'Generate revenue, inventory, and customer analytics.',
      version: 'v1.7.3',
      rating: 4.8,
      downloads: '9.7k',
      installed: true,
      icon: Icons.bar_chart_rounded,
    ),
    _ExtensionItem(
      name: 'Inventory Management',
      description: 'Track stock levels, valuation, and stock alerts.',
      version: 'v2.3.4',
      rating: 4.9,
      downloads: '14.5k',
      installed: true,
      icon: Icons.inventory_2_outlined,
    ),
    _ExtensionItem(
      name: 'Advanced Analytics',
      description:
          'Get detailed insights with advanced analytics and custom reports.',
      version: 'v2.1.0',
      rating: 4.8,
      downloads: '12.5k',
      installed: false,
      icon: Icons.insights_outlined,
    ),
    _ExtensionItem(
      name: 'Loyalty Program',
      description: 'Reward your customers with points and special discounts.',
      version: 'v1.5.2',
      rating: 4.6,
      downloads: '8.2k',
      installed: false,
      icon: Icons.star_border_rounded,
    ),
    _ExtensionItem(
      name: 'Multi-Currency Support',
      description:
          'Accept payments in multiple currencies with real-time conversion.',
      version: 'v3.0.1',
      rating: 4.9,
      downloads: '15.3k',
      installed: false,
      icon: Icons.account_balance_wallet_outlined,
    ),
    _ExtensionItem(
      name: 'Receipt Designer',
      description:
          'Customize your receipts with logos, colors, and custom fields.',
      version: 'v1.8.0',
      rating: 4.7,
      downloads: '9.8k',
      installed: false,
      icon: Icons.receipt_long_outlined,
    ),
  ];

  List<_ExtensionItem> get _filteredExtensions {
    final query = _searchController.text.trim().toLowerCase();
    return _extensions.where((item) {
      final matchesFilter = switch (_filter) {
        'Installed' => item.installed,
        'Not Installed' => !item.installed,
        _ => true,
      };
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  int get _installedCount => _extensions.where((item) => item.installed).length;

  String get _totalDownloadsText {
    final total = _extensions.fold<double>(
      0,
      (sum, item) => sum + double.parse(item.downloads.replaceAll('k', '')),
    );
    return '${total.toStringAsFixed(1)}k';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleExtensionTap(_ExtensionItem item) {
    if (item.installed) {
      AppToast.info('${item.name} extension is already installed');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Extension Not Installed',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        content: Text(
          'Please contact customer support to install the ${item.name} extension.',
          style: const TextStyle(height: 1.5, color: Color(0xFF5B6A7E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extensions = _filteredExtensions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ExtensionHeader(),
          const SizedBox(height: 18),
          _ExtensionFilterBar(
            searchController: _searchController,
            selectedFilter: _filter,
            onChanged: () => setState(() {}),
            onFilterChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.extension_outlined,
                  value: '${_extensions.length}',
                  label: 'Available Extensions',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.check_rounded,
                  value: '$_installedCount',
                  label: 'Installed',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.download_outlined,
                  value: _totalDownloadsText,
                  label: 'Total Downloads',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: extensions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              final item = extensions[index];
              return _ExtensionCard(
                item: item,
                onTap: () => _handleExtensionTap(item),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExtensionHeader extends StatelessWidget {
  const _ExtensionHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extensions',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Enhance your POS system with powerful extensions and features.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8492A6),
          ),
        ),
      ],
    );
  }
}

class _ExtensionFilterBar extends StatelessWidget {
  const _ExtensionFilterBar({
    required this.searchController,
    required this.selectedFilter,
    required this.onChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final String selectedFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText: 'Search extensions...',
                hintStyle: const TextStyle(
                  color: Color(0xFFA2AEBD),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF9CACBE),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: DropdownButtonFormField<String>(
              value: selectedFilter,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
              ),
              items: const ['All', 'Installed', 'Not Installed']
                  .map(
                    (filter) => DropdownMenuItem<String>(
                      value: filter,
                      child: Text(filter),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onFilterChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE8FBF7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF36B4AE), size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A97AA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({required this.item, required this.onTap});

  final _ExtensionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FBF7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF36B4AE),
                  size: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.version,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF97A4B6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374457),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: Color(0xFF7D8BA0),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFF4B400),
              ),
              const SizedBox(width: 4),
              Text(
                '${item.rating}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C5A6D),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.download_outlined,
                size: 16,
                color: Color(0xFF97A4B6),
              ),
              const SizedBox(width: 4),
              Text(
                item.downloads,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF97A4B6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: item.installed
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF36B4AE),
                foregroundColor: item.installed
                    ? const Color(0xFF4B5563)
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                item.installed ? Icons.check_rounded : Icons.download_outlined,
                size: 16,
              ),
              label: Text(
                item.installed ? 'Installed' : 'Install',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE7EDF5)),
    boxShadow: const [
      BoxShadow(color: Color(0x120F172A), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );
}

class _ExtensionItem {
  const _ExtensionItem({
    required this.name,
    required this.description,
    required this.version,
    required this.rating,
    required this.downloads,
    required this.installed,
    required this.icon,
  });

  final String name;
  final String description;
  final String version;
  final double rating;
  final String downloads;
  final bool installed;
  final IconData icon;
}
