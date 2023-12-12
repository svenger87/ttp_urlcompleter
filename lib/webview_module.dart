import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class WebViewModule extends StatefulWidget {
  final String url;

  const WebViewModule({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewModuleState createState() => _WebViewModuleState();
}

class _WebViewModuleState extends State<WebViewModule> {
  final FlutterWebviewPlugin _webviewPlugin = FlutterWebviewPlugin();
  bool _isLoading = true;
  String _pageTitle = ''; // Variable to store the site name

  @override
  void initState() {
    super.initState();

    // Optional: Enable debugging for the webview
    _webviewPlugin.launch(widget.url, debuggingEnabled: true);

    // Listen to page events
    _webviewPlugin.onStateChanged.listen((WebViewStateChanged state) {
      if (kDebugMode) {
        print('WebView State Changed:');
      }
      if (kDebugMode) {
        print('  Type: ${state.type}');
      }
      if (kDebugMode) {
        print('  URL: ${state.url}');
      }

      if (state.type == WebViewState.finishLoad) {
        if (kDebugMode) {
          print('Page finished loading');
        }
        setState(() {
          _isLoading = false;
        });
      } else if (state.type == WebViewState.startLoad) {
        if (kDebugMode) {
          print('Page started loading');
        }
        setState(() {
          _isLoading = true;
        });
      }
    });

    // Listen to URL changes
    _webviewPlugin.onUrlChanged.listen((String url) {
      if (kDebugMode) {
        print('URL Changed: $url');
      }

      // Extract the page title from the URL or implement your logic
      // For example, you can use a package like 'url_launcher' to parse the URL
      String pageTitle = extractPageTitleFromUrl(url);

      setState(() {
        _pageTitle = pageTitle;
      });
    });
  }

  // Function to extract page title from the URL (you can implement your logic)
  String extractPageTitleFromUrl(String url) {
    // Implement your logic to extract the page title
    // For simplicity, let's say the title is the last segment of the URL
    List<String> segments = Uri.parse(url).pathSegments;
    return segments.isNotEmpty ? segments.last : 'Unknown';
  }

  @override
  void dispose() {
    _webviewPlugin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle), // Dynamically set the title
        backgroundColor: const Color(0xFF104382),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canGoBack = await _webviewPlugin.canGoBack();
              if (kDebugMode) {
                print('Can Go Back: $canGoBack');
              }
              if (canGoBack) {
                _webviewPlugin.goBack();
              } else {
                if (kDebugMode) {
                  print('Cannot go back.');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              final canGoForward = await _webviewPlugin.canGoForward();
              if (kDebugMode) {
                print('Can Go Forward: $canGoForward');
              }
              if (canGoForward) {
                _webviewPlugin.goForward();
              } else {
                if (kDebugMode) {
                  print('Cannot go forward.');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webviewPlugin.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebviewScaffold(
            url: widget.url,
            withZoom: true,
            withLocalStorage: true,
            ignoreSSLErrors: true,
            hidden: false,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
