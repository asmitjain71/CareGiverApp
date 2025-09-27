import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  void _fetchInventory() async {
    _inventoryRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> inventoryMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<MedicationInventory> tempInventory = [];
        inventoryMap.forEach((key, value) {
          tempInventory.add(MedicationInventory.fromMap(
              Map<String, dynamic>.from(value), key));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory Management')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final item = _inventory[index];
                final isLowStock = item.quantity < 10;
                final isExpiringSoon =
                    item.expiryDate.difference(DateTime.now()).inDays < 7;
                return Card(
                  color: isLowStock || isExpiringSoon ? Colors.red[100] : null,
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      'Qty: ${item.quantity} | Expiry: ${item.expiryDate.toLocal().toString().split(' ')[0]}\n${item.description}', // Added
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLowStock || isExpiringSoon)
                          Icon(Icons.warning, color: Colors.red),
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () => _reconcileStock(item),
                          tooltip: 'Reconcile Stock',
                        ),
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editMedication(item),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteMedication(item),
                          tooltip: 'Delete',
                        ),
                        IconButton(
                          icon: Icon(Icons.shopping_cart),
                          onPressed: () => _generateReorder(item),
                          tooltip: 'Reorder',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedication,
        child: Icon(Icons.add),
        tooltip: 'Add Medication',
      ),
    );
  }
}
