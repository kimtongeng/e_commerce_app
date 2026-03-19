import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'addresses_screen.dart';
import 'log_in.dart';
import 'wishlist_screen.dart';
import 'orders_screen.dart';
import 'edit_profile_screen.dart';
import 'support_center_screen.dart';

const String _accountBaseUrl = 'http://10.0.2.2:3000';
const Color kBrand = Color.fromARGB(255, 98, 113, 241);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$_accountBaseUrl/auth/profile'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _profile = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final res = await http.post(
                  Uri.parse('$_accountBaseUrl/auth/logout'),
                  headers: _headers,
                );

                Navigator.pop(context);

                if (res.statusCode == 200 || res.statusCode == 201) {
                  AuthSession.instance.clear();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                } else {
                  _showSnack("Logout failed");
                }
              } catch (e) {
                Navigator.pop(context);
                _showSnack("Network error");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile(String name, String email) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          currentName: name,
          currentEmail: email,
        ),
      ),
    );
    if (updated == true) _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['fullName'] ?? 'User';
    final email = _profile?['email'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kBrand))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(name, email, initial),
                    const SizedBox(height: 20),
                    _buildSection('MY SHOPPING', [
                      _buildMenuItem(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: kBrand,
                        iconBg: const Color(0xFFEEEFFD),
                        label: 'My Orders',
                        badge: null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrdersScreen()),
                        ),
                      ),
                      _buildMenuItem(
                        icon: Icons.favorite_border,
                        iconColor: Colors.red,
                        iconBg: const Color(0xFFFFEBEE),
                        label: 'Wishlist',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WishlistScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildSection('ACCOUNT DETAILS', [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        iconColor: kBrand,
                        iconBg: const Color(0xFFEEEFFD),
                        label: 'Edit Profile',
                        onTap: () => _openEditProfile(name, email),
                      ),
                      _buildMenuItem(
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        iconBg: const Color(0xFFFFFBEB),
                        label: 'Shipping Addresses',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddressesScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildSection('PREFERENCES', [
                      _buildMenuItem(
                        icon: Icons.tune,
                        iconColor: kBrand,
                        iconBg: const Color(0xFFEEEFFD),
                        label: 'Settings',
                        onTap: () => _showSnack('Settings coming soon'),
                      ),
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        iconColor: const Color(0xFF6B7280),
                        iconBg: const Color(0xFFF3F4F6),
                        label: 'Support Center',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SupportCenterScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSignOut(),
                    const SizedBox(height: 16),
                    const Text('App Version 1.0.0 (Build 1)',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(String name, String email, String initial) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 16, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 20, color: Color(0xFF1F2937)),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Account',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => _openEditProfile(name, email),
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEFFD),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kBrand.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: kBrand)),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                            color: kBrand, shape: BoxShape.circle),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openEditProfile(name, email),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 2),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to edit profile →',
                        style: TextStyle(
                            fontSize: 11,
                            color: kBrand,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.8)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOut() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _signOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}