import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../modules/webview_module.dart';
import '../screens/pickists_screen.dart';
import '../modules/torsteuerung_module.dart';
import '../modules/converter_module.dart';
import 'package:hangerstations_dashboard_module/screens/hangerstations_dashboard_module.dart';
import 'package:tool_planning/screens/tool_planning_screen.dart';
import 'package:packaging_module/screens/production_orders_screen.dart';
import 'package:tryout_planning/screens/einfahr_planer_screen.dart';
import 'package:sap2worldship/main.dart';
import 'package:kistenqrcodegenerator/pages/qrcode_generator_page.dart';
import '../modules/suggestions_manager.dart';
import 'package:ttp_app/screens/tools_main_screen.dart';

/// A common class for module items used in the side menu and favorites.
class ModuleItem {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  ModuleItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

/// A class to group module items into a category (used for submenus).
/// An optional [icon] here will be used as the leading widget in the ExpansionTile.
class ModuleCategory {
  final String title;
  final List<ModuleItem> items;
  final Widget? icon;
  ModuleCategory({
    required this.title,
    required this.items,
    this.icon,
  });
}

/// Returns the list of module categories for the side menu.
List<ModuleCategory> getModuleCategories(BuildContext context) {
  return [
    ModuleCategory(
      title: 'IKOffice',
      icon: Image.asset(
        'assets/IKOffice.ico', // Replace with your asset path.
        width: 24,
        height: 24,
      ),
      items: [
        ModuleItem(
          title: 'IKOffce PZE',
          icon: Image.asset(
            'assets/IKOffice.ico', // Replace with your asset path.
            width: 24,
            height: 24,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: ikOfficePZE),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Linienkonfiguration',
          icon: Image.asset(
            'assets/IKOffice.ico', // Replace with your asset path.
            width: 24,
            height: 24,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: ikOfficeLineConfig),
              ),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Produktions und Materialpläne',
      icon: Icon(MdiIcons.notebookCheck),
      items: [
        ModuleItem(
          title: 'Produktionsplan 1W',
          icon: Icon(MdiIcons.numeric1BoxMultipleOutline),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: prodPlan1w),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Produktionsplan 3W',
          icon: Icon(MdiIcons.numeric3BoxMultipleOutline),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: prodPlan3w),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Materialplan',
          icon: const Icon(Icons.grain_rounded),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: matplan),
              ),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Informationen (Active Collab, Intranet etc.)',
      icon: Icon(Icons.info_sharp),
      items: [
        ModuleItem(
          title: 'Intranet',
          icon:
              Image.asset('assets/leuchtturm_blue.png', width: 36, height: 36),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: intranet),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'ActiveCollab',
          icon: Image.asset('assets/ac.png', width: 36, height: 36),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: ac),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'ttpedia',
          icon: Image.asset('assets/bookstack.png', width: 36, height: 36),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewModule(url: bookstack),
              ),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Gebäudemanagement',
      icon: Icon(Icons.house),
      items: [
        ModuleItem(
          title: 'Torsteuerung',
          icon: const Icon(Icons.door_sliding),
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
      ],
    ),
    ModuleCategory(
      title: 'Produktion',
      icon: Icon(MdiIcons.robotIndustrial),
      items: [
        ModuleItem(
          title: 'Aufhängestationen',
          icon: Icon(MdiIcons.gantryCrane),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Dashboard(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Kartonagen Fertigung',
          icon: Icon(MdiIcons.packageVariant),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductionOrdersScreen(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Störfall Textbaustein Manager',
          icon: Icon(MdiIcons.packageVariant),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SuggestionsManager(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Anbauteile Konverter',
          icon: Icon(MdiIcons.translate),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const ConverterModal(),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Werkzeugbau',
      icon: Icon(MdiIcons.nut),
      items: [
        ModuleItem(
          title: 'Werkzeuglagerverwaltung',
          icon: const Icon(Icons.storage),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToolsMainScreen(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Einfahrplaner',
          icon: Icon(MdiIcons.carHatchback),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EinfahrPlanerScreen(
                  isStandalone: false,
                  isFullscreen: false,
                ),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Planungstool WZB',
          icon: const Icon(Icons.view_kanban),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToolPlanningScreen(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'Kisten QR Code Generator',
          icon: Icon(MdiIcons.packageVariantClosed),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QrCodeGeneratorPage(),
              ),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Logistik',
      icon: Icon(Icons.forklift),
      items: [
        ModuleItem(
          title: 'Picklisten',
          icon: const Icon(Icons.checklist_rounded),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PdfReaderPage(),
              ),
            );
          },
        ),
        ModuleItem(
          title: 'SAP2Worldship',
          icon: SvgPicture.asset(
            'assets/icon/UPS_icon.svg',
            width: 36,
            height: 36,
            colorFilter: ColorFilter.mode(Colors.grey, BlendMode.dstIn),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SAP2WorldShipScreen(),
              ),
            );
          },
        ),
      ],
    ),
    ModuleCategory(
      title: 'Tools',
      icon: Icon(Icons.handyman),
      items: [],
    ),
  ];
}

/// Helper to flatten all ModuleCategories into a single list of ModuleItems.
List<ModuleItem> flattenCategories(List<ModuleCategory> categories) {
  return categories.expand((cat) => cat.items).toList();
}

/// Main drawer widget.
class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = getModuleCategories(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Drawer header.
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

          // Build an ExpansionTile for each category.
          ...categories.map((category) {
            return ExpansionTile(
              leading: category.icon, // Use the category's icon.
              title: Text(category.title),
              children: category.items.map((item) {
                return ListTile(
                  leading: item.icon,
                  title: Text(item.title),
                  onTap: item.onTap,
                );
              }).toList(),
            );
          }),
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
