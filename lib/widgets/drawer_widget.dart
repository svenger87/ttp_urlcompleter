import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../constants.dart';
import '../modules/webview_module.dart';
import '../screens/tool_ui.dart';
import '../screens/pickists_screen.dart';
import '../modules/torsteuerung_module.dart';
import '../modules/converter_module.dart';
//import '../screens/stations_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:hangerstations_dashboard_module/screens/hangerstations_dashboard_module.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/leuchtturm.png',
                      width: 36,
                      height: 36,
                    ),
                    const Text(
                      'Tools & Links',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'it-support@ttp-papenburg.de',
                    );

                    // ignore: deprecated_member_use
                    if (await canLaunch(emailUri.toString())) {
                      // ignore: deprecated_member_use
                      await launch(emailUri.toString());
                    } else {
                      if (kDebugMode) {
                        print('Could not launch email client');
                      }
                    }
                  },
                  child: const Text(
                    '  it-support@ttp-papenburg.de',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading:
                Image.asset('assets/productionplan.png', width: 36, height: 36),
            title: const Text('Produktionspläne'),
            children: [
              ListTile(
                leading: Image.asset('assets/productionplan.png',
                    width: 36, height: 36),
                title: const Text('Produktionsplan 1W'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WebViewModule(url: prodPlan1w),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Image.asset('assets/productionplan.png',
                    width: 36, height: 36),
                title: const Text('Produktionsplan 3W'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WebViewModule(url: prodPlan3w),
                    ),
                  );
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.grain_rounded),
            title: const Text('Materialplanung'),
            children: [
              ListTile(
                leading: const Icon(Icons.grain_rounded),
                title: const Text('Materialplan'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WebViewModule(url: matplan),
                    ),
                  );
                },
              ),
            ],
          ),
          ListTile(
            leading: Image.asset('assets/leuchtturm_blue.png',
                width: 36, height: 36),
            title: const Text('Intranet'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebViewModule(url: intranet),
                ),
              );
            },
          ),
          ListTile(
            leading: Image.asset('assets/ac.png', width: 36, height: 36),
            title: const Text('ActiveCollab'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebViewModule(url: ac),
                ),
              );
            },
          ),
          ListTile(
            leading: Image.asset('assets/bookstack.png', width: 36, height: 36),
            title: const Text('ttpedia'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebViewModule(url: bookstack),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: const Text('Picklisten'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const PdfReaderPage(),
              ));
            },
          ),
          ListTile(
            leading: Icon(MdiIcons.gantryCrane),
            title: const Text('Aufhängestationen'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const Dashboard(),
              ));
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.handyman),
            title: const Text('Tools'),
            children: [
              const ConverterModule(),
              ListTile(
                leading: const Icon(Icons.door_sliding),
                title: const Text('Torsteuerung'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const TorsteuerungModule(initialUrl: 'google.de'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Werkzeuglagerverwaltung'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ToolInventoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentItemsDrawer extends StatelessWidget {
  final List<String> recentItems;
  final void Function() clearRecentItems;
  final String wim;

  const RecentItemsDrawer({
    super.key,
    required this.recentItems,
    required this.clearRecentItems,
    required this.wim,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Zuletzt benutzt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recentItems.length + 1,
              itemBuilder: (context, index) {
                if (index < recentItems.length) {
                  final recentUrl = '$wim/${recentItems[index]}';
                  return ListTile(
                    title: Text(recentItems[index]),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewModule(url: recentUrl),
                        ),
                      );
                    },
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextButton(
                      onPressed: clearRecentItems,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8.0),
                          Text('Zuletzt benutzte löschen',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
