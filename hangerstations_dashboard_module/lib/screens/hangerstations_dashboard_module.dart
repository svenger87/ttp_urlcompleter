// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

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
  Map<String, dynamic>? _fetchedData;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Start the animation loop

    _fetchDataSilently(); // Initial data fetch
    _startBackgroundUpdate(); // Start the background update timer
  }

  // Function to silently fetch data without showing any loading indicators
  Future<void> _fetchDataSilently() async {
    try {
      final data = await fetchData();
      setState(() {
        _fetchedData = data;
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

  // Fetch the actual data from the API
  Future<Map<String, dynamic>> fetchData() async {
    final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:5000/api/dashboard_data'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
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
        await _pollCacheUpdateStatus();
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

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF104382),
          title: const Text('Status Aufhängestationen'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aufhängestationen'),
              Tab(text: 'Materialfluss'),
            ],
          ),
          actions: [
            IconButton(
              icon: isUpdating
                  ? RotationTransition(
                      turns: _controller,
                      child: const Icon(Icons.refresh),
                    )
                  : const Icon(Icons.refresh),
              onPressed: isUpdating
                  ? null
                  : () async {
                      await _updateCache();
                    },
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
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              // Ensure snapshot.data is not null
              return const Center(child: Text('No data available.'));
            } else {
              var stations = List.from(snapshot.data!['stations']);
              stations.sort(
                  (a, b) => (a['Station'] ?? '').compareTo(b['Station'] ?? ''));
              return TabBarView(
                children: [
                  StationOverview(stations: stations),
                  MaterialFlowDashboard(stations: stations),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class StationOverview extends StatelessWidget {
  final List<dynamic> stations;

  const StationOverview({super.key, required this.stations});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 2;
    } else if (screenWidth >= 600 && screenWidth < 1200) {
      crossAxisCount = 3;
    } else if (screenWidth >= 1200 && screenWidth < 1600) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 8;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: screenWidth < 600 ? 2 : 1.5,
        ),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          var station = stations[index];
          return StationCard(
              station: station, isSmallScreen: screenWidth < 600);
        },
      ),
    );
  }
}

class MaterialFlowDashboard extends StatelessWidget {
  final List<dynamic> stations;

  const MaterialFlowDashboard({super.key, required this.stations});

  List<dynamic> reorderStationsInSnakePattern(
      List<dynamic> stations, int crossAxisCount) {
    int totalItems = stations.length;
    int numRows =
        (totalItems / crossAxisCount).ceil(); // Calculate number of rows

    // Create an empty list for reordered stations
    List<dynamic> reorderedStations = List.filled(totalItems, null);

    // Reorder the list in a "snake" pattern
    for (int i = 0; i < totalItems; i++) {
      int row = i % numRows;
      int col = i ~/ numRows;
      int newIndex = col + row * crossAxisCount;

      // Make sure to avoid any null value overflow if the totalItems is not a perfect multiple of crossAxisCount
      if (newIndex < totalItems) {
        reorderedStations[newIndex] = stations[i];
      }
    }

    return reorderedStations;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 1; // For small screens, show 1 column
    } else {
      crossAxisCount = 2; // For larger screens, show 2 columns
    }

    // Reduce card size by adjusting childAspectRatio based on both width and height
    final double cardHeight =
        screenHeight / 9.5; // Adjust this value to fit more cards vertically
    final double cardWidth = screenWidth / crossAxisCount;
    final double aspectRatio =
        cardWidth / cardHeight; // Adjust based on the new height

    // Reorder the stations in a snake pattern
    List<dynamic> reorderedStations =
        reorderStationsInSnakePattern(stations, crossAxisCount);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: aspectRatio, // Dynamically calculated aspect ratio
        ),
        itemCount: reorderedStations.length,
        itemBuilder: (context, index) {
          var station = reorderedStations[index];
          return MaterialFlowCard(
            station: station,
            isSmallScreen: screenWidth < 600,
          );
        },
      ),
    );
  }
}

class StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isSmallScreen;

  const StationCard(
      {super.key, required this.station, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    String stationName = station['Station'] ?? 'N/A';
    String materialNumber = station['Materialnummer'] ?? 'FREI';
    String workplace = station['Arbeitsplatz'] ?? 'FREI';
    String remark = station['Bemerkung'] ?? 'N/A';
    String type = station['Name'] ?? 'N/A;';
    String wbz = station['WBZ'] ?? 'N/A;';
    Color statusColor = materialNumber == 'FREI' ? Colors.white : Colors.blue;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings,
                    color: statusColor, size: isSmallScreen ? 20 : 24),
                const SizedBox(width: 8),
                Text(
                  'Station: $stationName',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Typ: $type',
              style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14, color: Colors.white70),
            ),
            Text(
              'Material: $materialNumber',
              style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14, color: Colors.white70),
            ),
            Text(
              'WBZ: $wbz',
              style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 24, color: Colors.white70),
            ),
            Text(
              'Linie: $workplace',
              style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14, color: Colors.white70),
            ),
            Text(
              'Bemerkung: $remark',
              style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class MaterialFlowCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isSmallScreen;

  const MaterialFlowCard({
    super.key,
    required this.station,
    required this.isSmallScreen,
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
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Ensure elements are spaced evenly
              children: [
                Flexible(
                  child: Center(
                    child: StationComponent(
                      stationName: stationName,
                      materialName: materialNumber,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ),
                if (materialNumber != 'FREI')
                  const Flexible(
                    child: Center(
                      child: Pipeline(),
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
                  const Flexible(
                    child: Center(
                      child: Pipeline(),
                    ),
                  )
                else
                  const Spacer(), // Add Spacer for missing pipeline
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
      // Wrap everything in a Center widget
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center the content
        children: [
          Icon(
            MdiIcons.gantryCrane,
            size: isSmallScreen ? 24 : 30,
            color: materialName == 'FREI'
                ? Colors.white
                : Colors.blue, // Set icon to white if materialNumber is 'LEER'
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
      mainAxisAlignment:
          MainAxisAlignment.center, // Ensure the content is centered
      children: [
        Icon(
          dryingRequired == 'Erforderlich'
              ? MdiIcons.tumbleDryer
              : MdiIcons.tumbleDryerOff, // Show tumbleDryerOff if not required
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
      mainAxisAlignment:
          MainAxisAlignment.center, // Ensure the content is centered
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
  const Pipeline({super.key});

  @override
  _PipelineState createState() => _PipelineState();
}

class _PipelineState extends State<Pipeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MovingGradientPipelinePainter(animation: _animation),
      child: const SizedBox(
        width: double.infinity,
        height: 10, // Ensure a consistent height for the pipeline
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
        Colors.blue,
      ],
      stops: [movingStop, movingStop + 0.2, movingStop + 0.4],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      tileMode: TileMode.repeated,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
