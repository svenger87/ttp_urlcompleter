import 'package:flutter/material.dart';
import 'screens/number_input_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ttp App',
      theme: ThemeData(
        primaryColor: const Color(0xFF104382),
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF104382),
      ),
      themeMode: ThemeMode.system,
      home: const NumberInputPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
