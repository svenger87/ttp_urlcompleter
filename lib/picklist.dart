import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'webview_module.dart';

class PickListModule extends StatelessWidget {
  const PickListModule({Key? key}) : super(key: key);

  // Nextcloud share URL
  static const String nextcloudShareUrl =
      'https://wim-solution.sip.local:8443/s/tsCLmJSTadGT88c'; // Replace with your share URL

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
      final response = await http.get(Uri.parse(nextcloudShareUrl));
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
