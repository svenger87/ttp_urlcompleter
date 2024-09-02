// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:ttp_app/modules/webviewwindows_module.dart';
import 'package:ttp_app/modules/webview_module.dart';

void navigateToUrl(BuildContext context, String url,
    {bool isWindows = false}) async {
  if (await canLaunch(url)) {
    if (isWindows) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewWindowsModule(initialUrl: url),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewModule(url: url),
        ),
      );
    }
  } else {
    if (kDebugMode) {
      print('Could not launch $url');
    }
  }
}
