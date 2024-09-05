import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart'; // For parsing HTML
import 'package:webview_flutter/webview_flutter.dart';
// Import platform-specific WebView components.
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewModule extends StatefulWidget {
  final String url;

  const WebViewModule({Key? key, required this.url}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _WebViewModuleState createState() => _WebViewModuleState();
}

class _WebViewModuleState extends State<WebViewModule> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = 'Lade...';

  @override
  void initState() {
    super.initState();

    // Platform-specific WebViewController creation parameters
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // For iOS/macOS
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      // Default params for Android
      params = const PlatformWebViewControllerCreationParams();
    }

    // WebViewController initialization with platform params
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    // Set JavaScript and NavigationDelegate
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress: $progress%)');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            String? title = await _controller.getTitle();
            setState(() {
              _pageTitle = title ?? 'Web Page';
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
          ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    // Platform-specific behavior for Android and iOS/macOS
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    // Extract initial page title
    extractPageTitleFromUrl(widget.url);
  }

  Future<void> extractPageTitleFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final document = parse(response.body);
      final titleElement = document.head?.querySelector('title');
      final pageTitle = titleElement?.text ?? 'Externer Link';

      setState(() {
        _pageTitle = pageTitle;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting page title: $e');
      }
    }
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
              if (await _controller.canGoBack()) {
                _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await _controller.canGoForward()) {
                _controller.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
