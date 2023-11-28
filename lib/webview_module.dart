import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

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

      // Implement your custom logic based on the URL
      if (url.contains('some_keyword')) {
        // Do something
      }
    });
  }

  @override
  void dispose() {
    // Dispose of the webview when the widget is disposed
    _webviewPlugin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Externer Link'),
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
