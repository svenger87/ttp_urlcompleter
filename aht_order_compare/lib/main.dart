import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'constants/constants.dart';

const String apiUrl = kApiUrl;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Comparison Tool',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PDFComparisonScreen(),
    );
  }
}

class PDFComparisonScreen extends StatefulWidget {
  const PDFComparisonScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PDFComparisonScreenState createState() => _PDFComparisonScreenState();
}

class _PDFComparisonScreenState extends State<PDFComparisonScreen> {
  File? ahtPdf;
  File? sapPdf;
  Map<String, dynamic>? comparisonResult;
  bool isLoading = false;

  Future<void> pickPdf(bool isAht) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        if (isAht) {
          ahtPdf = File(result.files.single.path!);
        } else {
          sapPdf = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> comparePdfs() async {
    if (ahtPdf == null || sapPdf == null) {
      setState(() {
        comparisonResult = {'error': 'Bitte beide PDFs hochladen'};
      });
      return;
    }

    setState(() {
      isLoading = true; // Show loading indicator
    });

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(apiUrl),
    );
    request.files
        .add(await http.MultipartFile.fromPath('aht_file', ahtPdf!.path));
    request.files
        .add(await http.MultipartFile.fromPath('sap_file', sapPdf!.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = jsonDecode(await response.stream.bytesToString());
      setState(() {
        comparisonResult = responseData;
      });
    } else {
      setState(() {
        comparisonResult = {'error': 'Vergleich fehlgeschlagen'};
      });
    }

    setState(() {
      isLoading = false; // Hide loading indicator
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Vergleich")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => pickPdf(true),
              icon: Image.asset('assets/images/AHT.png', width: 24, height: 24),
              label: Text(ahtPdf == null
                  ? "AHT Lieferplanabruf auswählen"
                  : "AHT PDF geladen"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => pickPdf(false),
              icon: Image.asset('assets/images/SAP.png', width: 24, height: 24),
              label: Text(sapPdf == null
                  ? "SAP Lieferplanbestätigung auswählen"
                  : "SAP PDF geladen"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : comparePdfs, // Disable button while loading
              icon: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compare),
              label: const Text("Vergleich starten"),
            ),
            const SizedBox(height: 20),
            comparisonResult != null ? buildComparisonTable() : Container(),
          ],
        ),
      ),
    );
  }

  Widget buildComparisonTable() {
    if (comparisonResult == null || comparisonResult!.containsKey('error')) {
      return Text(
        comparisonResult?['error'] ?? 'Fehler beim Vergleich',
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    }

    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FractionColumnWidth(0.2),
        1: FractionColumnWidth(0.13),
        2: FractionColumnWidth(0.13),
        3: FractionColumnWidth(0.13),
      },
      children: [
        buildRow(
            "Kriterium", "AHT Lieferplan", "SAP Bestätigung", "Übereinstimmung",
            isHeader: true),
        buildRow(
            "Bestellnummer",
            comparisonResult!["Bestellnummer AHT"],
            comparisonResult!["Bestellnummer SAP"],
            matchIndicator(comparisonResult!["Bestellnummer Match"])),
        buildRow(
            "Liefertermin",
            comparisonResult!["Liefertermin AHT"],
            comparisonResult!["Liefertermin SAP"],
            matchIndicator(comparisonResult!["Liefertermin Match"])),
        buildRow(
            "Menge (Stück)",
            comparisonResult!["Eingeteilte Menge AHT"].toString(),
            comparisonResult!["Berechnete Eingeteilte Menge SAP"].toString(),
            matchIndicator(comparisonResult!["Eingeteilte Menge Match"])),
        buildRow(
            "Menge (Meter)",
            comparisonResult!["Converted Menge (M)"].toString(),
            comparisonResult!["Menge SAP (M)"].toString(),
            matchIndicator(comparisonResult!["Menge Match"])),
      ],
    );
  }

  TableRow buildRow(
      String title, String? ahtValue, String? sapValue, String matchValue,
      {bool isHeader = false}) {
    return TableRow(
      children: [
        buildCell(title, isHeader: isHeader),
        buildCell(ahtValue ?? "-", isHeader: isHeader),
        buildCell(sapValue ?? "-", isHeader: isHeader),
        buildCell(matchValue, isHeader: isHeader),
      ],
    );
  }

  Widget buildCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 16 : 14,
        ),
      ),
    );
  }

  /// Returns a ✅ or ❌ based on match boolean
  String matchIndicator(bool? isMatch) {
    if (isMatch == null) return "-";
    return isMatch ? "✅ Ja" : "❌ Nein";
  }
}
