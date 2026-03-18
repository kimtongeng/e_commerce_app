import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'product_detail_screen.dart';
import 'checkout_screen.dart';

const String _cartBaseUrl = 'http://10.0.2.2:3000';

// ─── Models ───────────────────────────────────────────────────────────────────

class CartProduct {
  final String id;
  final String title;
  final double price;
  final List<dynamic> images;
  final String category;
  final String brand;

  CartProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.images,
    required this.category,
    required this.brand,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: json['image'] ?? [],
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
    );
  }
}

class CartItem {
  final String itemId; // _id of the cart item entry
  final CartProduct product;
  int quantity;

  CartItem({
    required this.itemId,
    required this.product,
    required this.quantity,
  });
}

// ─── Cart Screen ──────────────────────────────────────────────────────────────

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = [];
  bool _isLoading = true;
  String? _error;

  // Per-item quantity update loading
  final Set<String> _updatingIds = {};
  final Set<String> _removingIds = {};
  bool _isClearing = false;

  // Promo
  final TextEditingController _promoController = TextEditingController();
  double _promoDiscount = 0;
  bool _applyingPromo = false;
  String? _promoError;

  final double _shippingCost = 10.0;

  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  // ─── Fetch cart ──────────────────────────────────────────────────────────
  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('$_cartBaseUrl/cart/$_uid'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawItems = data['items'] as List<dynamic>? ?? [];
        final List<CartItem> parsed = [];
        for (final item in rawItems) {
          final rawProduct = item['productId'];
          if (rawProduct == null) continue;
          if (rawProduct is Map<String, dynamic>) {
            // Fully populated product object
            parsed.add(CartItem(
              itemId: item['_id'] ?? '',
              product: CartProduct.fromJson(rawProduct),
              quantity: item['quantity'] ?? 1,
            ));
          } else if (rawProduct is String && rawProduct.isNotEmpty) {
            // Only ID returned — create minimal product with the id so updates still work
            parsed.add(CartItem(
              itemId: item['_id'] ?? '',
              product: CartProduct(
                id: rawProduct,
                title: 'Product',
                price: 0,
                images: [],
                category: '',
                brand: '',
              ),
              quantity: item['quantity'] ?? 1,
            ));
          }
        }
        setState(() {
          _items = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load cart (${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Update quantity ─────────────────────────────────────────────────────
  Future<void> _updateQuantity(CartItem item, int newQty) async {
    if (newQty < 1) {
      _removeItem(item);
      return;
    }
    if (_updatingIds.contains(item.itemId)) return;
    if (item.product.id.isEmpty) {
      await _fetchCart(); // re-fetch to get populated product ids
      return;
    }
    final originalQty = item.quantity;
    setState(() {
      _updatingIds.add(item.itemId);
      item.quantity = newQty; // optimistic
    });
    try {
      final body = jsonEncode({
        'userId': _uid,
        'productId': item.product.id,
        'quantity': newQty,
      });
      final res = await http.put(
        Uri.parse('$_cartBaseUrl/cart/update'),
        headers: _headers,
        body: body,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        setState(() => item.quantity = originalQty);
        _showSnack('Failed to update quantity (${res.statusCode})');
      }
    } catch (_) {
      setState(() => item.quantity = originalQty);
      _showSnack('Connection error');
    }
    setState(() => _updatingIds.remove(item.itemId));
  }

  // ─── Remove item ─────────────────────────────────────────────────────────
  Future<void> _removeItem(CartItem item) async {
    if (_removingIds.contains(item.itemId)) return;
    setState(() => _removingIds.add(item.itemId));
    try {
      final res = await http.delete(
        Uri.parse('$_cartBaseUrl/cart/remove/$_uid/${item.product.id}'),
        headers: _headers,
      );
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        setState(() => _items.removeWhere((i) => i.itemId == item.itemId));
      } else {
        _showSnack('Failed to remove item');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _removingIds.remove(item.itemId));
  }

  // ─── Clear cart ──────────────────────────────────────────────────────────
  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isClearing = true);
    try {
      final res = await http.delete(
        Uri.parse('$_cartBaseUrl/cart/clear/$_uid'),
        headers: _headers,
      );
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        setState(() {
          _items.clear();
          _promoDiscount = 0;
          _promoController.clear();
        });
      } else {
        _showSnack('Failed to clear cart');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _isClearing = false);
  }

  // ─── Promo code (mock) ───────────────────────────────────────────────────
  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    setState(() {
      _applyingPromo = true;
      _promoError = null;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _applyingPromo = false;
        if (code == 'SAVE20') {
          _promoDiscount = 20;
          _showSnack('Promo applied! \$20 off');
        } else if (code == 'HALF50') {
          _promoDiscount = _subtotal * 0.5;
          _showSnack('Promo applied! 50% off');
        } else {
          _promoDiscount = 0;
          _promoError = 'Invalid promo code';
        }
      });
    });
  }

  // ─── Totals ──────────────────────────────────────────────────────────────
  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.product.price * i.quantity);
  double get _total => _subtotal + _shippingCost - _promoDiscount;
  int get _itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.indigo))
            : _error != null
                ? _buildError()
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _items.isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                onRefresh: _fetchCart,
                                color: Colors.indigo,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      ..._items
                                          .map((item) => _buildCartItem(item)),
                                      const SizedBox(height: 12),
                                      _buildPromoSection(),
                                      const SizedBox(height: 12),
                                      _buildOrderSummary(),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      if (_items.isNotEmpty) _buildCheckoutBar(),
                    ],
                  ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Cart',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                if (_items.isNotEmpty)
                  Text('$_itemCount item${_itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            GestureDetector(
              onTap: _isClearing ? null : _clearCart,
              child: _isClearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.red))
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text('Clear All',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w500)),
                    ),
            ),
        ],
      ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.indigo),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchCart,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 48, color: Colors.indigo),
          ),
          const SizedBox(height: 20),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('Add items to get started',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Shopping',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Cart Item Card ───────────────────────────────────────────────────────
  Widget _buildCartItem(CartItem item) {
    final hasImage = item.product.images.isNotEmpty;
    final imageUrl = hasImage
        ? '$_cartBaseUrl/uploads/products/${item.product.images[0]}'
        : null;
    final isRemoving = _removingIds.contains(item.itemId);
    final isUpdating = _updatingIds.contains(item.itemId);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: item.product.id,
              heroImageUrl: imageUrl,
            ),
          ),
        );
        _fetchCart(); // ✅ refresh cart when returning from product detail
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isRemoving ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.indigo.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // ── Image ──────────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Container(
                  width: 100,
                  height: 110,
                  color: const Color(0xFFE8EAF6),
                  child: imageUrl != null
                      ? Image.network(imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.indigo, size: 28)),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.indigo));
                          })
                      : const Center(
                          child: Icon(Icons.shopping_bag,
                              size: 36, color: Colors.indigo)),
                ),
              ),

              // ── Info ───────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
                                Text(item.product.brand.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(item.product.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(item.product.category,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          ),
                          // ── Remove X ─────────────────────────────────
                          GestureDetector(
                            onTap: isRemoving ? null : () => _removeItem(item),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: isRemoving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF9CA3AF)))
                                  : const Icon(Icons.close,
                                      size: 18, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price
                          Text(
                            '\$${(item.product.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          ),
                          // ── Quantity stepper ──────────────────────────
                          Row(
                            children: [
                              _stepBtn(
                                icon: Icons.remove,
                                onTap: isUpdating
                                    ? null
                                    : () => _updateQuantity(
                                        item, item.quantity - 1),
                              ),
                              Container(
                                width: 36,
                                height: 32,
                                alignment: Alignment.center,
                                child: isUpdating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.indigo))
                                    : Text('${item.quantity}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937))),
                              ),
                              _stepBtn(
                                icon: Icons.add,
                                onTap: isUpdating
                                    ? null
                                    : () => _updateQuantity(
                                        item, item.quantity + 1),
                                filled: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? Colors.indigo : const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        child: Icon(icon,
            size: 16, color: filled ? Colors.white : const Color(0xFF374151)),
      ),
    );
  }

  // ─── Promo Code ───────────────────────────────────────────────────────────
  Widget _buildPromoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Promo Code',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle:
                        const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    errorText: _promoError,
                    errorStyle: const TextStyle(fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyingPromo ? null : _applyPromo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _applyingPromo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_promoDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Promo applied! -\$${_promoDiscount.toStringAsFixed(2)} off',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Order Summary ────────────────────────────────────────────────────────
  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _summaryRow('Shipping', '\$${_shippingCost.toStringAsFixed(2)}'),
          if (_promoDiscount > 0) ...[
            const SizedBox(height: 10),
            _summaryRow(
              'Promo Discount',
              '-\$${_promoDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              Text(
                '\$${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1F2937))),
      ],
    );
  }

  // ─── Checkout Bar ─────────────────────────────────────────────────────────
  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutScreen(
              subtotal: _subtotal,
              shippingFee: _shippingCost,
              promoDiscount: _promoDiscount,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Proceed to Checkout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.arrow_forward,
                  size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
