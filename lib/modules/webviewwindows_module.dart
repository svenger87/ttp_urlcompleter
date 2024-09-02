import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

class WebViewWindowsModule extends StatefulWidget {
  final String initialUrl;

  const WebViewWindowsModule({Key? key, required this.initialUrl})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _WebViewWindowsModuleState createState() => _WebViewWindowsModuleState();
}

class _WebViewWindowsModuleState extends State<WebViewWindowsModule> {
  final _controller = WebviewController();
  final _textController = TextEditingController();
  final List<StreamSubscription> _subscriptions = [];
  bool _isWebviewSuspended = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      await _controller.initialize();
      _subscriptions.add(_controller.url.listen((url) {
        _textController.text = url;
      }));

      _subscriptions.add(
        _controller.containsFullScreenElementChanged.listen((flag) {
          debugPrint('Contains fullscreen element: $flag');
          windowManager.setFullScreen(flag);
        }),
      );

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl(widget.initialUrl);

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Fehler'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${e.code}'),
                Text('Message: ${e.message}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Fortfahren'),
              )
            ],
          ),
        );
      });
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        'Starte WebView',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Card(
              elevation: 0,
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Zurück',
                  splashRadius: 20,
                  onPressed: () {
                    _controller.goBack();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Neu Laden',
                  splashRadius: 20,
                  onPressed: () {
                    _controller.reload();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Vorwärts',
                  splashRadius: 20,
                  onPressed: () {
                    _controller.goForward();
                  },
                ),
              ]),
            ),
            Expanded(
              child: Card(
                color: Colors.transparent,
                elevation: 0,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Stack(
                  children: [
                    Webview(
                      _controller,
                      permissionRequested: _onPermissionRequested,
                    ),
                    StreamBuilder<LoadingState>(
                      stream: _controller.loadingState,
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data == LoadingState.loading) {
                          return const LinearProgressIndicator();
                        } else {
                          return const SizedBox();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: _isWebviewSuspended ? 'Fortfahren' : 'Pausieren',
        onPressed: () async {
          if (_isWebviewSuspended) {
            await _controller.resume();
          } else {
            await _controller.suspend();
          }
          setState(() {
            _isWebviewSuspended = !_isWebviewSuspended;
          });
        },
        child: Icon(_isWebviewSuspended ? Icons.play_arrow : Icons.pause),
      ),
      appBar: AppBar(
        title: StreamBuilder<String>(
          stream: _controller.title,
          builder: (context, snapshot) {
            return Text(snapshot.hasData ? snapshot.data! : 'Externer Link');
          },
        ),
        backgroundColor: const Color(0xFF104382),
      ),
      body: Center(
        child: compositeView(),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView benötigt Berechtigung'),
        content: Text('WebView hat eine Berechtigung angefragt \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Verweigern'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Zulassen'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }
}
