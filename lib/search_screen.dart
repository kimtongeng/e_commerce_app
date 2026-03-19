import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'product_detail_screen.dart';

const String _searchBaseUrl = "http://10.0.2.2:3000";
const Color kBrand = Color.fromARGB(255, 98, 113, 241);

// ─── Search Result Model ──────────────────────────────────────────────────────

class SearchProduct {
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

  SearchProduct({
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

  factory SearchProduct.fromJson(Map<String, dynamic> json) {
    return SearchProduct(
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

// ─── Search Screen ────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  List<SearchProduct> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _total = 0;
  String _sortBy = 'Relevance';

  // Active filters
  final List<String> _activeFilters = [];

  final List<String> _sortOptions = [
    'Relevance',
    'Price: Low to High',
    'Price: High to Low',
    'Newest',
    'Top Rated',
  ];

  final Set<String> _wishlistLoading = {};

  // Recent searches (in-memory)
  final List<String> _recentSearches = [
    'Sneakers',
    'Running shoes',
    'Nike',
    'Leather jacket',
  ];

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": AuthSession.instance.bearerToken,
      };

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _search(widget.initialQuery);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Search API ──────────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _total = 0;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) return;
    setState(() => _isLoading = true);

    if (!_recentSearches.contains(keyword)) {
      setState(() {
        _recentSearches.insert(0, keyword);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }

    try {
      final uid = AuthSession.instance.userId;
      final uri = Uri.parse(
          "$_searchBaseUrl/products/search?keyword=${Uri.encodeComponent(keyword)}&userId=$uid");
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List<dynamic>? ?? [])
            .map((e) => SearchProduct.fromJson(e))
            .toList();

        _sortResults(results);

        setState(() {
          _results = results;
          _total = data['total'] ?? results.length;
          _hasSearched = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasSearched = true;
      });
    }
  }

  void _sortResults(List<SearchProduct> results) {
    switch (_sortBy) {
      case 'Price: Low to High':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Top Rated':
        results.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        break;
    }
  }

  void _applySortAndRefresh(String sort) {
    setState(() => _sortBy = sort);
    final sorted = List<SearchProduct>.from(_results);
    _sortResults(sorted);
    setState(() => _results = sorted);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort By',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            ..._sortOptions.map((option) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option,
                      style: TextStyle(
                          fontSize: 14,
                          color: _sortBy == option
                              ? kBrand
                              : const Color(0xFF374151),
                          fontWeight: _sortBy == option
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  trailing: _sortBy == option
                      ? const Icon(Icons.check, color: kBrand, size: 18)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _applySortAndRefresh(option);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Toggle wishlist ──────────────────────────────────────────────────────
  Future<void> _toggleWishlist(SearchProduct product) async {
    if (_wishlistLoading.contains(product.id)) return;
    setState(() => _wishlistLoading.add(product.id));
    try {
      final uid = AuthSession.instance.userId;
      http.Response response;
      if (product.isWishlist) {
        final url = Uri.parse('$_searchBaseUrl/wishlist/$uid/${product.id}');
        response = await http.delete(url, headers: _headers);
      } else {
        final url = Uri.parse('$_searchBaseUrl/wishlist');
        response = await http.post(
          url,
          headers: _headers,
          body: jsonEncode({'userId': uid, 'productId': product.id}),
        );
      }
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(() => product.isWishlist = !product.isWishlist);
      } else {
        _showSnack('Failed to update wishlist (${response.statusCode})');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _wishlistLoading.remove(product.id));
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_activeFilters.isNotEmpty) _buildFilterChips(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kBrand))
                  : !_hasSearched
                      ? _buildEmptyState()
                      : _results.isEmpty
                          ? _buildNoResults()
                          : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
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
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFFD),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kBrand, width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: kBrand, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) => _search(v.trim()),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(
                        hintText: 'Search for brands or items...',
                        hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _results = [];
                          _hasSearched = false;
                          _total = 0;
                        });
                        _focusNode.requestFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.cancel,
                            color: Color(0xFF9CA3AF), size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kBrand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _activeFilters.map((filter) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFFD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBrand.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filter,
                      style: const TextStyle(
                          fontSize: 12,
                          color: kBrand,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _activeFilters.remove(filter)),
                    child: const Icon(Icons.close, size: 14, color: kBrand),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Empty / Initial State ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Searches',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                GestureDetector(
                  onTap: () => setState(() => _recentSearches.clear()),
                  child: const Text('Clear all',
                      style: TextStyle(
                          fontSize: 12,
                          color: kBrand,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((s) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = s;
                    _search(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history,
                            size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Text(s,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF374151))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 28),

          const Text('Popular Categories',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: [
              _categoryChip('Shoes', Icons.directions_walk),
              _categoryChip('Clothing', Icons.checkroom),
              _categoryChip('Accessories', Icons.watch),
              _categoryChip('Electronics', Icons.devices),
              _categoryChip('Sports', Icons.sports),
              _categoryChip('Home', Icons.weekend),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _search(label);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFFD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: kBrand),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }

  // ─── No Results ───────────────────────────────────────────────────────────
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: kBrand.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No results for "${_searchController.text}"',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try different keywords or check your spelling',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Results ──────────────────────────────────────────────────────────────
  Widget _buildResults() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_total Results',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                  Text(
                    'Found in "${_searchController.text}"',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEFFD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBrand.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 14, color: kBrand),
                      const SizedBox(width: 4),
                      Text(
                        'Sort: $_sortBy',
                        style: const TextStyle(
                            fontSize: 12,
                            color: kBrand,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 14, color: kBrand),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _results.length,
              itemBuilder: (_, i) => _buildProductCard(_results[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Product Card ─────────────────────────────────────────────────────────
  Widget _buildProductCard(SearchProduct product) {
    final hasImage = product.images.isNotEmpty;
    final imageUrl = hasImage
        ? "$_searchBaseUrl/uploads/products/${product.images[0]}"
        : null;

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
              color: kBrand.withOpacity(0.07),
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
                  height: 150,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEFFD),
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
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: kBrand, size: 36),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kBrand),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.shopping_bag,
                              size: 50, color: kBrand),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleWishlist(product),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: _wishlistLoading.contains(product.id)
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kBrand),
                            )
                          : Icon(
                              product.isWishlist
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
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
                  Text(
                    product.brand.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        color: kBrand,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
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
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}