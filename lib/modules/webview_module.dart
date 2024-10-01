import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart'; // For parsing HTML
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewModule extends StatefulWidget {
  final String url;

  const WebViewModule({Key? key, required this.url}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _WebViewModuleState createState() => _WebViewModuleState();
}

class _WebViewModuleState extends State<WebViewModule> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  String _pageTitle = 'Lade...';
  double progress = 0;
  PullToRefreshController? pullToRefreshController;
  final TextEditingController urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Pull to refresh controller (only for Android and iOS)
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: Colors.blue,
        ),
        onRefresh: () async {
          _controller?.reload();
        },
      );
    }

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
              if (await _controller?.canGoBack() ?? false) {
                _controller?.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await _controller?.canGoForward() ?? false) {
                _controller?.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest:
                        URLRequest(url: WebUri.uri(Uri.parse(widget.url))),
                    pullToRefreshController: pullToRefreshController,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading =
                            true; // Start showing the loading indicator
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading =
                            false; // Hide the loading indicator when done
                      });
                      pullToRefreshController?.endRefreshing();
                    },
                    onReceivedServerTrustAuthRequest:
                        (controller, challenge) async {
                      return ServerTrustAuthResponse(
                          action: ServerTrustAuthResponseAction.PROCEED);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        this.progress = progress / 100;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      if (kDebugMode) {
                        print(consoleMessage);
                      }
                    },
                  ),
                  if (_isLoading)
                    const Center(
                        child:
                            CircularProgressIndicator()), // Display loading indicator
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
