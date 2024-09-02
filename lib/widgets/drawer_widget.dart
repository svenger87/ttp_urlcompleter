// ignore_for_file: deprecated_member_use, unused_element

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../constants.dart';
import '../modules/webview_module.dart';
import '../modules/webviewwindows_module.dart';
import '../screens/tool_ui.dart';
import '../screens/pickists_screen.dart';
import '../modules/torsteuerung_module.dart';
import '../modules/converter_module.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({Key? key}) : super(key: key);

  void _openUrl(BuildContext context, String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        enableJavaScript: true,
        forceWebView: true,
      );
    } else {
      if (kDebugMode) {
        print('Could not launch $url');
      }
    }
  }

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

                    if (await canLaunch(emailUri.toString())) {
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
                  if (Platform.isWindows) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const WebViewWindowsModule(initialUrl: prodPlan1w),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const WebViewModule(url: prodPlan1w),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Image.asset('assets/productionplan.png',
                    width: 36, height: 36),
                title: const Text('Produktionsplan 3W'),
                onTap: () {
                  if (Platform.isWindows) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const WebViewWindowsModule(initialUrl: prodPlan3w),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const WebViewModule(url: prodPlan3w),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          ListTile(
            leading: Image.asset('assets/leuchtturm_blue.png',
                width: 36, height: 36),
            title: const Text('Intranet'),
            onTap: () {
              if (Platform.isWindows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const WebViewWindowsModule(initialUrl: intranet),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(url: intranet),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Image.asset('assets/ac.png', width: 36, height: 36),
            title: const Text('ActiveCollab'),
            onTap: () {
              if (Platform.isWindows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const WebViewWindowsModule(initialUrl: ac),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(url: ac),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Image.asset('assets/bookstack.png', width: 36, height: 36),
            title: const Text('ttpedia'),
            onTap: () {
              if (Platform.isWindows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const WebViewWindowsModule(initialUrl: bookstack),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebViewModule(url: bookstack),
                  ),
                );
              }
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

  const RecentItemsDrawer({
    Key? key,
    required this.recentItems,
    required this.clearRecentItems,
  }) : super(key: key);

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
                      if (Platform.isWindows) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WebViewWindowsModule(initialUrl: recentUrl),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebViewModule(url: recentUrl),
                          ),
                        );
                      }
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
