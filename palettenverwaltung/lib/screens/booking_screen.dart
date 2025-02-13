import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/palette_type.dart';
import '../models/booking.dart';
import '../models/customer_inventory_item.dart';
import '../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final ApiService apiService;

  const BookingScreen({Key? key, required this.apiService}) : super(key: key);

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();

  // Booking type: 'in' (assigning) or 'out' (removing)
  String _bookingType = 'in';

  // Data lists
  List<Customer> _customers = [];
  List<PaletteType> _allPaletteTypes = [];
  List<CustomerInventoryItem> _customerInventory = [];

  // Selections: For "in", _selectedPaletteOrInventory will be a PaletteType;
  // for "out", it will be a CustomerInventoryItem.
  dynamic _selectedPaletteOrInventory;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// Fetch all customers and all palette types.
  Future<void> _fetchInitialData() async {
    try {
      final customers = await widget.apiService.fetchCustomers();
      final paletteTypes = await widget.apiService.fetchPaletteTypes();
      setState(() {
        _customers = customers;
        _allPaletteTypes = paletteTypes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
    }
  }

  /// Update available palette/inventory list.
  Future<void> _updateAvailableList() async {
    setState(() {
      _selectedPaletteOrInventory = null;
    });
    if (_bookingType == 'in') {
      // For "in", use the full list.
      return;
    } else {
      // For "out", fetch customer's inventory.
      if (_selectedCustomer == null) return;
      try {
        final inventory = await widget.apiService
            .fetchCustomerInventory(_selectedCustomer!.id!);
        setState(() {
          _customerInventory = inventory;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden des Inventars: $e')),
        );
      }
    }
  }

  void _onBookingTypeChanged(String value) async {
    setState(() {
      _bookingType = value;
    });
    await _updateAvailableList();
  }

  void _onCustomerChanged(Customer? newCustomer) async {
    setState(() {
      _selectedCustomer = newCustomer;
    });
    if (_bookingType == 'out' && newCustomer != null) {
      await _updateAvailableList();
    }
  }

  Future<void> _submitBooking() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte wählen Sie einen Kunden aus')));
      return;
    }

    final int qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte eine positive Menge eingeben')));
      return;
    }

    int paletteTypeId;
    if (_bookingType == 'in') {
      final selectedType = _selectedPaletteOrInventory as PaletteType?;
      if (selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bitte wählen Sie einen Paletten-Typ aus')));
        return;
      }
      // Global availability check for "in" bookings.
      final available = await widget.apiService
          .fetchPaletteTypeAvailability(selectedType.id!);
      if (qty > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Global verfügbar sind nur $available Paletten dieses Typs.')),
        );
        return;
      }
      paletteTypeId = selectedType.id!;
    } else {
      final selectedItem =
          _selectedPaletteOrInventory as CustomerInventoryItem?;
      if (selectedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Bitte wählen Sie einen Paletten-Typ (Inventar) aus')));
        return;
      }
      if (qty > selectedItem.totalQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Kunde hat nur ${selectedItem.totalQuantity} verfügbar')));
        return;
      }
      paletteTypeId = selectedItem.paletteTypeId;
    }

    // For "in", booking quantity is positive; for "out", negative.
    final finalQty = (_bookingType == 'in') ? qty : -qty;
    final booking = Booking(
      customerId: _selectedCustomer!.id!,
      paletteTypeId: paletteTypeId,
      quantity: finalQty,
      bookingDate: DateTime.now(),
    );

    try {
      await widget.apiService.createBooking(booking);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Buchung erfolgreich')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler beim Buchen: $e')));
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paletten buchen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _customers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Booking type selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: 'in',
                          groupValue: _bookingType,
                          onChanged: (value) {
                            if (value != null) {
                              _onBookingTypeChanged(value);
                            }
                          },
                        ),
                        const Text('Ausbuchen'),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: 'out',
                          groupValue: _bookingType,
                          onChanged: (value) {
                            if (value != null) {
                              _onBookingTypeChanged(value);
                            }
                          },
                        ),
                        const Text('Einbuchen'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer dropdown
                    DropdownButtonFormField<Customer>(
                      decoration: const InputDecoration(labelText: 'Kunde'),
                      items: _customers.map((customer) {
                        return DropdownMenuItem<Customer>(
                          value: customer,
                          child: Text(customer.name),
                        );
                      }).toList(),
                      value: _selectedCustomer,
                      onChanged: _onCustomerChanged,
                      validator: (value) => value == null
                          ? 'Bitte wählen Sie einen Kunden'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // If booking out, display current inventory for the selected customer
                    if (_bookingType == 'out' && _selectedCustomer != null)
                      _customerInventory.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aktuelles Inventar:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                ..._customerInventory.map((inv) => Text(
                                    '${inv.paletteTypeName}: ${inv.totalQuantity}')),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                  'Für diesen Kunden sind derzeit keine Paletten vorhanden.'),
                            ),

                    // Palette type / inventory dropdown
                    if (_bookingType == 'in') ...[
                      DropdownButtonFormField<PaletteType>(
                        decoration:
                            const InputDecoration(labelText: 'Paletten-Typ'),
                        items: _allPaletteTypes.map((pt) {
                          return DropdownMenuItem<PaletteType>(
                            value: pt,
                            child: Text(pt.bezeichnung),
                          );
                        }).toList(),
                        value: _selectedPaletteOrInventory is PaletteType
                            ? _selectedPaletteOrInventory as PaletteType
                            : null,
                        onChanged: (pt) {
                          setState(() {
                            _selectedPaletteOrInventory = pt;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Bitte wählen Sie einen Paletten-Typ'
                            : null,
                      )
                    ] else ...[
                      if (_selectedCustomer != null &&
                          _customerInventory.isNotEmpty)
                        DropdownButtonFormField<CustomerInventoryItem>(
                          decoration: const InputDecoration(
                              labelText: 'Verfügbarer Paletten-Typ'),
                          items: _customerInventory.map((inv) {
                            return DropdownMenuItem<CustomerInventoryItem>(
                              value: inv,
                              child: Text(
                                  '${inv.paletteTypeName} (verfügbar: ${inv.totalQuantity})'),
                            );
                          }).toList(),
                          value: _selectedPaletteOrInventory
                                  is CustomerInventoryItem
                              ? _selectedPaletteOrInventory
                                  as CustomerInventoryItem
                              : null,
                          onChanged: (item) {
                            setState(() {
                              _selectedPaletteOrInventory = item;
                            });
                          },
                          validator: (value) => value == null
                              ? 'Bitte wählen Sie einen Paletten-Typ'
                              : null,
                        ),
                    ],
                    const SizedBox(height: 16),

                    // Quantity field
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Menge'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte eine Menge eingeben';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Ungültige Zahl';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    ElevatedButton(
                      onPressed: _submitBooking,
                      child: const Text('Buchung absenden'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
