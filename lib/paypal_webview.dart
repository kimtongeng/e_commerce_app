import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'auth_session.dart';

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

  // ✅ Once we start handling, ignore ALL other callbacks
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
            if (_handled) return; // ✅ already handled, ignore everything

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
        // ✅ Go straight to home — NO snackbar here, no cancel possible
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showSnack('Capture failed (${res.statusCode})');
        if (mounted) Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Network error: $e');
        Navigator.pop(context, false);
      }
    }
  }

  void _handleCancel() {
    if (!mounted) return;
    // Only show cancel if we haven't already succeeded
    _showSnack('Payment cancelled');
    Navigator.pop(context, false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}