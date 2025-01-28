import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

// Import the newer QR library
import 'package:qr/qr.dart';

void main() {
  runApp(const MyApp());
}

/// Root widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisten QR Code Generator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QrCodeGeneratorPage(),
    );
  }
}

/// The main UI page
class QrCodeGeneratorPage extends StatefulWidget {
  const QrCodeGeneratorPage({super.key});

  @override
  State<QrCodeGeneratorPage> createState() => _QrCodeGeneratorPageState();
}

class _QrCodeGeneratorPageState extends State<QrCodeGeneratorPage> {
  String? csvFilePath;
  String? outputDirectory;
  double progressValue = 0;
  String statusMessage = "";

  bool isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kisten QR Code Generator"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) CSV file chooser
            TextFormField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "QR CSV Datei auswählen",
              ),
              controller: TextEditingController(text: csvFilePath ?? ""),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                );
                if (result != null && result.files.isNotEmpty) {
                  setState(() {
                    csvFilePath = result.files.single.path;
                  });
                }
              },
              child: const Text("Durchsuchen"),
            ),

            const SizedBox(height: 20),

            // 2) Output folder chooser
            TextFormField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Ausgabeverzeichnis auswählen",
              ),
              controller: TextEditingController(text: outputDirectory ?? ""),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () async {
                String? selectedDir =
                    await FilePicker.platform.getDirectoryPath();
                if (selectedDir != null) {
                  setState(() {
                    outputDirectory = selectedDir;
                  });
                }
              },
              child: const Text("Durchsuchen"),
            ),

            const SizedBox(height: 40),

            // 3) Generate button
            ElevatedButton(
              onPressed: isGenerating ? null : _generateQrCodes,
              child: const Text("Kisten QR Codes erstellen"),
            ),

            const SizedBox(height: 20),

            // Progress
            LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(statusMessage),
          ],
        ),
      ),
    );
  }

  /// Called when "Kisten QR Codes erstellen" is pressed
  Future<void> _generateQrCodes() async {
    // 1) Validate input selections
    if (csvFilePath == null || outputDirectory == null) {
      setState(() {
        statusMessage = "Bitte Ein- und Ausgabeverzeichnis auswählen.";
      });
      return;
    }

    final inputFile = File(csvFilePath!);
    if (!await inputFile.exists()) {
      setState(() {
        statusMessage = "Die ausgewählte CSV-Datei existiert nicht.";
      });
      return;
    }

    final outputDir = Directory(outputDirectory!);
    if (!await outputDir.exists()) {
      setState(() {
        statusMessage = "Das ausgewählte Ausgabeverzeichnis existiert nicht.";
      });
      return;
    }

    // 2) Read CSV
    List<List<dynamic>> csvTable;
    try {
      final csvString = await inputFile.readAsString();
      csvTable = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvString, eol: "\n");
    } catch (e) {
      setState(() {
        statusMessage = "Fehler beim Lesen der CSV-Datei: $e";
      });
      return;
    }

    if (csvTable.isEmpty) {
      setState(() {
        statusMessage = "Die CSV-Datei ist leer.";
      });
      return;
    }

    // 3) Check CSV headers
    final headers = csvTable.first;
    final shortUrlIndex = headers.indexOf('shortUrl');
    final titleIndex = headers.indexOf('title');
    if (shortUrlIndex < 0 || titleIndex < 0) {
      setState(() {
        statusMessage = "CSV-Header müssen 'shortUrl' und 'title' enthalten.";
      });
      return;
    }

    final dataRows = csvTable.sublist(1);
    if (dataRows.isEmpty) {
      setState(() {
        statusMessage = "Keine Datenzeilen gefunden.";
      });
      return;
    }

    // 4) Generate QR codes
    setState(() {
      isGenerating = true;
      progressValue = 0;
      statusMessage = "Erstelle QR Codes...";
    });

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      // Safeguard: check row length
      if (row.length <= shortUrlIndex || row.length <= titleIndex) {
        continue;
      }
      // Prepare data
      String shortUrl = row[shortUrlIndex].toString();
      String title = row[titleIndex].toString();

      // Encode spaces
      shortUrl = encodeSpacesInUrl(shortUrl);

      // Build an output path (SVG file named after the sanitized title)
      final safeTitle = sanitizeFilename(title);
      final svgPath = p.join(outputDirectory!, "$safeTitle.svg");

      try {
        // Generate an SVG for each row
        final svgContent = generateQrSvgWithText(
          shortUrl: shortUrl,
          title: title,
        );
        // Write the file
        final outFile = File(svgPath);
        await outFile.writeAsString(svgContent);
      } catch (e) {
        debugPrint("Fehler bei der QR-Code-Erstellung: $e");
      }

      // 5) Update progress
      setState(() {
        progressValue = (i + 1) / dataRows.length;
      });

      // Let UI breathe slightly
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() {
      isGenerating = false;
      statusMessage =
          "QR Codes generiert und im Ausgabeverzeichnis gespeichert. Erledigt!";
    });
  }
}

