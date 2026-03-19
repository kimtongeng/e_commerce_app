import 'package:flutter/material.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedFaqIndex;

  final List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.shopping_bag_outlined,
      'label': 'Orders',
      'color': Colors.indigo,
      'bg': Color(0xFFE8EAF6),
    },
    {
      'icon': Icons.local_shipping_outlined,
      'label': 'Shipping',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
    },
    {
      'icon': Icons.assignment_return_outlined,
      'label': 'Returns',
      'color': Colors.red,
      'bg': Color(0xFFFFEBEE),
    },
    {
      'icon': Icons.credit_card_outlined,
      'label': 'Payments',
      'color': Colors.green,
      'bg': Color(0xFFE8F5E9),
    },
    {
      'icon': Icons.account_circle_outlined,
      'label': 'Account',
      'color': Color(0xFF8B5CF6),
      'bg': Color(0xFFF3E8FF),
    },
    {
      'icon': Icons.devices_outlined,
      'label': 'App Help',
      'color': Color(0xFF0EA5E9),
      'bg': Color(0xFFE0F2FE),
    },
  ];

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I track my order?',
      'a':
          'Go to My Orders in your account, select the order you want to track, and tap "Track Order". You\'ll see real-time updates on your delivery status.',
    },
    {
      'q': 'What is your return policy?',
      'a':
          'We accept returns within 30 days of delivery. Items must be unused and in their original packaging. To start a return, go to My Orders and select "Return Item".',
    },
    {
      'q': 'How long does shipping take?',
      'a':
          'Standard shipping takes 3–7 business days. Express shipping (1–2 business days) is available at checkout for an additional fee.',
    },
    {
      'q': 'Can I change or cancel my order?',
      'a':
          'Orders can be modified or cancelled within 1 hour of placement. After that, the order is processed and changes may not be possible. Contact us immediately if you need help.',
    },
    {
      'q': 'How do I update my payment method?',
      'a':
          'Go to Account → Payment Methods to add, remove, or update your saved cards and payment options.',
    },
    {
      'q': 'I received a wrong or damaged item. What do I do?',
      'a':
          'We\'re sorry about that! Please contact us within 48 hours of delivery with a photo of the item. We\'ll arrange a replacement or full refund immediately.',
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _faqs;
    return _faqs
        .where((faq) =>
            faq['q']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            faq['a']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildCategories(),
                    const SizedBox(height: 24),
                    _buildFaqSection(),
                    const SizedBox(height: 24),
                    _buildContactSection(),
                    const SizedBox(height: 30),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(10, 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Support Center',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hi, how can we help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search for help...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFF9CA3AF), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'BROWSE BY TOPIC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              return GestureDetector(
                onTap: () => _showSnack('${cat['label']} help coming soon'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cat['bg'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat['icon'] as IconData,
                            color: cat['color'] as Color, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    final faqs = _filteredFaqs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'FREQUENTLY ASKED QUESTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (faqs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    'No results for "$_searchQuery"',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(faqs.length, (i) {
                final isExpanded = _expandedFaqIndex == i;
                final isLast = i == faqs.length - 1;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() =>
                          _expandedFaqIndex = isExpanded ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? const Color(0xFFE8EAF6)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.question_mark_rounded,
                                size: 14,
                                color: isExpanded
                                    ? Colors.indigo
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                faqs[i]['q']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isExpanded
                                      ? Colors.indigo
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        color: const Color(0xFFF9FAFB),
                        padding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
                        child: Text(
                          faqs[i]['a']!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (!isLast)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'CONTACT US',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildContactTile(
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.indigo,
                iconBg: const Color(0xFFE8EAF6),
                title: 'Live Chat',
                subtitle: 'Typically replies in a few minutes',
                onTap: () => _showSnack('Live chat coming soon'),
              ),
              const SizedBox(height: 10),
              _buildContactTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFFFBEB),
                title: 'Email Us',
                subtitle: 'support@shopapp.com',
                onTap: () => _showSnack('Email support coming soon'),
              ),
              const SizedBox(height: 10),
              _buildContactTile(
                icon: Icons.phone_outlined,
                iconColor: Colors.green,
                iconBg: const Color(0xFFE8F5E9),
                title: 'Call Us',
                subtitle: 'Mon–Fri, 9am–6pm',
                onTap: () => _showSnack('Phone support coming soon'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}