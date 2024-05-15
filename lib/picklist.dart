import 'dart:io'; // Import dart:io for HttpClient
import 'package:flutter/material.dart';
import 'package:http/io_client.dart'
    as http; // Import IOClient for SSL certificate bypass
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'webview_module.dart';

class PickListModule extends StatelessWidget {
  const PickListModule({Key? key}) : super(key: key);

  // Nextcloud share URL
  static const String nextcloudShareUrl =
      'https://10.152.50.75:8443/s/tsCLmJSTadGT88c'; // Replace with your share URL

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _fetchPicklistUrls(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Text('Error fetching picklists');
        } else if (snapshot.hasData) {
          final picklistUrls = snapshot.data!;
          return ListView.builder(
            itemCount: picklistUrls.length,
            itemBuilder: (context, index) {
              final url = picklistUrls[index];
              return ListTile(
                title: Text(url),
                onTap: () {
                  _openPicklistWebView(context, url);
                },
              );
            },
          );
        } else {
          return const Text('No picklists found');
        }
      },
    );
  }

  // Function to fetch picklist URLs from Nextcloud share
  Future<List<String>> _fetchPicklistUrls() async {
    try {
      final httpClient = http.IOClient(HttpClient()
        ..badCertificateCallback =
            ((_, __, ___) => true)); // Use the bypass from main
      final response = await httpClient.get(Uri.parse(nextcloudShareUrl));
      final html = response.body;
      final document = parse(html);

      final List<String> picklistUrls = [];
      final List<dom.Element> linkElements =
          document.querySelectorAll('a[href^="/nextcloud_share"]');
      for (final element in linkElements) {
        final href = element.attributes['href'];
        if (href != null) {
          final url = nextcloudShareUrl + href;
          picklistUrls.add(url);
          print('Fetched picklist URL: $url'); // Debug print statement
        }
      }

      httpClient.close(); // Close the HttpClient to release resources

      return picklistUrls;
    } catch (e) {
      print('Error fetching picklist URLs: $e');
      return [];
    }
  }

  // Function to open picklist in webview
  void _openPicklistWebView(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewModule(url: url),
      ),
    );
  }
}