/// Replace spaces with %20
String encodeSpacesInUrl(String url) {
  return url.replaceAll(' ', '%20');
}

/// Sanitize filename by removing characters not allowed on Windows, etc.
String sanitizeFilename(String filename) {
  final illegalReg = RegExp(r'[<>:"/\\|?*]');
  return filename.replaceAll(illegalReg, '_');
}

/// Return the first word before a space
String getFirstWord(String text) {
  if (text.trim().isEmpty) return text;
  return text.split(' ').first;
}

/// Generate an SVG containing the QR code and some text, then rotate it 180°.
String generateQrSvgWithText({
  required String shortUrl,
  required String title,
}) {
  final displayText = getFirstWord(title);

  // 1) Create the QR code
  final qrCode = QrCode.fromData(
    data: shortUrl,
    errorCorrectLevel: QrErrorCorrectLevel.L,
  );

  // 2) Create a QrImage to access module data
  final qrImage = QrImage(qrCode);

  // 3) Retrieve the module count
  final moduleCount = qrCode.moduleCount;

  // 4) Basic layout constants
  const pixelSize = 10; // each QR cell is 10x10 SVG units
  const margin = 20; // extra spacing
  const fontSize = 40; // text size

  final totalSize = moduleCount * pixelSize;
  final fullWidth = totalSize + margin * 2;
  final fullHeight = totalSize + margin * 2 + fontSize + 10;

  // We'll rotate 180 degrees about the center
  final centerX = fullWidth / 2;
  final centerY = fullHeight / 2;

  // 5) Build SVG rectangles for each dark cell
  final buffer = StringBuffer();
  for (int r = 0; r < moduleCount; r++) {
    for (int c = 0; c < moduleCount; c++) {
      final isDark = qrImage.isDark(r, c); // Check if the module is dark
      if (isDark) {
        final x = c * pixelSize + margin;
        final y = r * pixelSize + margin;
        buffer.writeln(
            '<rect x="$x" y="$y" width="$pixelSize" height="$pixelSize" fill="#000000" />');
      }
    }
  }

  // 6) Position the text below the code
  final textX = fullWidth / 2;
  final textY = totalSize + margin + fontSize;

  // 7) Combine into an SVG string, with rotation transform
  final svg = '''
<svg width="$fullWidth" height="$fullHeight" version="1.1"
     xmlns="http://www.w3.org/2000/svg">
  <g transform="translate($centerX, $centerY) rotate(180) translate(${-centerX}, ${-centerY})">
    $buffer
    <text x="$textX" y="$textY"
          font-size="$fontSize"
          text-anchor="middle"
          fill="#000000"
          font-family="Arial, sans-serif">$displayText</text>
  </g>
</svg>
''';

  return svg;
}
