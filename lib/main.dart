import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WIM Profilnummer',
      theme: ThemeData(
        primaryColor: Color(0xFF104382), // Set the primary color
        primarySwatch: Colors.blue,
      ),
      home: const NumberInputPage(),
    );
  }
}

class NumberInputPage extends StatefulWidget {
  const NumberInputPage({Key? key}) : super(key: key);

  @override
  _NumberInputPageState createState() => _NumberInputPageState();
}

class _NumberInputPageState extends State<NumberInputPage> {
  final TextEditingController _numberController = TextEditingController();

  void _openUrlWithNumber() async {
    final String number = _numberController.text;
    final url = 'http://wim-solution.sip.local:8081/$number';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Konnte nicht starten $url');
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/leuchtturm.png'), // Replace with your logo asset
        ),
        title: const Text('WIM Profilnummer'),
        backgroundColor: Theme.of(context).primaryColor, // Set app bar color
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Profilnummer eingeben'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _openUrlWithNumber,
                style: ElevatedButton.styleFrom(
                  primary: Theme.of(context).primaryColor, // Set button color
                ),
                child: const Text('Profilverzeichnis öffnen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
