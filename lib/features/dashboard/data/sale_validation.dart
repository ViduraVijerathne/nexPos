import '../models/models.dart';

String? validateSaleInput({
  required List<PosCartItem> items,
  required double amountPaid,
  required double cashPaidAmount,
  required double cardPaidAmount,
  required double discountAmount,
  required double taxAmount,
}) {
  if (items.isEmpty) {
    return 'Add at least one item to the cart';
  }
  if (items.any(
    (item) =>
        item.quantity <= 0 || !item.unitPrice.isFinite || item.unitPrice < 0,
  )) {
    return 'Cart quantities and prices must be valid';
  }
  final amounts = [
    amountPaid,
    cashPaidAmount,
    cardPaidAmount,
    discountAmount,
    taxAmount,
  ];
  if (amounts.any((amount) => !amount.isFinite || amount < 0)) {
    return 'Payment amounts, discount and tax must be finite and non-negative';
  }
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
  final total = subtotal - discountAmount.clamp(0, subtotal) + taxAmount;
  if (!total.isFinite) {
    return 'Sale total must be finite';
  }
  if ((amountPaid - (cashPaidAmount + cardPaidAmount)).abs() > 0.000001) {
    return 'Paid amount must match cash and card payments';
  }
  if (amountPaid < total) {
    return 'Paid amount must be equal to or greater than total';
  }
  if (cardPaidAmount > total) {
    return 'Card payment cannot exceed the sale total';
  }
  return null;
}
