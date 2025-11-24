import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:practice/services/notification_service.dart';
import 'model/medication_inventory.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final DatabaseReference _inventoryRef =
      FirebaseDatabase.instance.ref().child('inventory');
  List<MedicationInventory> _inventory = [];
  bool _isLoading = true;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _inventorySubscription;

  @override
  void initState() {
    super.initState();
    _listenToInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inventorySubscription?.cancel();
    super.dispose();
  }

  void _listenToInventory() {
    _inventorySubscription?.cancel();
    _inventorySubscription = _inventoryRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> inventoryMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<MedicationInventory> tempInventory = [];
        inventoryMap.forEach((key, value) {
          final item = MedicationInventory.fromMap(
              Map<String, dynamic>.from(value), key);
          tempInventory.add(item);

          // Check for low stock and notify
          if (item.quantity < 10) {
            NotificationService().showNotification(
              id: item.id.hashCode,
              title: 'Low Stock Alert',
              body:
                  'The stock for ${item.name} is low (${item.quantity} left).',
            );
          }
        });
        setState(() {
          _inventory = tempInventory;
          _isLoading = false;
        });
      } else {
        setState(() {
          _inventory = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _refreshInventory() async {
    final snapshot = await _inventoryRef.get();
    if (!snapshot.exists) {
      setState(() {
        _inventory = [];
        _isLoading = false;
      });
      return;
    }
    final Map<dynamic, dynamic> inventoryMap =
        snapshot.value as Map<dynamic, dynamic>;
    final tempInventory = inventoryMap.entries
        .map((entry) => MedicationInventory.fromMap(
            Map<String, dynamic>.from(entry.value), entry.key))
        .toList();
    setState(() {
      _inventory = tempInventory;
      _isLoading = false;
    });
  }

  void _generateReorder(MedicationInventory item) {
    // Implement reorder logic here (e.g., push to 'reorders' node in Firebase)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reorder generated for ${item.name}')),
    );
  }

  void _reconcileStock(MedicationInventory item) async {
    int? newQty = await showDialog<int>(
      context: context,
      builder: (context) {
        TextEditingController controller =
            TextEditingController(text: item.quantity.toString());
        return AlertDialog(
          title: Text('Reconcile Stock for ${item.name}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'New Quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
    if (newQty != null) {
      await _inventoryRef.child(item.id).update({'quantity': newQty});
    }
  }

  void _editMedication(MedicationInventory item) async {
    TextEditingController nameController =
        TextEditingController(text: item.name);
    TextEditingController qtyController =
        TextEditingController(text: item.quantity.toString());
    TextEditingController expiryController = TextEditingController(
        text: item.expiryDate.toIso8601String().split('T')[0]);
    TextEditingController descController =
        TextEditingController(text: item.description); // Added
    bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: expiryController,
                decoration:
                    InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)'),
              ),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: 'Description'), // Added
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Save')),
          ],
        );
      },
    );
    if (saved == true) {
      await _inventoryRef.child(item.id).update({
        'name': nameController.text,
        'quantity': int.tryParse(qtyController.text) ?? item.quantity,
        'expiryDate': expiryController.text,
        'description': descController.text, // Added
      });
    }
  }

  void _deleteMedication(MedicationInventory item) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _inventoryRef.child(item.id).remove();
    }
  }

  void _addMedication() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController qtyController = TextEditingController();
    TextEditingController expiryController = TextEditingController();
    TextEditingController descController = TextEditingController(); // Added
    bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: expiryController,
                decoration:
                    InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)'),
              ),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: 'Description'), // Added
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Add')),
          ],
        );
      },
    );
    if (saved == true) {
      await _inventoryRef.push().set({
        'name': nameController.text,
        'quantity': int.tryParse(qtyController.text) ?? 0,
        'expiryDate': expiryController.text,
        'description': descController.text, // Added
      });
    }
  }

  Future<void> _importFromFile() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File import is only available on mobile/desktop.'),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isImporting = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final extension = filePath.split('.').last.toLowerCase();
      List<Map<String, dynamic>> parsedItems = [];

      if (extension == 'json') {
        final raw = await File(filePath).readAsString();
        final dynamic data = jsonDecode(raw);
        parsedItems = _extractInventoryFromDynamic(data);
      } else if (extension == 'pdf') {
        final bytes = await File(filePath).readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText();
        document.dispose();
        parsedItems = _extractInventoryFromPdf(text);
      }

      if (parsedItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recognizable inventory items in the file.'),
          ),
        );
        return;
      }

      final futures = parsedItems.map((item) => _inventoryRef.push().set(item));
      await Future.wait(futures);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${parsedItems.length} items added to inventory')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractInventoryFromDynamic(dynamic data) {
    final List<Map<String, dynamic>> items = [];
    if (data is List) {
      for (final entry in data) {
        final map = _normalizeMedicationMap(entry);
        if (map != null) items.add(map);
      }
    } else if (data is Map) {
      data.forEach((key, value) {
        final map = _normalizeMedicationMap(value);
        if (map != null) items.add(map);
      });
    }
    return items;
  }

  List<Map<String, dynamic>> _extractInventoryFromPdf(String rawText) {
    final sections = rawText.split(RegExp(r'\n\s*\n'));
    final List<Map<String, dynamic>> items = [];

    for (final section in sections) {
      final nameMatch =
          RegExp(r'(?:Name|Medication)\s*:\s*(.+)', caseSensitive: false)
              .firstMatch(section);
      final qtyMatch =
          RegExp(r'(?:Qty|Quantity)\s*:\s*(\d+)', caseSensitive: false)
              .firstMatch(section);
      final expiryMatch = RegExp(
              r'(?:Expiry|Expires|Valid Until)\s*:\s*([\d\-\/]+)',
              caseSensitive: false)
          .firstMatch(section);
      final descMatch =
          RegExp(r'(?:Notes|Description)\s*:\s*(.+)', caseSensitive: false)
              .firstMatch(section);

      final name = nameMatch?.group(1)?.trim();
      if (name == null || name.isEmpty) continue;

      items.add({
        'name': name,
        'quantity': int.tryParse(qtyMatch?.group(1) ?? '') ?? 0,
        'expiryDate': _parseDateString(expiryMatch?.group(1)),
        'description': descMatch?.group(1)?.trim() ?? '',
      });
    }

    return items;
  }

  Map<String, dynamic>? _normalizeMedicationMap(dynamic entry) {
    if (entry is! Map) return null;
    final map = Map<String, dynamic>.from(entry);

    final name = map['name'] ?? map['medication'] ?? '';
    if (name.toString().isEmpty) return null;

    final expiryRaw =
        map['expiryDate'] ?? map['expiry'] ?? map['expiresOn'] ?? '';

    return {
      'name': name.toString(),
      'quantity': int.tryParse('${map['quantity'] ?? map['qty'] ?? 0}') ?? 0,
      'expiryDate': _parseDateString(expiryRaw),
      'description':
          map['description']?.toString() ?? map['notes']?.toString() ?? '',
    };
  }

  String _parseDateString(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw) ?? DateTime.now();
    return parsed.toIso8601String();
  }

  List<MedicationInventory> get _filteredInventory {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _inventory;
    return _inventory
        .where((item) =>
            item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query))
        .toList();
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add medication manually'),
                onTap: () {
                  Navigator.pop(context);
                  _addMedication();
                },
              ),
              ListTile(
                leading: _isImporting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload),
                title: Text(_isImporting
                    ? 'Importing...'
                    : 'Import medications from file'),
                onTap: _isImporting
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _importFromFile();
                      },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh inventory',
            onPressed: _refreshInventory,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _inventory.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      await _refreshInventory();
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search medication or description',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        ..._filteredInventory.map(_buildInventoryCard),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showActionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add / Import'),
      ),
    );
  }

  Widget _buildInventoryCard(MedicationInventory item) {
    final isLowStock = item.quantity < 10;
    final isExpiringSoon =
        item.expiryDate.difference(DateTime.now()).inDays < 7;
    final warningColor =
        isLowStock || isExpiringSoon ? Colors.orangeAccent : Colors.green;
    final badgeText = isLowStock
        ? 'Low stock'
        : (isExpiringSoon ? 'Expiring soon' : 'Healthy');
    final badgeBackground = warningColor.withValues(alpha: 0.15);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  backgroundColor: badgeBackground,
                  label: Text(
                    badgeText,
                    style: TextStyle(color: warningColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'Quantity',
                    value: item.quantity.toString(),
                    icon: Icons.inventory_2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    label: 'Expiry',
                    value: item.expiryDate
                        .toLocal()
                        .toIso8601String()
                        .split('T')
                        .first,
                    icon: Icons.event,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _reconcileStock(item),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reconcile'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editMedication(item),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _generateReorder(item),
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('Reorder'),
                ),
                IconButton(
                  onPressed: () => _deleteMedication(item),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No medications in inventory',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Import from a JSON/PDF file or add medications manually to start tracking stock levels.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showActionSheet,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import inventory'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
