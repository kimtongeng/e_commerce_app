import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'auth_session.dart';
import 'orders_screen.dart';
import 'ecommerce_home.dart';

const String _paypalBaseUrl = 'http://10.0.2.2:3000';

class PaypalWebview extends StatefulWidget {
  final String url;
  const PaypalWebview({super.key, required this.url});

  @override
  State<PaypalWebview> createState() => _PaypalWebviewState();
}

class _PaypalWebviewState extends State<PaypalWebview> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _capturing = false;
  bool _handled = false;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (_handled) return;
            if (url.contains('/paypal/success') ||
                url.contains('paypal-success')) {
              _handled = true;
              final token = Uri.parse(url).queryParameters['token'];
              _handleSuccess(token);
              return;
            }
            if (url.contains('/paypal/cancel') ||
                url.contains('paypal-cancel')) {
              _handled = true;
              _handleCancel();
              return;
            }
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (_handled) return;
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (_handled) return;
            final url = error.url ?? '';
            if (url.contains('/paypal/success') ||
                url.contains('paypal-success')) {
              _handled = true;
              final token = Uri.parse(url).queryParameters['token'];
              _handleSuccess(token);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_handled) return NavigationDecision.prevent;
            final url = request.url;
            if (url.contains('/paypal/success') ||
                url.contains('paypal-success')) {
              _handled = true;
              final token = Uri.parse(url).queryParameters['token'];
              _handleSuccess(token);
              return NavigationDecision.prevent;
            }
            if (url.contains('/paypal/cancel') ||
                url.contains('paypal-cancel')) {
              _handled = true;
              _handleCancel();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleSuccess(String? token) async {
    if (token == null || token.isEmpty) {
      _showSnack('Missing payment token');
      if (mounted) Navigator.pop(context, false);
      return;
    }

    if (mounted) setState(() => _capturing = true);

    try {
      final res = await http.post(
        Uri.parse('$_paypalBaseUrl/paypal/capture'),
        headers: _headers,
        body: jsonEncode({'orderId': token}),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _capturing = false);
        _showSuccessDialog();
      } else {
        _showSnack('Capture failed (${res.statusCode})');
        Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Network error: $e');
        Navigator.pop(context, false);
      }
    }
  }

  void _showSuccessDialog() {
    // ✅ Capture the widget's own context BEFORE opening dialog
    final rootContext = context;

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 52),
              ),
              const SizedBox(height: 20),
              const Text('Payment Successful!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 8),
              const Text(
                'Your order has been confirmed and is being processed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF003087),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text('Pay',
                            style: TextStyle(
                                color: Color(0xFF009CDE),
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Paid via PayPal',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF003087),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ "View My Orders" — close dialog then navigate using rootContext
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // close dialog
                    // Stack: HomeScreen → OrdersScreen
                    // Back from OrdersScreen naturally returns to HomeScreen
                    Navigator.of(rootContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                          builder: (_) => const OrdersScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View My Orders',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ "Continue Shopping" — close dialog then navigate to HomeScreen
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // close dialog
                    Navigator.of(rootContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Continue Shopping',
                      style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCancel() {
    if (!mounted) return;
    _showSnack('Payment cancelled');
    Navigator.pop(context, false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('Pay',
                style: TextStyle(
                    color: Color(0xFF009CDE),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('Pal',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_handled) {
              _handled = true;
              Navigator.pop(context, false);
            }
          },
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && !_capturing)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF003087),
              color: Color(0xFF009CDE),
            ),
          if (_capturing)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text('Confirming payment...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Text('Please wait',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}