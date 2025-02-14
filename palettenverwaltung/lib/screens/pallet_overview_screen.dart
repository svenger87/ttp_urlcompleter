import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:palettenverwaltung/models/customer.dart';
import '../services/api_service.dart';
import '../models/overview.dart';
import '../models/palette_type.dart';
import '../models/customer_inventory_item.dart';
import '../screens/booking_screen.dart';
import '../screens/customer_inventory_selector_screen.dart';
import '../screens/palette_type_inventory_selector_screen.dart';

class PalletOverviewScreen extends StatefulWidget {
  const PalletOverviewScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PalletOverviewScreenState createState() => _PalletOverviewScreenState();
}

class _PalletOverviewScreenState extends State<PalletOverviewScreen> {
  final ApiService _apiService = ApiService();
  late Future<Overview> _futureOverview;
  List<PaletteType> _allPaletteTypes = [];
  List<Customer> _allCustomers = [];

  Customer? _selectedCustomerDetail;
  List<CustomerInventoryItem>? _selectedCustomerInventory;

  // Drill-down state for each card:
  PaletteType? _selectedGlobalDetail;
  int? _availableGlobal;

  PaletteType? _selectedOnSiteDetail;
  int? _availableOnSite;

  @override
  void initState() {
    super.initState();
    _futureOverview = _apiService.fetchOverview();
    _apiService.fetchPaletteTypes().then((types) {
      setState(() {
        _allPaletteTypes = types;
      });
    });
    _apiService.fetchCustomers().then((customers) {
      setState(() {
        _allCustomers = customers;
      });
    });
  }

  void _goToCustomerDetails() async {
    final customers = await _apiService.fetchCustomers();
    Navigator.push(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(
        builder: (context) => CustomerInventorySelectorScreen(
          apiService: _apiService,
          customers: customers,
        ),
      ),
    );
  }

