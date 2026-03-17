import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';

const String _baseUrl = "http://10.0.2.2:3000";

// ─── Models ──────────────────────────────────────────────────────────────────

class ProductVariant {
  final String id;
  final String sku;
  final String size;
  final String color;
  final double price;
  final List<dynamic> images;
  final int stock;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.size,
    required this.color,
    required this.price,
    required this.images,
    required this.stock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['_id'] ?? '',
      sku: json['sku'] ?? '',
      size: json['size'] ?? '',
      color: json['color'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: json['images'] ?? [],
      stock: json['stock'] ?? 0,
    );
  }
}

class ProductDetail {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<dynamic> images;
  final String category;
  final String brand;
  final int stock;
  final double rating;
  final List<ProductVariant> variants;
  bool isWishlist;

  ProductDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.brand,
    required this.stock,
    required this.rating,
    required this.variants,
    required this.isWishlist,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: json['image'] ?? [],
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      stock: json['stock'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((e) => ProductVariant.fromJson(e))
          .toList(),
      isWishlist: json['isWishlist'] ?? false,
    );
  }
}

// ─── Product Detail Screen ────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? heroImageUrl;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.heroImageUrl,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _product;
  bool _isLoading = true;
  String? _error;

  int _currentImageIndex = 0;
  String? _selectedSize;
  String? _selectedColor;
  bool _isWishlistLoading = false;
  bool _isAddingToCart = false;

  bool _descExpanded = true;
  bool _materialsExpanded = false;
  bool _shippingExpanded = false;

  // ─── Reviews state ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = false;
  bool _showAddReview = false;
  int _newRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submittingReview = false;
  String? _deletingReviewId;

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String get _uid => AuthSession.instance.userId;
  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    _fetchProduct();
    _fetchReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ─── Fetch product with userId for isWishlist status ─────────────────────
  Future<void> _fetchProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // GET /products/:id?userId=USER_ID
      final response = await http.get(
        Uri.parse("$_baseUrl/products/${widget.productId}?userId=$_uid"),
        headers: _headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final product = ProductDetail.fromJson(jsonDecode(response.body));
        setState(() {
          _product = product;
          if (product.variants.isNotEmpty) {
            _selectedSize = product.variants.first.size;
            _selectedColor = product.variants.first.color;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load product (${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  // ─── Toggle wishlist ──────────────────────────────────────────────────────
  Future<void> _toggleWishlist() async {
    if (_product == null || _isWishlistLoading) return;

    setState(() => _isWishlistLoading = true);

    try {
      http.Response response;

      if (_product!.isWishlist) {
        // DELETE /wishlist/USER_ID/PRODUCT_ID
        response = await http.delete(
          Uri.parse("$_baseUrl/wishlist/$_uid/${_product!.id}"),
          headers: _headers,
        );
      } else {
        // POST /wishlist { userId, productId }
        response = await http.post(
          Uri.parse("$_baseUrl/wishlist"),
          headers: _headers,
          body: jsonEncode({"userId": _uid, "productId": _product!.id}),
        );
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(() => _product!.isWishlist = !_product!.isWishlist);
      } else {
        _showSnack("Failed to update wishlist (${response.statusCode})");
      }
    } catch (e) {
      _showSnack("Connection error");
    } finally {
      setState(() => _isWishlistLoading = false);
    }
  }

  // ─── Fetch reviews ───────────────────────────────────────────────────────
  Future<void> _fetchReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/reviews/product/${widget.productId}"),
        headers: _headers,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _reviews = data.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (_) {}
    setState(() => _reviewsLoading = false);
  }

  // ─── Submit review ────────────────────────────────────────────────────────
  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showSnack('Please write a comment');
      return;
    }
    setState(() => _submittingReview = true);
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/reviews"),
        headers: _headers,
        body: jsonEncode({
          "userId": _uid,
          "productId": widget.productId,
          "rating": _newRating,
          "comment": comment,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        setState(() {
          _showAddReview = false;
          _newRating = 5;
        });
        _showSnack('Review submitted!');
        await _fetchReviews();
      } else {
        _showSnack('Failed to submit review (${response.statusCode})');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _submittingReview = false);
  }

  // ─── Delete review ────────────────────────────────────────────────────────
  Future<void> _deleteReview(String reviewId) async {
    setState(() => _deletingReviewId = reviewId);
    try {
      final response = await http.delete(
        Uri.parse("$_baseUrl/reviews/$reviewId"),
        headers: _headers,
      );
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(() => _reviews.removeWhere((r) => r['_id'] == reviewId));
        _showSnack('Review deleted');
      } else {
        _showSnack('Failed to delete (${response.statusCode})');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _deletingReviewId = null);
  }

  List<String> get _uniqueSizes {
    if (_product == null) return [];
    return _product!.variants.map((v) => v.size).toSet().toList();
  }

  List<String> get _uniqueColors {
    if (_product == null) return [];
    return _product!.variants.map((v) => v.color).toSet().toList();
  }

  List<String> get _allImages {
    if (_product == null) return [];
    final imgs = <String>[
      ..._product!.images.map((img) => "$_baseUrl/uploads/products/$img"),
    ];
    for (final v in _product!.variants) {
      for (final img in v.images) {
        imgs.add("$_baseUrl/uploads/products/$img");
      }
    }
    return imgs.toSet().toList();
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, _product?.isWishlist);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.indigo))
            : _error != null
                ? _buildError()
                : Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageSection(),
                            _buildProductInfo(),
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            _buildColorSelector(),
                            _buildSizeSelector(),
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            _buildExpandableSection(
                              title: 'Product Description',
                              expanded: _descExpanded,
                              onToggle: () => setState(
                                  () => _descExpanded = !_descExpanded),
                              content: _product!.description,
                            ),
                            _buildExpandableSection(
                              title: 'Materials & Care',
                              expanded: _materialsExpanded,
                              onToggle: () => setState(() =>
                                  _materialsExpanded = !_materialsExpanded),
                              content:
                                  'Made from premium full-grain cowhide leather. Clean with a damp cloth. Condition regularly with leather conditioner. Store in a cool, dry place.',
                            ),
                            _buildExpandableSection(
                              title: 'Shipping & Returns',
                              expanded: _shippingExpanded,
                              onToggle: () => setState(
                                  () => _shippingExpanded = !_shippingExpanded),
                              content:
                                  'Free standard shipping on orders over \$50. Express shipping available. Returns accepted within 30 days of purchase in original condition.',
                            ),
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            _buildReviewsSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                      _buildTopBar(),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
      ), // Scaffold
    ); // PopScope
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.indigo),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchProduct,
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

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context, _product?.isWishlist),
              ),
              const Text(
                'Product Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              _navButton(
                icon: Icons.share_outlined,
                onTap: () => _showSnack('Share coming soon'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1F2937)),
      ),
    );
  }

  // ─── Image Section ────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    final images = _allImages;
    final hasImages = images.isNotEmpty;

    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          hasImages
              ? PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => Image.network(
                    images[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 60, color: Color(0xFF9CA3AF)),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.indigo),
                      );
                    },
                  ),
                )
              : Container(
                  color: const Color(0xFFE8EAF6),
                  child: const Center(
                    child: Icon(Icons.shopping_bag,
                        size: 80, color: Colors.indigo),
                  ),
                ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImageIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentImageIndex
                          ? Colors.indigo
                          : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Product Info ─────────────────────────────────────────────────────────

  Widget _buildProductInfo() {
    final product = _product!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < product.rating.floor()
                        ? Icons.star
                        : (i < product.rating
                            ? Icons.star_half
                            : Icons.star_border),
                    size: 14,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                product.rating > 0
                    ? '${product.rating.toStringAsFixed(1)} (${product.stock * 12} Reviews)'
                    : 'No reviews yet',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Color Selector ───────────────────────────────────────────────────────

  Widget _buildColorSelector() {
    final colors = _uniqueColors;
    if (colors.isEmpty) return const SizedBox.shrink();

    final colorMap = {
      'Brown': const Color(0xFF8B4513),
      'Black': const Color(0xFF1F2937),
      'Navy': const Color(0xFF1E3A5F),
      'Blue': Colors.blue,
      'Red': Colors.red,
      'White': Colors.white,
      'Grey': Colors.grey,
      'Gray': Colors.grey,
      'Green': Colors.green,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COLOR',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            children: colors.map((color) {
              final isSelected = _selectedColor == color;
              final bgColor = colorMap[color] ?? Colors.indigo;

              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.indigo : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 6,
                            )
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: bgColor == Colors.white
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Size Selector ────────────────────────────────────────────────────────

  Widget _buildSizeSelector() {
    final sizes = _uniqueSizes;
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SELECT SIZE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1)),
              GestureDetector(
                onTap: () => _showSnack('Size guide coming soon'),
                child: const Text('Size Guide',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sizes.map((size) {
              final isSelected = _selectedSize == size;
              return GestureDetector(
                onTap: () => setState(() => _selectedSize = size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.indigo : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? Colors.indigo : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      size,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Expandable Section ───────────────────────────────────────────────────

  Widget _buildExpandableSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required String content,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937))),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              content,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }

  // ─── Reviews Section ──────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    final avgRating = _reviews.isEmpty
        ? 0.0
        : _reviews.fold<double>(0, (sum, r) => sum + (r['rating'] ?? 0)) /
            _reviews.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Reviews',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 2),
                  Text(
                    _reviews.isEmpty
                        ? 'No reviews yet'
                        : 'Based on ${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              // Average rating badge
              if (_reviews.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Add Review Toggle Button ─────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _showAddReview = !_showAddReview),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _showAddReview ? const Color(0xFFE8EAF6) : Colors.indigo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showAddReview ? Icons.close : Icons.rate_review_outlined,
                    size: 16,
                    color: _showAddReview ? Colors.indigo : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showAddReview ? 'Cancel' : 'Write a Review',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showAddReview ? Colors.indigo : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Add Review Form ──────────────────────────────────────────
          if (_showAddReview) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Star rating picker
                  const Text('Your Rating',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setState(() => _newRating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            i < _newRating ? Icons.star : Icons.star_border,
                            size: 30,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Comment input
                  const Text('Your Comment',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.indigo),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submittingReview ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submittingReview
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Review',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Reviews List ─────────────────────────────────────────────
          if (_reviewsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.indigo),
              ),
            )
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Be the first to review this product!',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
            )
          else
            ..._reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewId = review['_id'] ?? '';
    final userId = review['userId'];
    final name = userId is Map ? (userId['fullName'] ?? 'User') : 'User';
    // Check if this review belongs to current user
    final isOwner = userId is Map ? (userId['_id'] == _uid) : (userId == _uid);
    final rating = (review['rating'] ?? 0) as int;
    final comment = review['comment'] ?? '';
    final createdAt = review['createdAt'] ?? '';
    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    final isDeleting = _deletingReviewId == reviewId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937))),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 12,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              // Delete button (only for own reviews)
              if (isOwner) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isDeleting ? null : () => _deleteReview(reviewId),
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red),
                        )
                      : const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFEF4444)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(comment,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Wishlist button ──────────────────────────────────────────
          GestureDetector(
            onTap: _toggleWishlist,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_product?.isWishlist ?? false)
                    ? Colors.red.shade50
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_product?.isWishlist ?? false)
                      ? Colors.red.shade200
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: _isWishlistLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.indigo),
                    )
                  : Icon(
                      (_product?.isWishlist ?? false)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: (_product?.isWishlist ?? false)
                          ? Colors.red
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Add to Cart button ───────────────────────────────────────
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isAddingToCart
                  ? null
                  : () async {
                      if (_selectedSize == null && _uniqueSizes.isNotEmpty) {
                        _showSnack('Please select a size');
                        return;
                      }
                      setState(() => _isAddingToCart = true);
                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl/cart/add'),
                          headers: _headers,
                          body: jsonEncode({
                            'userId': _uid,
                            'productId': _product!.id,
                            'quantity': 1,
                          }),
                        );
                        if (response.statusCode == 200 ||
                            response.statusCode == 201) {
                          _showSnack('Added to cart!');
                        } else {
                          _showSnack(
                              'Failed to add to cart (${response.statusCode})');
                        }
                      } catch (_) {
                        _showSnack('Connection error');
                      }
                      setState(() => _isAddingToCart = false);
                    },
              icon: _isAddingToCart
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.shopping_cart, size: 20),
              label: Text(
                _isAddingToCart ? 'Adding...' : 'Add to Cart',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
