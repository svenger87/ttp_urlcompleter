import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/loading_indicator.dart';
import '../modules/webview_module.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  // ignore: library_private_types_in_public_api
  _ProjectDetailScreenState createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? projectDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProjectDetails();
  }

  Future<void> fetchProjectDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final details =
          await ApiService.fetchProjectDetailsById(widget.projectId);
      setState(() {
        projectDetails = details;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching project details: $e');
      }
    }
  }

  void _openWebView() {
    if (kDebugMode) {
      print('Attempting to open WebView with project details: $projectDetails');
    }

    if (projectDetails != null) {
      final projectNumber = projectDetails!['salamanderacprojectnumber'];
      final taskId = projectDetails!['salamanderactaskid'];

      // Check if necessary information is present
      if (projectNumber == null || taskId == null) {
        if (kDebugMode) {
          print('Missing projectNumber or taskId for link generation.');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine IKOffice Projektdetails gepflegt.'),
          ),
        );
        return;
      }

      // Construct the URL using the project number and task ID
      final url =
          'https://olymp.sip.de/projects/$projectNumber?modal=Task-$taskId-$projectNumber';

      if (kDebugMode) {
        print('Generated URL: $url');
      }

      // Navigate to the WebViewModule with the generated URL
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewModule(url: url),
        ),
      );
    } else {
      if (kDebugMode) {
        print('Project details are null, cannot open WebView.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No project details available for link generation'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(projectDetails?['name'] ?? 'Project Details'),
      ),
      body: isLoading
          ? const LoadingIndicator()
          : projectDetails == null
              ? const Center(child: Text('No details available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${projectDetails?['name'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Text('Number: ${projectDetails?['number'] ?? 'N/A'}'),
                      const SizedBox(height: 10),
                      Text(
                          'Priority: ${projectDetails?['priority_order'] ?? 'Not Set'}'),
                      const SizedBox(height: 10),
                      Text(
                          'Status: ${projectDetails?['internalstatus'] ?? 'N/A'}'),
                      const SizedBox(height: 10),
                      Text(
                          'Description: ${projectDetails?['description'] ?? 'N/A'}'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _openWebView,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/ac.png', // Path to your asset image
                              height:
                                  20, // Adjust the height according to your needs
                            ),
                            const SizedBox(
                                width:
                                    8), // Add some space between the icon and text
                            const Text('AC Projekt öffnen'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