  void _goToPaletteTypeDetails() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteTypeInventorySelectorScreen(
          apiService: _apiService,
          paletteTypes: _allPaletteTypes,
        ),
      ),
    );
  }

  void _goToBookingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(apiService: _apiService),
      ),
    );
  }

  // Drill-down for Gesamtpaletten:
  Future<void> _selectGlobalDetail() async {
    PaletteType? selected = await showDialog<PaletteType>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Gesamtpaletten – Typ auswählen"),
          content: SizedBox(
            width: double.maxFinite,
            child: TypeAheadField<PaletteType>(
              suggestionsCallback: (pattern) async {
                return _allPaletteTypes
                    .where((pt) =>
                        pt.globalInventory > 0 &&
                        pt.bezeichnung
                            .toLowerCase()
                            .contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, PaletteType suggestion) {
                return ListTile(
                  title: Text(suggestion.bezeichnung),
                  subtitle: Text("Global: ${suggestion.globalInventory}"),
                );
              },
              onSelected: (PaletteType suggestion) {
                Navigator.pop(context, suggestion);
              },
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Typ eingeben",
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Abbrechen"),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      int avail = await _apiService.fetchPaletteTypeAvailability(selected.id!);
      setState(() {
        _selectedGlobalDetail = selected;
        _availableGlobal = avail;
      });
    }
  }

  // Drill-down for Vor Ort:
  Future<void> _selectOnSiteDetail() async {
    PaletteType? selected = await showDialog<PaletteType>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Vor Ort – Typ auswählen"),
          content: SizedBox(
            width: double.maxFinite,
            child: TypeAheadField<PaletteType>(
              suggestionsCallback: (pattern) async {
                return _allPaletteTypes.where((pt) {
                  final available = pt.globalInventory - pt.bookedQuantity;
                  return available > 0 &&
                      pt.bezeichnung
                          .toLowerCase()
                          .contains(pattern.toLowerCase());
                }).toList();
              },
              itemBuilder: (context, PaletteType suggestion) {
                final available =
                    suggestion.globalInventory - suggestion.bookedQuantity;
                return ListTile(
                  title: Text(suggestion.bezeichnung),
                  subtitle: Text("Vor Ort: $available"),
                );
              },
              onSelected: (PaletteType suggestion) {
                Navigator.pop(context, suggestion);
              },
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Typ eingeben",
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Abbrechen"),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      int avail = await _apiService.fetchPaletteTypeAvailability(selected.id!);
      setState(() {
        _selectedOnSiteDetail = selected;
        _availableOnSite = avail;
      });
    }
  }

// Drill-down for Beim Kunden:
  Future<void> _selectWithCustomerDetail() async {
    Customer? selectedCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Beim Kunden – Kunde auswählen"),
          content: SizedBox(
            width: double.maxFinite,
            child: TypeAheadField<Customer>(
              debounceDuration: const Duration(milliseconds: 300),
              suggestionsCallback: (pattern) async {
                return _allCustomers
                    .where((customer) => customer.name
                        .toLowerCase()
                        .contains(pattern.toLowerCase()))
                    .toList();
              },
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Kunde eingeben",
                  ),
                );
              },
              itemBuilder: (context, Customer suggestion) {
                return ListTile(
                  title: Text(suggestion.name),
                );
              },
              onSelected: (Customer suggestion) {
                Navigator.pop(context, suggestion);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Abbrechen"),
            ),
          ],
        );
      },
    );

    if (selectedCustomer != null) {
      final inventory =
          await _apiService.fetchCustomerInventory(selectedCustomer.id!);

      setState(() {
        _selectedCustomerDetail = selectedCustomer;
        _selectedCustomerInventory = inventory;
      });
    }
  }

  Widget _buildSummaryCard(String title, String value,
      {VoidCallback? onTap, Widget? extraContent}) {
    final content = Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (extraContent != null) ...[
          const SizedBox(height: 8),
          extraContent,
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Overview>(
      future: _futureOverview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }
        final overview = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gesamtpaletten card:
                  _buildSummaryCard(
                    "Gesamtpaletten",
                    overview.totalPalettes.toString(),
                    onTap: _selectGlobalDetail,
                    extraContent: _selectedGlobalDetail != null &&
                            _availableGlobal != null
                        ? Text(
                            "Typ: ${_selectedGlobalDetail!.bezeichnung}\n"
                            "Global: ${_selectedGlobalDetail!.globalInventory}\n"
                            "Buchungen: ${_selectedGlobalDetail!.bookedQuantity}\n"
                            "Verfügbar: ${_availableGlobal!}",
                            textAlign: TextAlign.center,
                          )
                        : const Text("Tippen zum Drill-Down",
                            textAlign: TextAlign.center),
                  ),
                  // Vor Ort card:
                  _buildSummaryCard(
                    "Vor Ort",
                    overview.onSite.toString(),
                    onTap: _selectOnSiteDetail,
                    extraContent: _selectedOnSiteDetail != null &&
                            _availableOnSite != null
                        ? Text(
                            "Typ: ${_selectedOnSiteDetail!.bezeichnung}\nVor Ort: ${_availableOnSite!}",
                            textAlign: TextAlign.center,
                          )
                        : const Text("Tippen zum Drill-Down",
                            textAlign: TextAlign.center),
                  ),
                  // Beim Kunden card:
                  _buildSummaryCard(
                    "Beim Kunden",
                    overview.withCustomer.toString(),
                    onTap: _selectWithCustomerDetail,
                    extraContent: _selectedCustomerDetail != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Kunde: ${_selectedCustomerDetail!.name}"),
                              if (_selectedCustomerInventory != null &&
                                  _selectedCustomerInventory!.isNotEmpty)
                                ..._selectedCustomerInventory!.map((item) => Text(
                                    "${item.paletteTypeName}: ${item.totalQuantity}"))
                              else
                                const Text("Keine Paletten für diesen Kunden."),
                            ],
                          )
                        : const Text("Tippen zum Drill-Down",
                            textAlign: TextAlign.center),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chart placeholder
              Text("Palettenverteilung",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4)
                  ],
                ),
                child: const Center(child: Text("Diagramm-Platzhalter")),
              ),
              const SizedBox(height: 16),
              // Navigation ListTiles for in-depth views
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Kundenübersicht"),
                trailing: const Icon(Icons.arrow_forward),
                onTap: _goToCustomerDetails,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text("Paletten-Typen Übersicht"),
                trailing: const Icon(Icons.arrow_forward),
                onTap: _goToPaletteTypeDetails,
              ),
              const SizedBox(height: 16),
              // Booking Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: _goToBookingScreen,
                  icon: const Icon(Icons.assignment),
                  label: const Text("Paletten buchen"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
