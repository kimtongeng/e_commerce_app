import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'product_detail_screen.dart';

const String _wishlistBaseUrl = 'http://10.0.2.2:3000';
const Color kBrand = Color.fromARGB(255, 98, 113, 241);

// ─── Model ────────────────────────────────────────────────────────────────────

class WishlistItem {
  final String wishlistId;
  final String productId;
  final String title;
  final String description;
  final double price;
  final List<dynamic> images;
  final String category;
  final String brand;
  final double rating;
  final int stock;

  WishlistItem({
    required this.wishlistId,
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.brand,
    required this.rating,
    required this.stock,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    return WishlistItem(
      wishlistId: json['_id'] ?? '',
      productId: product['_id'] ?? '',
      title: product['title'] ?? '',
      description: product['description'] ?? '',
      price: (product['price'] ?? 0).toDouble(),
      images: product['image'] ?? [],
      category: product['category'] ?? '',
      brand: product['brand'] ?? '',
      rating: (product['rating'] ?? 0).toDouble(),
      stock: product['stock'] ?? 0,
    );
  }
}

// ─── Wishlist Screen ──────────────────────────────────────────────────────────

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<WishlistItem> _items = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _removingIds = {};

  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  // ─── Fetch wishlist ──────────────────────────────────────────────────────
  Future<void> _fetchWishlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_wishlistBaseUrl/wishlist/$_uid'),
        headers: _headers,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _items = data
              .where((e) => e['product'] != null)
              .map((e) => WishlistItem.fromJson(e))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load wishlist (${response.statusCode})';
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

  // ─── Remove from wishlist ─────────────────────────────────────────────────
  Future<void> _removeFromWishlist(WishlistItem item) async {
    if (_removingIds.contains(item.wishlistId)) return;
    setState(() => _removingIds.add(item.wishlistId));
    try {
      final response = await http.delete(
        Uri.parse('$_wishlistBaseUrl/wishlist/$_uid/${item.productId}'),
        headers: _headers,
      );
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(
            () => _items.removeWhere((i) => i.wishlistId == item.wishlistId));
        _showSnack('Removed from wishlist');
      } else {
        _showSnack('Failed to remove (${response.statusCode})');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _removingIds.remove(item.wishlistId));
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kBrand))
                  : _error != null
                      ? _buildError()
                      : _items.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchWishlist,
                              color: kBrand,
                              child: _buildList(),
                            ),
            ),
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
          const Expanded(
            child: Text(
              'My Wishlist',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
          ),
          if (_items.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_items.length} item${_items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12,
                    color: kBrand,
                    fontWeight: FontWeight.w600),
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
          const Icon(Icons.wifi_off, size: 60, color: kBrand),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchWishlist,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFEEEFFD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, size: 48, color: kBrand),
          ),
          const SizedBox(height: 20),
          const Text('Your wishlist is empty',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('Save items you love by tapping the heart icon',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrand,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start Shopping',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────
  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildCard(_items[i]),
    );
  }

  // ─── Wishlist Card ────────────────────────────────────────────────────────
  Widget _buildCard(WishlistItem item) {
    final hasImage = item.images.isNotEmpty;
    final imageUrl = hasImage
        ? '$_wishlistBaseUrl/uploads/products/${item.images[0]}'
        : null;
    final isRemoving = _removingIds.contains(item.wishlistId);

    return GestureDetector(
      onTap: () async {
        final updatedWishlist = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: item.productId,
              heroImageUrl: imageUrl,
            ),
          ),
        );
        if (updatedWishlist == false && mounted) {
          setState(
              () => _items.removeWhere((i) => i.wishlistId == item.wishlistId));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kBrand.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Product image ───────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: Container(
                width: 110,
                height: 120,
                color: const Color(0xFFEEEFFD),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported,
                              color: kBrand, size: 30),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kBrand),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.shopping_bag,
                            size: 40, color: kBrand),
                      ),
              ),
            ),

            // ── Info ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.brand.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          color: kBrand,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937)),
                        ),
                        if (item.rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 12, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Remove button ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: isRemoving ? null : () => _removeFromWishlist(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isRemoving
                        ? const Color(0xFFFFF0F0)
                        : Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: isRemoving
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red.shade400),
                        )
                      : Icon(Icons.favorite,
                          size: 18, color: Colors.red.shade400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}