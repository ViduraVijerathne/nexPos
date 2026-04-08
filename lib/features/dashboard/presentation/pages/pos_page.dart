import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';

enum PaymentMethod { cash, card, upi }

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '500',
  );

  int _selectedCategoryIndex = 0;
  int _selectedProductIndex = 8;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;

  static const List<String> _categories = [
    'All',
    'busicuts',
    'd',
    '444',
    'fruits',
  ];

  static const List<_ProductData> _products = [
    _ProductData('manchee super cream cracker', 9, 77.00),
    _ProductData('manchee super cream cracker', 3, 88.00),
    _ProductData('dodam', 60, 88.00),
    _ProductData('manchee super cream cracker', 5, 99.00),
    _ProductData('dodam', 89, 999.00),
    _ProductData('product5', 71, 99.00),
    _ProductData('manchee super cream cracker', 7, 88.00),
    _ProductData('444', 21, 33.00),
    _ProductData('apple', 95, 888.00),
    _ProductData('manchee super cream cracker', 7, 7.00),
  ];

  static const List<_OrderItemData> _orderItems = [
    _OrderItemData('dodam', 1, 88.00),
    _OrderItemData('product5', 1, 99.00),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _PosHeader()),
              const SizedBox(width: 16),
              _PrimaryActionButton(
                label: 'New Transaction',
                icon: Icons.add,
                onPressed: () {
                  AppToast.success('New transaction started');
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _ProductsPanel(
                    searchController: _searchController,
                    categories: _categories,
                    products: _products,
                    selectedCategoryIndex: _selectedCategoryIndex,
                    selectedProductIndex: _selectedProductIndex,
                    onCategorySelected: (index) {
                      setState(() => _selectedCategoryIndex = index);
                    },
                    onProductSelected: (index) {
                      setState(() => _selectedProductIndex = index);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 356,
                  child: _CurrentOrderPanel(
                    items: _orderItems,
                    amountController: _amountController,
                    selectedPaymentMethod: _selectedPaymentMethod,
                    onPaymentMethodChanged: (method) {
                      setState(() => _selectedPaymentMethod = method);
                    },
                    onProcessPayment: () {
                      AppToast.success('Payment processed successfully');
                    },
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

class _PosHeader extends StatelessWidget {
  const _PosHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Point of Sale',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Process customer transactions and manage orders.',
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

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({
    required this.searchController,
    required this.categories,
    required this.products,
    required this.selectedCategoryIndex,
    required this.selectedProductIndex,
    required this.onCategorySelected,
    required this.onProductSelected,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final List<_ProductData> products;
  final int selectedCategoryIndex;
  final int selectedProductIndex;
  final ValueChanged<int> onCategorySelected;
  final ValueChanged<int> onProductSelected;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374457),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
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
                  vertical: 9,
                ),
                fillColor: const Color(0xFFFFFFFF),
                filled: true,
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
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _CategoryChip(
                  label: categories[index],
                  isSelected: index == selectedCategoryIndex,
                  onTap: () => onCategorySelected(index),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.98,
              ),
              itemBuilder: (context, index) {
                final product = products[index];

                return _ProductCard(
                  product: product,
                  isSelected: index == selectedProductIndex,
                  onTap: () => onProductSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentOrderPanel extends StatelessWidget {
  const _CurrentOrderPanel({
    required this.items,
    required this.amountController,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    required this.onProcessPayment,
  });

  final List<_OrderItemData> items;
  final TextEditingController amountController;
  final PaymentMethod selectedPaymentMethod;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onProcessPayment;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374457),
            ),
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            _OrderLineItem(item: item),
            const SizedBox(height: 10),
          ],
          const Divider(color: Color(0xFFEDF2F7), height: 18),
          const Text(
            'Customer',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          const _CustomerSearchField(),
          const SizedBox(height: 10),
          const _SelectedCustomerCard(),
          const SizedBox(height: 18),
          const _SummaryRow(label: 'Subtotal', value: 'Rs 187.00'),
          const SizedBox(height: 10),
          const _SummaryRow(
            label: 'Discount',
            value: '-\$6.88',
            valueColor: Color(0xFF46C2BC),
          ),
          const SizedBox(height: 10),
          const _SummaryRow(label: 'Tax (10%)', value: 'Rs 18.70'),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDF2F7), height: 1),
          const SizedBox(height: 14),
          const Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF344256),
                ),
              ),
              Spacer(),
              Text(
                'Rs 205.70',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF41C0BC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodButton(
                  label: 'Cash',
                  icon: Icons.receipt_long_outlined,
                  isSelected: selectedPaymentMethod == PaymentMethod.cash,
                  onTap: () => onPaymentMethodChanged(PaymentMethod.cash),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentMethodButton(
                  label: 'Card',
                  icon: Icons.credit_card_outlined,
                  isSelected: selectedPaymentMethod == PaymentMethod.card,
                  onTap: () => onPaymentMethodChanged(PaymentMethod.card),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentMethodButton(
                  label: 'UPI',
                  icon: Icons.account_balance_wallet_outlined,
                  isSelected: selectedPaymentMethod == PaymentMethod.upi,
                  onTap: () => onPaymentMethodChanged(PaymentMethod.upi),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Amount Paid',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: TextField(
              controller: amountController,
              decoration: InputDecoration(
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 8, right: 2),
                  child: Icon(
                    Icons.attach_money_rounded,
                    size: 16,
                    color: Color(0xFF78889E),
                  ),
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF647388),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFD8F5F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF7ED9D3)),
            ),
            child: const Row(
              children: [
                Text(
                  'Change to Return',
                  style: TextStyle(
                    color: Color(0xFF4A586B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Text(
                  '\$294.3',
                  style: TextStyle(
                    color: Color(0xFF36B4AE),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onProcessPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36B4AE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.credit_card_rounded, size: 16),
              label: const Text(
                'Process Payment',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF36B4AE) : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF36B4AE)
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : const Color(0xFF58677D),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final _ProductData product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF54D2CC)
                : const Color(0xFFE7EDF5),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1436B4AE),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 34,
                    color: Color(0xFFCBD6E4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF465366),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Stock: ${product.stock}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF96A3B6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF36B4AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderLineItem extends StatelessWidget {
  const _OrderLineItem({required this.item});

  final _OrderItemData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF465366),
                  ),
                ),
              ),
              const Text(
                'Remove',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFB6A6A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Qty: ${item.quantity} x Rs ${item.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF93A0B2),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF465366),
                ),
              ),
              const Spacer(),
              Text(
                'Rs ${(item.quantity * item.price).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF36B4AE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchField extends StatelessWidget {
  const _CustomerSearchField();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'BET23085 S.G.N.N.Bandara (444)',
          hintStyle: const TextStyle(
            color: Color(0xFF5F6E83),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            size: 17,
            color: Color(0xFF7D8BA0),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF36B4AE)),
          ),
        ),
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F5F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF65D4CC)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: Color(0xFF37AFA9),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BET23085 S.G.N.N.Bandara',
                  style: TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A586B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '444',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D7D92),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Clear',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFB6A6A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF55657A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7D8CA0),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF36B4AE) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF36B4AE)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.white : const Color(0xFF5A687D),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : const Color(0xFF5A687D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF36B4AE),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
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
      decoration: BoxDecoration(
        color: AppColors.white,
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
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _ProductData {
  const _ProductData(this.name, this.stock, this.price);

  final String name;
  final int stock;
  final double price;
}

class _OrderItemData {
  const _OrderItemData(this.name, this.quantity, this.price);

  final String name;
  final int quantity;
  final double price;
}
