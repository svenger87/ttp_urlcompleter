// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  bool isUpdating = false;
  late AnimationController _controller;
  Timer? _timer; // Timer for background updates
  Timer? _weightUpdateTimer; // Timer for real-time weight updates
  Map<String, dynamic>? _fetchedData;
  List<dynamic>? _fetchedWeights; // New weight data
  bool _isPipelineVisible = true; // Flag to control pipeline animation
  late TabController _tabController; // Controller for TabBarView

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 5), // Increased duration
      vsync: this,
    );

    _fetchDataSilently(); // Initial data fetch
    _startBackgroundUpdate(); // Start the background update timer
    _startWeightUpdate(); // Start weight update for real-time data

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  // Handle tab changes to control pipeline animation
  void _handleTabChange() {
    if (_tabController.index == 1) {
      // Materialfluss tab is active
      setState(() {
        _isPipelineVisible = true;
      });
      _controller.repeat(); // Start the animation
    } else {
      // Other tab is active
      setState(() {
        _isPipelineVisible = false;
      });
      _controller.stop(); // Stop the animation
    }
  }

  // Function to silently fetch data without showing any loading indicators
  Future<void> _fetchDataSilently() async {
    try {
      final data = await fetchData();
      final weights = await fetchWeightData(); // Fetch weight data
      setState(() {
        _fetchedData = data;
        _fetchedWeights = weights; // Store the fetched weights
      });
    } catch (e) {
      // Handle error if necessary, or leave it silent for background tasks
    }
  }

  // Timer to trigger background data fetch every 60 seconds
  void _startBackgroundUpdate() {
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchDataSilently(); // Silently update data every 60 seconds
    });
  }

  // Timer to update weight data every 1 second for real-time updates
  void _startWeightUpdate() {
    _weightUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchWeightDataRealtime(); // Fetch weight data every second
    });
  }

  // Manual update cache function (preserving existing functionality)
  Future<void> _updateCache() async {
    setState(() {
      isUpdating = true;
    });

    try {
      final response = await http.post(
          Uri.parse('http://wim-solution.sip.local:5000/api/update_cache'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache update triggered.')),
        );
        await _pollCacheUpdateStatus(); // Poll cache update status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Fehler beim Trigger vom Cache update: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Trigger vom Cache update: $e')),
      );
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
  }

  // Poll cache update status (unchanged)
  Future<void> _pollCacheUpdateStatus() async {
    bool updateComplete = false;
    while (!updateComplete) {
      try {
        final response = await http.get(Uri.parse(
            'http://wim-solution.sip.local:5000/api/cache_update_status'));
        if (response.statusCode == 200) {
          final status = jsonDecode(response.body)['status'];
          if (status == "Cache update fertig.") {
            updateComplete = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cache update fertig.')),
            );
            setState(() {});
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Fehler beim prüfen vom Cache Update Status: ${response.statusCode}')),
          );
          break;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler beim prüfen vom Cache Update Status: $e')),
        );
        break;
      }
    }
  }

  // Fetch the actual station data from the API
  Future<Map<String, dynamic>> fetchData() async {
    final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:5000/api/dashboard_data'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Fetch weight data from the new API
  Future<List<dynamic>> fetchWeightData() async {
    final response = await http.get(Uri.parse(
        'http://wim-solution.sip.local:5001/api/weight_measurement')); // Adjust the port if needed
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weight data');
    }
  }

  // Fetch weight data in real-time every second
  Future<void> _fetchWeightDataRealtime() async {
    try {
      final weights = await fetchWeightData(); // Fetch weight data
      setState(() {
        _fetchedWeights = weights; // Update weight data in real-time
      });
    } catch (e) {
      // Handle errors during weight data fetch
      if (kDebugMode) {
        print("Error fetching weight data: $e");
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel(); // Cancel the background timer
    _weightUpdateTimer?.cancel(); // Cancel the real-time weight update timer
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Merge station data and weight data into a unified structure
  List<dynamic> mergeDataWithWeights() {
    if (_fetchedData == null || _fetchedWeights == null) {
      return [];
    }

    List<dynamic> stations = List.from(_fetchedData!['stations']);
    for (var station in stations) {
      String stationName = station['Station'];
      // Find corresponding weight entry
      var weightEntry = _fetchedWeights!.firstWhere(
          (entry) => entry['station'] == stationName,
          orElse: () => null);

      // Add weight and time_remaining to the station
      if (weightEntry != null) {
        station['RemainingWeight'] = weightEntry['weight'];
        station['TimeRemaining'] =
            weightEntry['time_remaining']; // Add time remaining
      } else {
        station['RemainingWeight'] = 0; // Default if no weight is found
        station['TimeRemaining'] =
            'Unknown'; // Default if no time remaining is found
      }
    }
    return stations;
  }

  // Function to zero a specific scale
  Future<void> _zeroScale(String ip) async {
    try {
      final response = await http.post(
        Uri.parse('http://wim-solution.sip.local:5050/zero-scale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ip': ip}), // Pass the specific scale's IP
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waage erfolgreich genullt.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Fehler beim Nullen der Waage: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Nullen der Waage: $e')),
      );
    }
  }

  // Function to open the zero scale dialog
  void _openZeroScaleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Waage nullen'),
          content: ScaleList(onScaleSelected: _zeroScale),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF104382),
          title: const Text(
            'Status Aufhängestationen',
            style: TextStyle(color: Colors.white),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Aufhängestationen'),
              Tab(text: 'Materialfluss'),
            ],
          ),
          actions: [
            IconButton(
              icon: isUpdating
                  ? RotationTransition(
                      turns: _controller,
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
              onPressed: isUpdating
                  ? null
                  : () async {
                      await _updateCache();
                    },
            ),
            IconButton(
              icon: const Icon(
                Icons.scale,
                color: Colors.white,
              ),
              onPressed: _openZeroScaleDialog,
              tooltip: 'Waage nullen',
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future:
              _fetchedData == null ? fetchData() : Future.value(_fetchedData),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _fetchedData == null) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Fehler: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Keine Daten verfügbar.'));
            } else {
              var stations =
                  mergeDataWithWeights(); // Merge stations with weights
              stations.sort((a, b) {
                // First, sort by whether the workplace is 'FREI'
                String workplaceA = a['Arbeitsplatz'] ?? 'FREI';
                String workplaceB = b['Arbeitsplatz'] ?? 'FREI';

                if (workplaceA == 'FREI' && workplaceB == 'FREI') {
                  // If both are 'FREI', sort by the station name
                  return (a['Station'] ?? '').compareTo(b['Station'] ?? '');
                } else if (workplaceA == 'FREI') {
                  // If only A is 'FREI', it should go after B
                  return 1;
                } else if (workplaceB == 'FREI') {
                  // If only B is 'FREI', it should go after A
                  return -1;
                } else {
                  // If neither is 'FREI', sort by the workplace (Linie)
                  return workplaceA.compareTo(workplaceB);
                }
              });
              return TabBarView(
                controller: _tabController,
                children: [
                  StationOverview(stations: stations),
                  MaterialFlowDashboard(
                    stations: stations,
                    isPipelineVisible: _isPipelineVisible,
                    animationController: _controller,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class ScaleList extends StatelessWidget {
  final Function(String ip) onScaleSelected;

  const ScaleList({super.key, required this.onScaleSelected});

  @override
  Widget build(BuildContext context) {
    final Map<String, String> scaleIps = {
      "AUFHÄNGESTATION NR.01": "10.152.102.10",
      "AUFHÄNGESTATION NR.02": "10.152.102.12",
      "AUFHÄNGESTATION NR.03": "10.152.102.13",
      "AUFHÄNGESTATION NR.04": "10.152.102.14",
      "AUFHÄNGESTATION NR.05": "10.152.102.15",
      "AUFHÄNGESTATION NR.06": "10.152.102.16",
      "AUFHÄNGESTATION NR.07": "10.152.102.17",
      "AUFHÄNGESTATION NR.08": "10.152.102.18",
      "AUFHÄNGESTATION NR.09": "10.152.102.19",
      "AUFHÄNGESTATION NR.10": "10.152.10.86",
      "AUFHÄNGESTATION MISCH. NR.21": "10.152.102.21",
      "AUFHÄNGESTATION MISCH. NR.22": "10.152.102.22",
      "AUFHÄNGESTATION MISCH. NR.23": "10.152.102.23",
      "AUFHÄNGESTATION MISCH. NR.24": "10.152.102.24",
      "AUFHÄNGESTATION MISCH. NR.25": "10.152.102.25",
      "AUFHÄNGESTATION RESYSTA LINKS": "10.152.102.26",
      "AUFHÄNGESTATION RESYSTA RE.": "10.152.102.27",
      "AUFHÄNGESTATION S090 TECHNIKUM": "10.152.102.28",
    };

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: scaleIps.entries.map((entry) {
          return ListTile(
            title: Text(entry.key), // Display station name
            subtitle: Text('IP: ${entry.value}'),
            onTap: () {
              Navigator.of(context).pop(); // Close dialog on selection
              onScaleSelected(entry.value); // Pass IP to the callback function
            },
          );
        }).toList(),
      ),
    );
  }
}

class StationOverview extends StatelessWidget {
  final List<dynamic> stations;

  const StationOverview({super.key, required this.stations});

  @override
  Widget build(BuildContext context) {
    // Get screen width
    final screenWidth = MediaQuery.of(context).size.width;

    // Define the target card width and height
    const double cardWidth = 250; // Width of each card
    const double cardHeight = 300; // Fixed height of each card

    // Calculate crossAxisCount by dividing screen width by the target card width
    int crossAxisCount = (screenWidth / cardWidth).floor();

    return GridView.builder(
      padding: const EdgeInsets.all(2.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 1,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
        mainAxisExtent: cardHeight, // Set the fixed height for each card
      ),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        var station = stations[index];
        return StationCard(
          station: station,
          isSmallScreen: screenWidth < 600,
        );
      },
    );
  }
}

class StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isSmallScreen;

  const StationCard({
    super.key,
    required this.station,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    String stationName = station['Station'] ?? 'N/A';
    String materialNumber = station['Materialnummer'] ?? 'FREI';
    String workplace = station['Arbeitsplatz'] ?? 'FREI';
    String remark = station['Bemerkung'] ?? 'N/A';
    String type = station['Name'] ?? 'N/A';
    String wbz = station['WBZ'] ?? 'N/A';

    // Parse the remainingWeight to double
    double remainingWeight = station['RemainingWeight'] != null
        ? double.tryParse(station['RemainingWeight'].toString()) ?? 0
        : 0;

    // Retrieve the time remaining from the station data
    String timeRemaining = station['TimeRemaining'] ?? 'Nicht genug Daten';

    // Determine the color based on the remaining weight and material
    Color statusColor = materialNumber == 'FREI'
        ? Colors.white
        : remainingWeight == 0
            ? Colors.blue
            : remainingWeight < 100 && remainingWeight > 0
                ? Colors.red
                : Colors.blue;

    // Set a fixed height for all cards to avoid overflow
    double fixedCardHeight = 300.0; // Adjust this height as needed

    return SizedBox(
      height: fixedCardHeight, // Use fixed height for all cards
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings,
                      color: statusColor, size: isSmallScreen ? 20 : 24),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Station: $stationName',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Ensure text doesn't overflow by using flexible layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Typ: $type',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Material: $materialNumber',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'WBZ: $wbz',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Linie: $workplace',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Bemerkung: $remark',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restgewicht: ${remainingWeight.toStringAsFixed(2)} kg',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display time remaining
                    Text(
                      'Verbleibende Zeit: $timeRemaining',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        color: Colors.lightGreenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaterialFlowDashboard extends StatelessWidget {
  final List<dynamic> stations;
  final bool isPipelineVisible;
  final AnimationController animationController;

  const MaterialFlowDashboard({
    super.key,
    required this.stations,
    required this.isPipelineVisible,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 600;

        if (screenWidth >= 1200) {
          // For large screens, use a grid layout with two rows and reduced spacing
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // Display in 4 columns
                crossAxisSpacing: 2.0, // Reduce horizontal spacing
                mainAxisSpacing: 2.0, // Reduce vertical spacing
                childAspectRatio: 2.5, // Adjust aspect ratio
              ),
              itemCount: stations.length,
              itemBuilder: (context, index) {
                var station = stations[index];
                return MaterialFlowCard(
                  station: station,
                  isSmallScreen: false,
                  isPipelineVisible: isPipelineVisible,
                  animationController: animationController,
                );
              },
            ),
          );
        } else {
          // For smaller screens, use the regular single-row list layout
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              var station = stations[index];
              return MaterialFlowCard(
                station: station,
                isSmallScreen: isSmallScreen,
                isPipelineVisible: isPipelineVisible,
                animationController: animationController,
              );
            },
          );
        }
      },
    );
  }
}

class MaterialFlowCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isSmallScreen;
  final bool isPipelineVisible;
  final AnimationController animationController;

  const MaterialFlowCard({
    super.key,
    required this.station,
    required this.isSmallScreen,
    required this.isPipelineVisible,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    String stationName = station['Station'] ?? 'N/A';
    String materialNumber = station['Materialnummer'] ?? 'FREI';
    String dryingRequired =
        station['Trocknung'] == 'JA' ? 'Erforderlich' : 'Nicht erforderlich';
    String workplace = station['Arbeitsplatz'] ?? 'FREI';
    String mainArticle = station['Hauptartikel'] ?? 'FREI';
    String equipment = station['Equipment'] ?? 'FREI';

    return Card(
      margin: const EdgeInsets.all(2), // Minimize the card margin
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(2), // Minimize internal padding
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Center(
                    child: ExtruderComponent(
                      equipment: equipment,
                      workstation: workplace,
                      article: mainArticle,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ),
                if (materialNumber != 'FREI')
                  Flexible(
                    child: Center(
                      child: Pipeline(
                        isVisible: isPipelineVisible,
                        animationController: animationController,
                      ),
                    ),
                  )
                else
                  const Spacer(), // Add Spacer for missing pipeline
                Flexible(
                  child: Center(
                    child: DryerComponent(
                      dryingRequired: dryingRequired,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ),
                if (materialNumber != 'FREI')
                  Flexible(
                    child: Center(
                      child: Pipeline(
                        isVisible: isPipelineVisible,
                        animationController: animationController,
                      ),
                    ),
                  )
                else
                  const Spacer(), // Add Spacer for missing pipeline
                Flexible(
                  child: Center(
                    child: StationComponent(
                      stationName: stationName,
                      materialName: materialNumber,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StationComponent extends StatelessWidget {
  final String stationName;
  final String materialName;
  final bool isSmallScreen;

  const StationComponent({
    super.key,
    required this.stationName,
    required this.materialName,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.gantryCrane,
            size: isSmallScreen ? 24 : 30,
            color: materialName == 'FREI' ? Colors.white : Colors.blue,
          ),
          const SizedBox(height: 10),
          Text(
            'Aufhängestation: $stationName',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 10 : 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            'Materialnummer: $materialName',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 10 : 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class DryerComponent extends StatelessWidget {
  final String dryingRequired;
  final bool isSmallScreen;

  const DryerComponent({
    super.key,
    required this.dryingRequired,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          dryingRequired == 'Erforderlich'
              ? MdiIcons.tumbleDryer
              : MdiIcons.tumbleDryerOff,
          size: isSmallScreen ? 24 : 30,
          color: dryingRequired == 'Erforderlich' ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 10),
        Text(
          dryingRequired,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 10 : 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ExtruderComponent extends StatelessWidget {
  final String equipment;
  final String workstation;
  final String article;
  final bool isSmallScreen;

  const ExtruderComponent({
    super.key,
    required this.equipment,
    required this.workstation,
    required this.article,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/extruder.svg',
          width: isSmallScreen ? 24 : 30,
          height: isSmallScreen ? 24 : 30,
          // ignore: deprecated_member_use
          color: Colors.orange,
        ),
        const SizedBox(height: 10),
        Text(
          'Linie: $workstation',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 12 : 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Artikel: $article',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 10 : 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Werkzeug: $equipment',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 10 : 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class Pipeline extends StatefulWidget {
  final bool isVisible;
  final AnimationController animationController;

  const Pipeline({
    super.key,
    required this.isVisible,
    required this.animationController,
  });

  @override
  _PipelineState createState() => _PipelineState();
}

class _PipelineState extends State<Pipeline> {
  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: widget.isVisible, // Enable animation based on visibility
      child: CustomPaint(
        painter: MovingGradientPipelinePainter(
          animation: widget.animationController,
        ),
        child: const SizedBox(
          width: double.infinity,
          height: 10, // Ensure a consistent height for the pipeline
        ),
      ),
    );
  }
}

class MovingGradientPipelinePainter extends CustomPainter {
  final Animation<double> animation;

  MovingGradientPipelinePainter({required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    double movingStop = animation.value;

    final gradient = LinearGradient(
      colors: const [
        Colors.blue,
        Colors.lightBlueAccent,
      ], // Simplified gradient
      stops: [movingStop, movingStop + 0.2],
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      tileMode: TileMode.clamp,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant MovingGradientPipelinePainter oldDelegate) {
    return true;
  }
}
