// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, unused_local_variable

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  bool isUpdating = false;
  late AnimationController _controller; // Declare the controller

  @override
  void initState() {
    super.initState();

    // Initialize the controller here
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Start the animation loop
  }

  // Define the fetchData method here
  Future<Map<String, dynamic>> fetchData() async {
    final response = await http.get(
        Uri.parse('http://wim-solution.sip.local:5000/api/dashboard_data'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> _updateCache() async {
    setState(() {
      isUpdating = true; // Start the spinning animation
    });

    try {
      final response = await http.post(
          Uri.parse('http://wim-solution.sip.local:5000/api/update_cache'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache update triggered.')),
        );
        await _pollCacheUpdateStatus(); // Start polling for completion status
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
        isUpdating = false; // Stop the spinning animation
      });
    }
  }

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
            setState(() {}); // Refresh UI after update
          } else {
            await Future.delayed(
                const Duration(seconds: 2)); // Wait before checking again
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Fehler beim prüfen vom Cache Update Status: ${response.statusCode}')),
          );
          break; // Exit if there's an error in status checking
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fehler beim prüfen vom Cache Update Status: $e')),
        );
        break; // Exit if there's an error in status checking
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the controller properly
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF104382),
          title: const Text('Dashboards'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aufhängestationen'),
              Tab(text: 'Materialfluss'),
            ],
          ),
          actions: [
            IconButton(
              icon: isUpdating
                  // ignore: unnecessary_null_comparison
                  ? (_controller != null && _controller.isAnimating
                      ? RotationTransition(
                          turns: _controller,
                          child: const Icon(Icons.refresh),
                        )
                      : const Icon(Icons.refresh))
                  : const Icon(Icons.refresh),
              onPressed: isUpdating
                  ? null // Disable button while updating
                  : () async {
                      await _updateCache(); // Trigger the cache update and start polling for status
                    },
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: fetchData(), // Call the fetchData method
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isSmallScreen ? 1 : 2,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: isSmallScreen ? 2 : 1.5,
        ),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          var station = stations[index];
          return StationCard(station: station, isSmallScreen: isSmallScreen);
        },
      ),
    );
  }
}

class MaterialFlowDashboard extends StatelessWidget {
  final List<dynamic> stations;

  const MaterialFlowDashboard({super.key, required this.stations});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, index) {
        var station = stations[index];
        return MaterialFlowCard(station: station, isSmallScreen: isSmallScreen);
      },
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
    Color statusColor = materialNumber == 'FREI' ? Colors.red : Colors.green;

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

  const MaterialFlowCard(
      {super.key, required this.station, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    String stationName = station['Station'] ?? 'N/A';
    String materialNumber = station['Materialnummer'] ?? 'FREI';
    String dryingRequired =
        station['Trocknung'] == 'JA' ? 'Erforderlich' : 'Nicht erforderlich';
    String workplace = station['Arbeitsplatz'] ?? 'FREI';
    String mainArticle = station['Hauptartikel'] ?? 'FREI';
    String equipment = station['Equipment'] ?? 'FREI';
    Color statusColor = materialNumber == 'FREI' ? Colors.red : Colors.green;
    Color dryingColor =
        dryingRequired == 'Erforderlich' ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.grey[900],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StationComponent(
                  stationName: stationName,
                  materialName: materialNumber,
                  isSmallScreen: isSmallScreen,
                ),
              ),
              const Pipeline(),
              Expanded(
                child: DryerComponent(
                  dryingRequired: dryingRequired,
                  isSmallScreen: isSmallScreen,
                ),
              ),
              const Pipeline(),
              Expanded(
                child: ExtruderComponent(
                  equipment: equipment,
                  workstation: workplace,
                  article: mainArticle,
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
        ],
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(MdiIcons.gantryCrane,
            size: isSmallScreen ? 24 : 30, color: Colors.blue),
        const SizedBox(height: 10),
        Text(
          'Aufhängestation: $stationName',
          style:
              TextStyle(color: Colors.white, fontSize: isSmallScreen ? 10 : 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Materialnummer: $materialName',
          style: TextStyle(
              color: Colors.white70, fontSize: isSmallScreen ? 10 : 12),
          textAlign: TextAlign.center,
        ),
      ],
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
      children: [
        Icon(MdiIcons.tumbleDryer,
            size: isSmallScreen ? 24 : 30,
            color:
                dryingRequired == 'Erforderlich' ? Colors.green : Colors.red),
        const SizedBox(height: 10),
        Text(
          dryingRequired,
          style:
              TextStyle(color: Colors.white, fontSize: isSmallScreen ? 10 : 12),
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
          style:
              TextStyle(color: Colors.white, fontSize: isSmallScreen ? 12 : 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Artikel: $article',
          style: TextStyle(
              color: Colors.white70, fontSize: isSmallScreen ? 10 : 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Werkzeug: $equipment',
          style: TextStyle(
              color: Colors.white70, fontSize: isSmallScreen ? 10 : 12),
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
          width: 100, height: 30), // Adjusted for horizontal layout
    );
  }
}

class MovingGradientPipelinePainter extends CustomPainter {
  final Animation<double> animation;

  MovingGradientPipelinePainter({required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the moving stop position based on the animation value
    double movingStop = animation.value;

    // Create a gradient that moves from left to right
    final gradient = LinearGradient(
      colors: const [Colors.blue, Colors.lightBlueAccent, Colors.blue],
      stops: [movingStop - 0.3, movingStop, movingStop + 0.3],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // Create a rectangle for the pipeline
    final rect = Rect.fromLTWH(0, size.height / 2 - 5, size.width, 10);

    // Use the gradient to paint the pipeline
    final paint = Paint()..shader = gradient.createShader(rect);

    // Draw the pipeline as a rectangle
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint when animation updates
  }
}
