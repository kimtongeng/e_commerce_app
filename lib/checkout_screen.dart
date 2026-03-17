import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'addresses_screen.dart';
import 'paypal_webview.dart';

const String _checkoutBaseUrl = 'http://10.0.2.2:3000';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;

  List<Address> _addresses = [];
  bool _loadingAddresses = true;
  String? _selectedAddressId;
  bool _placingOrder = false;

  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _placeOrder() async {
    if (_placingOrder) return;
    setState(() => _placingOrder = true);

    try {
      // Step 1: Create order from cart
      final orderRes = await http.post(
        Uri.parse('$_checkoutBaseUrl/orders'),
        headers: _headers,
        body: jsonEncode({'userId': _uid}),
      );

      if (orderRes.statusCode != 200 && orderRes.statusCode != 201) {
        _showSnack('Failed to create order (${orderRes.statusCode})');
        return;
      }

      final orderData = jsonDecode(orderRes.body);
      final orderId = orderData['_id'] ?? orderData['id'];

      if (orderId == null) {
        _showSnack('Order ID missing from response');
        return;
      }

      // Step 2: Create PayPal payment
      final paypalRes = await http.post(
        Uri.parse('$_checkoutBaseUrl/paypal/create'),
        headers: _headers,
        body: jsonEncode({
          'currency': 'USD',
          'description': 'Order #$orderId',
          'order_id': orderId,
        }),
      );

      if (paypalRes.statusCode != 200 && paypalRes.statusCode != 201) {
        _showSnack('PayPal init failed (${paypalRes.statusCode})');
        return;
      }

      final paypalData = jsonDecode(paypalRes.body);
      final approveUrl = paypalData['approveUrl'];

      if (approveUrl == null) {
        _showSnack('No approval URL returned');
        return;
      }

      // Step 3: Open PayPal WebView
      // ✅ Don't check result — WebView calls popUntil(isFirst) on success
      //    which pops this screen too, so result will always be null on success.
      //    On cancel, WebView pops with false and we stay here.
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaypalWebview(url: approveUrl),
        ),
      );

      // ✅ Only handle cancel here — success is handled by WebView's popUntil
      if (mounted && result == false) {
        _showSnack('Payment Cancelled');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  Future<void> _fetchAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final res = await http.get(
        Uri.parse('$_checkoutBaseUrl/addresses/$_uid'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List<dynamic> data = jsonDecode(res.body);
        final list = data.map((e) => Address.fromJson(e)).toList();
        setState(() {
          _addresses = list;
          final def = list.where((a) => a.isDefault).toList();
          _selectedAddressId = def.isNotEmpty
              ? def.first.id
              : (list.isNotEmpty ? list.first.id : null);
        });
      }
    } catch (_) {}
    setState(() => _loadingAddresses = false);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepper(),
            Expanded(
              child:
                  _currentStep == 0 ? _buildShippingStep() : _buildReviewStep(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
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
          const Expanded(
            child: Center(
              child: Text('Checkout',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
              _fetchAddresses();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_location_alt_outlined,
                  size: 18, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    const steps = ['SHIPPING', 'REVIEW'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final filled = 0 < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: filled ? Colors.indigo : const Color(0xFFE5E7EB),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < _currentStep;
          final isActive = stepIdx == _currentStep;
          return GestureDetector(
            onTap: () {
              if (stepIdx < _currentStep) {
                setState(() => _currentStep = stepIdx);
              }
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive ? Colors.indigo : Colors.white,
                    border: Border.all(
                      color: isDone || isActive
                          ? Colors.indigo
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${stepIdx + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF))),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[stepIdx],
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isActive || isDone
                            ? Colors.indigo
                            : const Color(0xFF9CA3AF))),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShippingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saved Addresses',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_addresses.length} Address${_addresses.length == 1 ? '' : 'es'}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Colors.indigo),
              ),
            )
          else if (_addresses.isEmpty)
            _buildNoAddresses()
          else
            ..._addresses.map((addr) => _buildAddressCard(addr)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
              _fetchAddresses();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFD1D5DB),
                    style: BorderStyle.solid,
                    width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 18, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Text('Add New Address',
                      style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC7D7FE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('Pay',
                        style: TextStyle(
                            color: Color(0xFF009CDE),
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Payment will be processed securely via PayPal',
                    style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 18, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free Shipping on orders over \$50',
                    style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAddresses() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off_outlined,
              size: 40, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 8),
          const Text('No saved addresses',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 4),
          const Text('Add an address to continue',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
              _fetchAddresses();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Address addr) {
    final isSelected = _selectedAddressId == addr.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedAddressId = addr.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.indigo : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.indigo.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                addr.isDefault
                    ? Icons.home_outlined
                    : Icons.location_on_outlined,
                size: 18,
                color: isSelected ? Colors.indigo : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(addr.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      if (addr.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('DEFAULT',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${addr.street}, ${addr.city}, ${addr.country} ${addr.zipCode}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  Text(addr.phone,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.indigo : Colors.white,
                border: Border.all(
                  color: isSelected ? Colors.indigo : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, size: 10, color: Colors.white))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final selectedAddr =
        _addresses.where((a) => a.id == _selectedAddressId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Review',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 16),
          if (selectedAddr.isNotEmpty)
            _reviewSection(
              icon: Icons.location_on_outlined,
              title: 'DELIVER TO',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selectedAddr.first.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937))),
                  Text(
                    '${selectedAddr.first.street}, ${selectedAddr.first.city}, ${selectedAddr.first.country} ${selectedAddr.first.zipCode}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  Text(selectedAddr.first.phone,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _reviewSection(
            icon: Icons.payment_outlined,
            title: 'PAYMENT',
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('Pay',
                        style: TextStyle(
                            color: Color(0xFF009CDE),
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('PayPal',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', '\$249.00'),
                const SizedBox(height: 8),
                _summaryRow('Shipping', 'Free'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Total',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937))),
                    Text('\$249.00',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF0369A1)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tapping "Place Order" will create your order and redirect you to PayPal to complete payment.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isReview = _currentStep == 1;
    final canContinue = _selectedAddressId != null && !_placingOrder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: canContinue
                  ? () {
                      if (isReview) {
                        _placeOrder();
                      } else {
                        setState(() => _currentStep++);
                      }
                    }
                  : null,
              icon: _placingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      isReview ? Icons.payment_outlined : Icons.arrow_forward,
                      size: 18),
              label: Text(
                  _placingOrder
                      ? 'Processing...'
                      : isReview
                          ? 'Place Order & Pay with PayPal'
                          : 'Continue to Review',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isReview ? const Color(0xFF003087) : Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
              Text('SECURE CHECKOUT  •  POWERED BY PAYPAL',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
