import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';

const String _addrBaseUrl = 'http://10.0.2.2:3000';

// ─── Model ────────────────────────────────────────────────────────────────────

class Address {
  final String id;
  String name;
  String phone;
  String street;
  String city;
  String country;
  String zipCode;
  bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.street,
    required this.city,
    required this.country,
    required this.zipCode,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        street: json['street'] ?? '',
        city: json['city'] ?? '',
        country: json['country'] ?? '',
        zipCode: json['zipCode'] ?? '',
        isDefault: json['isDefault'] ?? false,
      );
}

// ─── Addresses Screen ─────────────────────────────────────────────────────────

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Address> _addresses = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _deletingIds = {};

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

  Future<void> _fetchAddresses() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_addrBaseUrl/addresses/$_uid'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _addresses = data.map((e) => Address.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed to load (${res.statusCode})'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  Future<void> _deleteAddress(Address addr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Remove this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deletingIds.add(addr.id));
    try {
      final res = await http.delete(
        Uri.parse('$_addrBaseUrl/addresses/${addr.id}'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        setState(() => _addresses.removeWhere((a) => a.id == addr.id));
        _showSnack('Address deleted');
      } else {
        _showSnack('Failed to delete (${res.statusCode})');
      }
    } catch (_) { _showSnack('Connection error'); }
    setState(() => _deletingIds.remove(addr.id));
  }

  void _showAddressForm({Address? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(
        editing: editing,
        uid: _uid,
        headers: _headers,
        onSaved: _fetchAddresses,
      ),
    );
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
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Shipping Addresses',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937))),
                  ),
                  GestureDetector(
                    onTap: () => _showAddressForm(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                  : _error != null
                      ? _buildError()
                      : _addresses.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchAddresses,
                              color: Colors.indigo,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _addresses.length,
                                itemBuilder: (_, i) => _buildCard(_addresses[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off, size: 60, color: Colors.indigo),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: _fetchAddresses,
          icon: const Icon(Icons.refresh), label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 90, height: 90,
        decoration: const BoxDecoration(
            color: Color(0xFFE8EAF6), shape: BoxShape.circle),
        child: const Icon(Icons.location_off_outlined, size: 44, color: Colors.indigo),
      ),
      const SizedBox(height: 16),
      const Text('No addresses yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      const Text('Add your first shipping address',
          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
    ]),
  );

  Widget _buildCard(Address addr) {
    final isDeleting = _deletingIds.contains(addr.id);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isDeleting ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: addr.isDefault
              ? Border.all(color: Colors.indigo, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.location_on_outlined,
                        size: 18, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(addr.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937))),
                        Text(addr.phone,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  if (addr.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Default',
                          style: TextStyle(
                              fontSize: 11, color: Colors.indigo,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _addrRow(Icons.home_outlined, addr.street),
                    const SizedBox(height: 4),
                    _addrRow(Icons.location_city_outlined,
                        '${addr.city}, ${addr.country} ${addr.zipCode}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeleting
                          ? null
                          : () => _showAddressForm(editing: addr),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo,
                        side: const BorderSide(color: Colors.indigo),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeleting
                          ? null
                          : () => _deleteAddress(addr),
                      icon: isDeleting
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red))
                          : const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addrRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
    ],
  );
}

// ─── Address Form Bottom Sheet ────────────────────────────────────────────────

class _AddressFormSheet extends StatefulWidget {
  final Address? editing;
  final String uid;
  final Map<String, String> headers;
  final VoidCallback onSaved;

  const _AddressFormSheet({
    this.editing,
    required this.uid,
    required this.headers,
    required this.onSaved,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _zipCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _streetCtrl = TextEditingController(text: e?.street ?? '');
    _cityCtrl = TextEditingController(text: e?.city ?? '');
    _countryCtrl = TextEditingController(text: e?.country ?? '');
    _zipCtrl = TextEditingController(text: e?.zipCode ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _streetCtrl,
                     _cityCtrl, _countryCtrl, _zipCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final body = jsonEncode({
      'userId': widget.uid,
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'zipCode': _zipCtrl.text.trim(),
    });

    try {
      final http.Response res;
      if (widget.editing != null) {
        // PUT /addresses/:id
        res = await http.put(
          Uri.parse('$_addrBaseUrl/addresses/${widget.editing!.id}'),
          headers: widget.headers,
          body: body,
        );
      } else {
        // POST /addresses
        res = await http.post(
          Uri.parse('$_addrBaseUrl/addresses'),
          headers: widget.headers,
          body: body,
        );
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack('Failed to save (${res.statusCode})');
      }
    } catch (_) {
      _showSnack('Connection error');
    }
    setState(() => _isSaving = false);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 20),
              _field(_nameCtrl, 'Full Name', Icons.person_outline,
                  required: true),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone, required: true),
              const SizedBox(height: 12),
              _field(_streetCtrl, 'Street Address', Icons.home_outlined,
                  required: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _field(_cityCtrl, 'City',
                          Icons.location_city_outlined, required: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(_zipCtrl, 'ZIP Code',
                          Icons.local_post_office_outlined,
                          keyboardType: TextInputType.number, required: true)),
                ],
              ),
              const SizedBox(height: 12),
              _field(_countryCtrl, 'Country', Icons.public_outlined,
                  required: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEditing ? 'Update Address' : 'Save Address',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.indigo)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}