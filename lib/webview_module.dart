import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

class WebViewModule extends StatefulWidget {
  final String url;

  const WebViewModule({Key? key, required this.url}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _WebViewModuleState createState() => _WebViewModuleState();
}

class _WebViewModuleState extends State<WebViewModule> {
  final FlutterWebviewPlugin _webviewPlugin = FlutterWebviewPlugin();
  bool _isLoading = true;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();

    _webviewPlugin.launch(widget.url, debuggingEnabled: true);

    _webviewPlugin.onStateChanged.listen((WebViewStateChanged state) {
      if (kDebugMode) {
        print('WebView State Changed:');
        print('  Type: ${state.type}');
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

    _webviewPlugin.onUrlChanged.listen((String url) {
      if (kDebugMode) {
        print('URL Changed: $url');
      }

      // Extract the page title from the URL using flutter_html
      extractPageTitleFromUrl(url);
    });
  }

  Future<void> extractPageTitleFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final htmlContent = response.body;
      final document = parse(htmlContent);
      final titleElement = document.head?.querySelector('title');
      final pageTitle = titleElement?.text ?? 'Externer Link';

      setState(() {
        _pageTitle = pageTitle;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting page title: $e');
      }
      // Handle error gracefully, e.g., show error message to user
    }
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
        title: Text(_pageTitle),
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
