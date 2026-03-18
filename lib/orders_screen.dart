import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'paypal_webview.dart';

const String _ordersBaseUrl = 'http://10.0.2.2:3000';

// ─── Models ───────────────────────────────────────────────────────────────────

class OrderItem {
  final String productId;
  final String title;
  final String brand;
  final double price;
  final int quantity;
  final List<dynamic> images;
  final String category;

  OrderItem({
    required this.productId,
    required this.title,
    required this.brand,
    required this.price,
    required this.quantity,
    required this.images,
    required this.category,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['productId'];
    if (product is Map<String, dynamic>) {
      return OrderItem(
        productId: product['_id'] ?? '',
        title: product['title'] ?? 'Product',
        brand: product['brand'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
        images: product['image'] ?? [],
        category: product['category'] ?? '',
      );
    }
    return OrderItem(
      productId: product?.toString() ?? '',
      title: 'Product',
      brand: '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      images: [],
      category: '',
    );
  }
}

// ✅ Embedded address object returned directly inside the order
class OrderAddress {
  final String fullName;
  final String phone;
  final String street;
  final String city;
  final String province;
  final String postalCode;

  OrderAddress({
    required this.fullName,
    required this.phone,
    required this.street,
    required this.city,
    required this.province,
    required this.postalCode,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postalCode'] ?? '',
    );
  }

  String get fullAddress =>
      '$street, $city, $province${postalCode.isNotEmpty ? ' $postalCode' : ''}';
}

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingFee;
  final double total;
  final String status;
  final String paymentStatus;
  final String paymentProvider;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime? paidAt;
  final OrderAddress? address; // ✅ embedded address

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.paymentProvider,
    this.paymentId,
    required this.createdAt,
    this.paidAt,
    this.address,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromJson(e))
          .toList(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      paymentProvider: json['paymentProvider'] ?? 'paypal',
      paymentId: json['paymentId'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt']) : null,
      address: json['address'] != null
          ? OrderAddress.fromJson(json['address'])
          : null,
    );
  }
}

