import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/overview.dart';
import '../models/palette_type.dart';
import '../screens/booking_screen.dart';
import '../screens/customer_inventory_selector_screen.dart';
import '../screens/palette_type_inventory_selector_screen.dart';

class PalletOverviewScreen extends StatefulWidget {
  const PalletOverviewScreen({super.key});

  @override
  _PalletOverviewScreenState createState() => _PalletOverviewScreenState();
}

class _PalletOverviewScreenState extends State<PalletOverviewScreen> {
  final ApiService _apiService = ApiService();
  late Future<Overview> _futureOverview;

  // Drill-down state for each card:
  PaletteType? _selectedGlobalDetail;
  int? _availableGlobal; // from fetchPaletteTypeAvailability

  PaletteType? _selectedOnSiteDetail;
  int? _availableOnSite;

  PaletteType? _selectedWithCustomerDetail;
  int? _bookedForSelected;

  @override
  void initState() {
    super.initState();
    _futureOverview = _apiService.fetchOverview();
  }

  void _goToCustomerDetails() async {
    final customers = await _apiService.fetchCustomers();
    Navigator.push(
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
    final paletteTypes = await _apiService.fetchPaletteTypes();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteTypeInventorySelectorScreen(
          apiService: _apiService,
          paletteTypes: paletteTypes,
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
    final paletteTypes = await _apiService.fetchPaletteTypes();
    PaletteType? tempSelected;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Gesamtpaletten - Typ auswählen"),
            content: DropdownButton<PaletteType>(
              isExpanded: true,
              value: tempSelected,
              items: paletteTypes.map((pt) {
                return DropdownMenuItem<PaletteType>(
                  value: pt,
                  child: Text(pt.bezeichnung),
                );
              }).toList(),
              hint: const Text("Typ auswählen"),
              onChanged: (pt) {
                setStateDialog(() {
                  tempSelected = pt;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Abbrechen"),
              ),
              TextButton(
                onPressed: () async {
                  if (tempSelected != null) {
                    int avail = await _apiService
                        .fetchPaletteTypeAvailability(tempSelected!.id!);
                    setState(() {
                      _selectedGlobalDetail = tempSelected;
                      _availableGlobal = avail;
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Auswählen"),
              ),
            ],
          );
        });
      },
    );
  }

  // Drill-down for Vor Ort:
  Future<void> _selectOnSiteDetail() async {
    final paletteTypes = await _apiService.fetchPaletteTypes();
    PaletteType? tempSelected;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Vor Ort - Typ auswählen"),
            content: DropdownButton<PaletteType>(
              isExpanded: true,
              value: tempSelected,
              items: paletteTypes.map((pt) {
                return DropdownMenuItem<PaletteType>(
                  value: pt,
                  child: Text(pt.bezeichnung),
                );
              }).toList(),
              hint: const Text("Typ auswählen"),
              onChanged: (pt) {
                setStateDialog(() {
                  tempSelected = pt;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Abbrechen"),
              ),
              TextButton(
                onPressed: () async {
                  if (tempSelected != null) {
                    int avail = await _apiService
                        .fetchPaletteTypeAvailability(tempSelected!.id!);
                    setState(() {
                      _selectedOnSiteDetail = tempSelected;
                      _availableOnSite = avail;
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Auswählen"),
              ),
            ],
          );
        });
      },
    );
  }

  // Drill-down for Beim Kunden:
  Future<void> _selectWithCustomerDetail() async {
    final paletteTypes = await _apiService.fetchPaletteTypes();
    PaletteType? tempSelected;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Beim Kunden - Typ auswählen"),
            content: DropdownButton<PaletteType>(
              isExpanded: true,
              value: tempSelected,
              items: paletteTypes.map((pt) {
                return DropdownMenuItem<PaletteType>(
                  value: pt,
                  child: Text(pt.bezeichnung),
                );
              }).toList(),
              hint: const Text("Typ auswählen"),
              onChanged: (pt) {
                setStateDialog(() {
                  tempSelected = pt;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Abbrechen"),
              ),
              TextButton(
                onPressed: () {
                  if (tempSelected != null) {
                    // Here, we assume that the booked_quantity is available in the PaletteType object.
                    setState(() {
                      _selectedWithCustomerDetail = tempSelected;
                      _bookedForSelected = tempSelected?.bookedQuantity;
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Auswählen"),
              ),
            ],
          );
        });
      },
    );
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
                            "Typ: ${_selectedGlobalDetail!.bezeichnung}\nGlobal: ${_selectedGlobalDetail!.globalInventory}\nBuchungen: ${_selectedGlobalDetail!.bookedQuantity}\nVerfügbar: ${_availableGlobal!}",
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
                    extraContent: _selectedWithCustomerDetail != null &&
                            _bookedForSelected != null
                        ? Text(
                            "Typ: ${_selectedWithCustomerDetail!.bezeichnung}\nBeim Kunden: ${_bookedForSelected!}",
                            textAlign: TextAlign.center,
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
