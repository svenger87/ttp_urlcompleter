// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/loading_indicator.dart';
import '../modules/webview_module.dart';
import '../screens/login_screen.dart';
import '../modals/comments_thread_modal.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
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

      if (kDebugMode) {
        print('Fetched Project Details: $projectDetails');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching project details: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Projektdetails: $e')),
      );
    }
  }

  Future<void> _openCommentsThread() async {
    try {
      // Check if the user is authenticated
      String? sessionToken = await ApiService.getSessionToken();

      if (kDebugMode) {
        print('Session token: \$sessionToken');
      }

      if (sessionToken == null) {
        // If not authenticated, navigate to LoginScreen
        bool? loginSuccess = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );

        if (kDebugMode) {
          print('Login success: \$loginSuccess');
        }

        if (loginSuccess != true) {
          // If login failed or was cancelled, do nothing
          return;
        }
      }

      // User is authenticated, fetch and display comments
      await _fetchAndShowComments();
    } catch (e) {
      if (kDebugMode) {
        print('Error in _openCommentsThread: \$e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fehler beim Öffnen der Kommentaransicht')),
      );
    }
  }

  Future<void> _fetchAndShowComments() async {
    final projectId = projectDetails?['salamanderacprojectnumber'] as String?;
    final taskIdString = projectDetails?['salamanderactaskid'] as String?;
    final taskId = taskIdString != null ? int.tryParse(taskIdString) : null;

    if (kDebugMode) {
      print('Project ID: \$projectId, Task ID: \$taskId');
    }

    if (taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task-ID fehlt')),
      );
      return;
    }

    try {
      List<Map<String, dynamic>> comments =
          await ApiService.fetchCommentsForTask(taskId: taskId);

      if (kDebugMode) {
        print('Fetched comments: \$comments');
      }

      // Open the comments thread modal
      await showDialog(
        context: context,
        builder: (context) {
          return CommentsThreadModal(
            comments: comments,
            projectId: int.parse(projectId!),
            taskId: taskId,
          );
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching comments: \$e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Laden der Kommentare')),
      );
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
          content: Text('Keine Projektdetails verfügbar für Link-Generierung'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(projectDetails?['number'] ?? 'Projektdetails'),
      ),
      body: isLoading
          ? const LoadingIndicator()
          : projectDetails == null
              ? const Center(child: Text('Keine Details verfügbar'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Werkzeug: ${projectDetails?['number'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        Text('Name: ${projectDetails?['name'] ?? 'N/A'}'),
                        const SizedBox(height: 10),
                        Text(
                            'Priorität: ${projectDetails?['priority_order'] ?? 'Nicht gesetzt'}'),
                        const SizedBox(height: 10),
                        Text(
                            'Status: ${projectDetails?['internalstatus'] ?? 'N/A'}'),
                        const SizedBox(height: 10),
                        Text(
                            'Beschreibung: ${projectDetails?['description'] ?? 'N/A'}'),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _openWebView,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/ac.png', // Path to your asset image
                                height: 20, // Adjust the height as needed
                              ),
                              const SizedBox(width: 8),
                              const Text('AC Projekt öffnen'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _openCommentsThread,
                          icon: const Icon(Icons.forum),
                          label: const Text('Kommentare anzeigen'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
