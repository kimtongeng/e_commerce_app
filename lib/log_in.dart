import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_session.dart';
import 'ecommerce_home.dart';
import 'register_screen.dart';

const String _baseUrl = "http://10.0.2.2:3000";
const Color kBrand = Color.fromARGB(255, 98, 113, 241);

// Keys for SharedPreferences
const String _prefRemember = 'remember_me';
const String _prefEmail = 'saved_email';
const String _prefPassword = 'saved_password';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  // ─── Load saved credentials ───────────────────────────────────────────────
  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_prefRemember) ?? false;
    if (remember) {
      _emailController.text = prefs.getString(_prefEmail) ?? '';
      _passwordController.text = prefs.getString(_prefPassword) ?? '';
    }
    setState(() => _rememberMe = remember);
  }

  // ─── Save / clear credentials ─────────────────────────────────────────────
  Future<void> _persistCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_prefRemember, true);
      await prefs.setString(_prefEmail, email);
      await prefs.setString(_prefPassword, password);
    } else {
      await prefs.remove(_prefRemember);
      await prefs.remove(_prefEmail);
      await prefs.remove(_prefPassword);
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please enter email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        AuthSession.instance.userId = data["user_id"] ?? '';
        AuthSession.instance.accessToken = data["access_token"] ?? '';

        await _persistCredentials(email, password);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showSnack(
            data["message"] ?? "Login failed (${response.statusCode})");
      }
    } catch (e) {
      _showSnack("Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  void _showForgotPassword() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_outlined, color: kBrand, size: 22),
            SizedBox(width: 8),
            Text('Forgot Password',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Password reset is coming soon!\n\nWe\'re working on this feature. Please contact support if you need immediate help.',
          style: TextStyle(
              fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Logo / Icon ─────────────────────────────────────────────
              const Center(
                child: Icon(Icons.shopping_bag,
                    size: 80, color: kBrand),
              ),
              const SizedBox(height: 36),

              // ── Headline ────────────────────────────────────────────────
              const Text(
                'Welcome Back',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    height: 1.2),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to continue shopping',
                style:
                    TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),

              const SizedBox(height: 36),

              // ── Email field ─────────────────────────────────────────────
              _fieldLabel('Email Address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'email@example.com',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.email_outlined,
                      size: 20, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: kBrand, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Password field ──────────────────────────────────────────
              _fieldLabel('Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline,
                      size: 20, color: Color(0xFF9CA3AF)),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: kBrand, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Remember Me / Forgot password ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _rememberMe
                                ? kBrand
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _rememberMe
                                  ? kBrand
                                  : const Color(0xFF9CA3AF),
                              width: 1.5,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        const Text('Remember me',
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showForgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                          color: kBrand,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Sign In Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Sign In',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign Up link ────────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF6B7280))),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              fontSize: 14,
                              color: kBrand,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151)),
      );
}