// ─── Orders Screen ────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_ordersBaseUrl/orders/my/$_uid'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _orders = data.map((e) => Order.fromJson(e)).toList();
          _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } else {
        setState(() => _error = 'Failed to load orders (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    }
    setState(() => _isLoading = false);
  }

  List<Order> get _allOrders => _orders;
  List<Order> get _paidOrders =>
      _orders.where((o) => o.status == 'paid' || o.status == 'processing').toList();
  List<Order> get _pendingOrders =>
      _orders.where((o) => o.status == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                  : _error != null
                      ? _buildError()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOrderList(_allOrders),
                            _buildOrderList(_paidOrders),
                            _buildOrderList(_pendingOrders),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                Text('${_orders.length} order${_orders.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          GestureDetector(
            onTap: _fetchOrders,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh, size: 18, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.indigo,
        unselectedLabelColor: const Color(0xFF9CA3AF),
        indicatorColor: Colors.indigo,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          Tab(text: 'All (${_allOrders.length})'),
          Tab(text: 'Paid (${_paidOrders.length})'),
          Tab(text: 'Pending (${_pendingOrders.length})'),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Colors.indigo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => _buildOrderCard(orders[i]),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _statusColor(order.status);
    final statusIcon = _statusIcon(order.status);
    final itemCount = order.items.fold<int>(0, (s, i) => s + i.quantity);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
        _fetchOrders();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.id.substring(order.id.length - 8).toUpperCase()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 3),
                  Text('$itemCount item${itemCount == 1 ? '' : 's'} • ${_formatDate(order.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  _buildStatusBadge(order.status),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 44, color: Colors.indigo),
          ),
          const SizedBox(height: 16),
          const Text('No orders yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 6),
          const Text('Your orders will appear here',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start Shopping', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.indigo),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return Colors.green;
      case 'processing':  return Colors.blue;
      case 'shipped':     return Colors.orange;
      case 'delivered':   return Colors.teal;
      case 'cancelled':   return Colors.red;
      default:            return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return Icons.check_circle_outline;
      case 'processing':  return Icons.autorenew;
      case 'shipped':     return Icons.local_shipping_outlined;
      case 'delivered':   return Icons.done_all;
      case 'cancelled':   return Icons.cancel_outlined;
      default:            return Icons.schedule;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return 'PAID';
      case 'processing':  return 'PROCESSING';
      case 'shipped':     return 'SHIPPED';
      case 'delivered':   return 'DELIVERED';
      case 'cancelled':   return 'CANCELLED';
      default:            return 'PENDING';
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Order Detail Screen ──────────────────────────────────────────────────────

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _payingNow = false;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  Future<void> _payNow() async {
    if (_payingNow) return;
    setState(() => _payingNow = true);
    try {
      final res = await http.post(
        Uri.parse('$_ordersBaseUrl/paypal/create'),
        headers: _headers,
        body: jsonEncode({
          'currency': 'USD',
          'description': 'Order #${widget.order.id}',
          'order_id': widget.order.id,
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        _showSnack('Failed to init payment (${res.statusCode})');
        return;
      }
      final data = jsonDecode(res.body);
      final approveUrl = data['approveUrl'];
      if (approveUrl == null) { _showSnack('No approval URL returned'); return; }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PaypalWebview(url: approveUrl)));
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _payingNow = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isPending => widget.order.status == 'pending';

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return Colors.green;
      case 'processing':  return Colors.blue;
      case 'shipped':     return Colors.orange;
      case 'delivered':   return Colors.teal;
      case 'cancelled':   return Colors.red;
      default:            return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return Icons.check_circle_outline;
      case 'processing':  return Icons.autorenew;
      case 'shipped':     return Icons.local_shipping_outlined;
      case 'delivered':   return Icons.done_all;
      case 'cancelled':   return Icons.cancel_outlined;
      default:            return Icons.schedule;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid':        return 'PAID';
      case 'processing':  return 'PROCESSING';
      case 'shipped':     return 'SHIPPED';
      case 'delivered':   return 'DELIVERED';
      case 'cancelled':   return 'CANCELLED';
      default:            return 'PENDING';
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(dt)} at $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = _statusColor(order.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Details',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        Text('#${order.id.substring(order.id.length - 8).toUpperCase()}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(order.status), size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(_statusLabel(order.status),
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Pending warning
                    if (_isPending) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                            SizedBox(width: 10),
                            Expanded(child: Text(
                              'This order is awaiting payment. Complete your payment to confirm the order.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Order Info ───────────────────────────────────────────
                    _sectionTitle('Order Information'),
                    const SizedBox(height: 8),
                    _infoCard([
                      _infoRow(Icons.tag, 'Order ID', order.id.toUpperCase()),
                      _infoRow(Icons.calendar_today_outlined, 'Placed On', _formatDateTime(order.createdAt)),
                      if (order.paidAt != null)
                        _infoRow(Icons.check_circle_outline, 'Paid On', _formatDateTime(order.paidAt!),
                            valueColor: Colors.green),
                      _infoRow(Icons.inventory_2_outlined, 'Total Items',
                          '${order.items.fold<int>(0, (s, i) => s + i.quantity)} item(s)'),
                    ]),

                    const SizedBox(height: 16),

                    // ── Shipping Address ─────────────────────────────────────
                    if (order.address != null) ...[
                      _sectionTitle('Shipping Address'),
                      const SizedBox(height: 8),
                      _infoCard([
                        _infoRow(Icons.person_outline, 'Name', order.address!.fullName),
                        _infoRow(Icons.phone_outlined, 'Phone', order.address!.phone),
                        _infoRow(Icons.location_on_outlined, 'Address', order.address!.fullAddress),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // ── Payment ──────────────────────────────────────────────
                    _sectionTitle('Payment'),
                    const SizedBox(height: 8),
                    _infoCard([
                      _infoRow(Icons.payment_outlined, 'Provider', order.paymentProvider.toUpperCase()),
                      _infoRow(
                        order.paymentStatus == 'paid'
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        'Payment Status',
                        order.paymentStatus.toUpperCase(),
                        valueColor: order.paymentStatus == 'paid' ? Colors.green : const Color(0xFFF59E0B),
                      ),
                      if (order.paymentId != null)
                        _infoRow(Icons.receipt_outlined, 'Transaction ID', order.paymentId!),
                    ]),

                    const SizedBox(height: 16),

                    // ── Items ────────────────────────────────────────────────
                    _sectionTitle('Items (${order.items.length})'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: order.items.asMap().entries.map((e) {
                          final idx = e.key;
                          final item = e.value;
                          final imageUrl = item.images.isNotEmpty
                              ? '$_ordersBaseUrl/uploads/products/${item.images[0]}'
                              : null;
                          final isLast = idx == order.items.length - 1;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60, height: 60,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8EAF6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: imageUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.network(imageUrl, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons.shopping_bag, color: Colors.indigo, size: 26)),
                                            )
                                          : const Icon(Icons.shopping_bag, color: Colors.indigo, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (item.brand.isNotEmpty)
                                            Text(item.brand.toUpperCase(),
                                                style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          Text(item.title,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                              maxLines: 2, overflow: TextOverflow.ellipsis),
                                          if (item.category.isNotEmpty)
                                            Text(item.category, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(6)),
                                                child: Text('Qty: ${item.quantity}',
                                                    style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('\$${item.price.toStringAsFixed(2)} each',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 14, endIndent: 14),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Price Summary ────────────────────────────────────────
                    _sectionTitle('Price Summary'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _summaryRow('Shipping Fee', '\$${order.shippingFee.toStringAsFixed(2)}'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                              Text('\$${order.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Pay Now (pending only) ───────────────────────────────────────
            if (_isPending)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, -3))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _payingNow ? null : _payNow,
                        icon: _payingNow
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(color: const Color(0xFF009CDE), borderRadius: BorderRadius.circular(4)),
                                child: const Center(child: Text('Pay', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                              ),
                        label: Text(
                          _payingNow ? 'Initializing...' : 'Pay \$${widget.order.total.toStringAsFixed(2)} with PayPal',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003087),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor: const Color(0xFFD1D5DB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outlined, size: 12, color: Color(0xFF9CA3AF)),
                        SizedBox(width: 4),
                        Text('SECURE PAYMENT  •  POWERED BY PAYPAL',
                            style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151), letterSpacing: 0.3));

  Widget _infoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            e.value,
            if (!isLast) const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 14, endIndent: 14),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: Colors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: valueColor ?? const Color(0xFF1F2937)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ],
      );
}