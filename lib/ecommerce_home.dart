import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';
import 'wishlist_screen.dart';
import 'cart_screen.dart';
import 'account_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

// ─── Config ───────────────────────────────────────────────────────────────────
const String baseUrl = "http://10.0.2.2:3000";
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const ShopApp());
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class HomeData {
  final BannerData banner;
  final List<Category> categories;
  final List<dynamic> flashSale;

  HomeData({
    required this.banner,
    required this.categories,
    required this.flashSale,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      banner: BannerData.fromJson(json['banner'] ?? {}),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => Category.fromJson(e))
          .toList(),
      flashSale: json['flashSale'] ?? [],
    );
  }
}

class BannerData {
  final String title;
  final String buttonText;

  BannerData({required this.title, required this.buttonText});

  factory BannerData.fromJson(Map<String, dynamic> json) {
    return BannerData(
      title: json['title'] ?? 'New Collection',
      buttonText: json['buttonText'] ?? 'Shop Now',
    );
  }
}

class Category {
  final String id;
  final String name;
  final String image;
  final String description;

  Category({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<dynamic> images;
  final String category;
  final String brand;
  final int stock;
  final double rating;
  bool isWishlist;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.brand,
    required this.stock,
    required this.rating,
    required this.isWishlist,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: json['image'] ?? [],
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      stock: json['stock'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      isWishlist: json['isWishlist'] ?? false,
    );
  }
}

// ─── Category Icon Mapper ─────────────────────────────────────────────────────

IconData _iconForCategory(String name) {
  switch (name.toLowerCase()) {
    case 'shoes':
    case 'shoses':
      return Icons.directions_walk;
    case 'clothing':
    case 'fashion':
      return Icons.checkroom;
    case 'accessories':
      return Icons.watch;
    case 'home':
      return Icons.weekend;
    case 'electronics':
    case 'devices':
      return Icons.devices;
    case 'sports':
      return Icons.sports;
    default:
      return Icons.category;
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── app_links replaces uni_links ──────────────────────────────────────────
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;

  int _selectedIndex = 0;
  HomeData? _homeData;
  List<Product> _products = [];
  bool _isLoading = true;
  int _cartCount = 0;
  String? _error;
  String? _selectedCategoryName;

  final Set<String> _wishlistLoading = {};

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _listenDeepLinks();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.wait([_fetchHomeData(), _fetchProducts(), _fetchCartCount()]);
    setState(() => _isLoading = false);
  }

  // ── app_links API ─────────────────────────────────────────────────────────
  void _listenDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri),
      onError: (_) {}, // silently ignore errors
    );
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.host == "paypal-success") {
      final token = uri.queryParameters["token"];
      if (token != null) {
        await http.get(
          Uri.parse("$baseUrl/paypal/capture?token=$token"),
          headers: _headers,
        );
        if (!mounted) return;
        Navigator.pushNamed(context, "/payment-success");
      }
    } else if (uri.host == "paypal-cancel") {
      if (!mounted) return;
      Navigator.pushNamed(context, "/payment-cancel");
    }
  }

  Future<void> _fetchHomeData() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/home"),
        headers: _headers,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _homeData = HomeData.fromJson(jsonDecode(response.body));
        _selectedCategoryName = null;
      } else {
        _error = "Failed to load home (${response.statusCode})";
      }
    } catch (e) {
      _error = "Connection error: $e";
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/products?userId=$_uid"),
        headers: _headers,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        _products = data.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchCartCount() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/cart/$_uid"),
        headers: _headers,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        final count =
            items.fold<int>(0, (sum, i) => sum + ((i['quantity'] ?? 1) as int));
        _cartCount = count;
      }
    } catch (_) {}
  }

  // ─── Toggle wishlist ──────────────────────────────────────────────────────
  Future<void> _toggleWishlist(Product product) async {
    if (_wishlistLoading.contains(product.id)) return;

    setState(() => _wishlistLoading.add(product.id));

    try {
      http.Response response;

      if (product.isWishlist) {
        response = await http.delete(
          Uri.parse("$baseUrl/wishlist/$_uid/${product.id}"),
          headers: _headers,
        );
      } else {
        response = await http.post(
          Uri.parse("$baseUrl/wishlist"),
          headers: _headers,
          body: jsonEncode({"userId": _uid, "productId": product.id}),
        );
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(() => product.isWishlist = !product.isWishlist);
      } else {
        _showSnack("Failed to update wishlist (${response.statusCode})");
      }
    } catch (e) {
      _showSnack("Connection error");
    } finally {
      setState(() => _wishlistLoading.remove(product.id));
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  List<Product> get _filteredProducts {
    if (_selectedCategoryName == null) return _products;
    return _products
        .where((p) =>
            p.category.toLowerCase() == _selectedCategoryName!.toLowerCase())
        .toList();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.indigo))
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _fetchAll,
                    color: Colors.indigo,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          _buildHeroBanner(),
                          const SizedBox(height: 20),
                          _buildCategories(),
                          const SizedBox(height: 20),
                          if (_homeData != null &&
                              _homeData!.flashSale.isNotEmpty) ...[
                            _buildFlashSaleHeader(),
                            const SizedBox(height: 20),
                          ],
                          _buildRecommended(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.indigo),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchAll,
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

  // ─── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.indigo, width: 1.5),
          ),
          child: const Row(
            children: [
              SizedBox(width: 12),
              Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search for brands or items...',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero Banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    final banner = _homeData?.banner;
    final title = banner?.title ?? 'New Collection';
    final buttonText = banner?.buttonText ?? 'Shop Now';

    final parts = title.split(' ');
    final line1 = parts.length > 1
        ? parts.sublist(0, parts.length ~/ 2).join(' ')
        : title;
    final line2 =
        parts.length > 1 ? parts.sublist(parts.length ~/ 2).join(' ') : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Container(
                width: 140,
                color: const Color(0xFF283593),
                child: const Icon(Icons.person,
                    size: 100, color: Color(0xFF5C6BC0)),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'NEW SEASON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  line2.isNotEmpty ? '$line1\n$line2' : line1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(buttonText,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Categories ────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    final categories = _homeData?.categories ?? [];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              GestureDetector(
                onTap: () => setState(() => _selectedCategoryName = null),
                child: const Text('View All',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          categories.isEmpty
              ? const Text('No categories available',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final imageUrl = cat.image.isNotEmpty
                          ? "$baseUrl/uploads/categories/${cat.image}"
                          : null;
                      final isSelected = _selectedCategoryName == cat.name;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategoryName =
                            isSelected ? null : cat.name),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.indigo
                                      : const Color(0xFFE8EAF6),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo
                                          .withOpacity(isSelected ? 0.3 : 0.08),
                                      blurRadius: isSelected ? 10 : 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.indigo, width: 2)
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: imageUrl != null
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            color: isSelected
                                                ? Colors.white
                                                : null,
                                            colorBlendMode: isSelected
                                                ? BlendMode.srcIn
                                                : null,
                                            errorBuilder: (_, __, ___) => Icon(
                                              _iconForCategory(cat.name),
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.indigo,
                                              size: 28,
                                            ),
                                            loadingBuilder:
                                                (_, child, progress) {
                                              if (progress == null)
                                                return child;
                                              return const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.indigo,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Icon(
                                            _iconForCategory(cat.name),
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.indigo,
                                            size: 28,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.indigo
                                      : const Color(0xFF374151),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  // ─── Flash Sale ────────────────────────────────────────────────────────────
  Widget _buildFlashSaleHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Flash Sale',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(width: 8),
          _buildTimerBadge('00'),
          const SizedBox(width: 4),
          _buildTimerBadge('45'),
          const SizedBox(width: 4),
          _buildTimerBadge('12'),
          const Spacer(),
          const Icon(Icons.arrow_forward, color: Colors.indigo, size: 20),
        ],
      ),
    );
  }

  Widget _buildTimerBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.indigo, borderRadius: BorderRadius.circular(4)),
      child: Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Recommended ───────────────────────────────────────────────────────────
  Widget _buildRecommended() {
    final products = _filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _selectedCategoryName ?? 'Recommended for You',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              if (_selectedCategoryName != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryName = null),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.close, size: 12, color: Colors.indigo),
                        SizedBox(width: 3),
                        Text('Clear',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.indigo,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        products.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off,
                          size: 48, color: Color(0xFF9CA3AF)),
                      const SizedBox(height: 8),
                      Text(
                        _selectedCategoryName != null
                            ? 'No products in "$_selectedCategoryName"'
                            : 'No products available',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _buildProductCard(products[index]),
                ),
              ),
      ],
    );
  }

  // ─── Product Card ──────────────────────────────────────────────────────────
  Widget _buildProductCard(Product product) {
    final hasImage = product.images.isNotEmpty;
    final imageUrl =
        hasImage ? "$baseUrl/uploads/products/${product.images[0]}" : null;
    final isWishlistLoading = _wishlistLoading.contains(product.id);

    return GestureDetector(
      onTap: () async {
        final updatedWishlist = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: product.id,
              heroImageUrl: imageUrl,
            ),
          ),
        );
        if (updatedWishlist != null && mounted) {
          setState(() => product.isWishlist = updatedWishlist);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EAF6),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.indigo, size: 40),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.indigo),
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.shopping_bag,
                              size: 60, color: Colors.indigo),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleWishlist(product),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isWishlistLoading
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.indigo),
                            )
                          : Icon(
                              product.isWishlist
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: product.isWishlist
                                  ? Colors.red
                                  : const Color(0xFF9CA3AF),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.brand,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 2),
                  Text(
                    product.title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFF59E0B), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        product.rating > 0
                            ? product.rating.toStringAsFixed(1)
                            : 'New',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937)),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_cart,
                            color: Colors.white, size: 15),
                      ),
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

  // ─── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const navItems = [
      {'label': 'Home'},
      {'label': 'Search'},
      {'label': 'Cart'},
      {'label': 'Wishlist'},
      {'label': 'Profile'},
    ];

    IconData navIcon(int index, bool isSelected) {
      switch (index) {
        case 0:
          return isSelected ? Icons.home : Icons.home_outlined;
        case 1:
          return Icons.search;
        case 2:
          return Icons.shopping_cart;
        case 3:
          return isSelected ? Icons.favorite : Icons.favorite_border;
        case 4:
          return isSelected ? Icons.person : Icons.person_outline;
        default:
          return Icons.circle;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () async {
                  if (index == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  } else if (index == 2) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                    if (mounted) await _fetchCartCount();
                    if (mounted) setState(() {});
                  } else if (index == 3) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WishlistScreen()),
                    );
                    if (mounted) await _fetchProducts();
                    if (mounted) setState(() {});
                  } else if (index == 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                  } else {
                    setState(() => _selectedIndex = index);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          navIcon(index, isSelected),
                          color: isSelected
                              ? Colors.indigo
                              : const Color(0xFF9CA3AF),
                          size: 24,
                        ),
                        // ── Cart badge ─────────────────────────────────
                        if (index == 2 && _cartCount > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                _cartCount > 99 ? '99+' : '$_cartCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      navItems[index]['label']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.indigo
                            : const Color(0xFF9CA3AF),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
