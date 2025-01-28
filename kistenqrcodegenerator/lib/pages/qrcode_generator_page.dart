// lib/pages/qrcode_generator_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // TypeAhead
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:qr/qr.dart';
import '../models/profile.dart';
import '../services/api_service.dart'; // your API service
// import '../constants/constants.dart'; // only if needed

class QrCodeGeneratorPage extends StatefulWidget {
  const QrCodeGeneratorPage({super.key});

  @override
  State<QrCodeGeneratorPage> createState() => _QrCodeGeneratorPageState();
}

class _QrCodeGeneratorPageState extends State<QrCodeGeneratorPage> {
  // CSV-related fields
  String? csvFilePath;
  String? outputDirectory;
  double progressValue = 0;
  String statusMessage = "";
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      // In your service, fetch everything (maybe pass an empty query or itemsPerPage=9999)
      final profiles = await apiService.fetchAllProfiles();
      setState(() {
        apiProfiles = profiles;
      });
    } catch (e) {
      // handle error
    }
  }

  // API-related fields
  bool isUsingApi = true; // Default to API
  final ApiService apiService = ApiService();
  List<Profile> apiProfiles =
      []; // If you do local filtering, hold all profiles here
  List<Profile> selectedProfiles = [];

  // Controller for CSV TextFormField
  final TextEditingController _csvController = TextEditingController();

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kisten QR Code Generator"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle between CSV and API
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("CSV"),
                  Switch(
                    value: isUsingApi,
                    onChanged: (value) {
                      setState(() {
                        isUsingApi = value;
                        if (isUsingApi) {
                          // Reset CSV
                          csvFilePath = null;
                          _csvController.clear();
                          // Reset selected
                          selectedProfiles.clear();
                        } else {
                          // Reset API
                          apiProfiles.clear();
                          selectedProfiles.clear();
                        }
                      });
                    },
                  ),
                  const Text("API"),
                ],
              ),
              const SizedBox(height: 20),

              // Conditional UI
              isUsingApi ? _buildApiSection() : _buildCsvSection(),

              const SizedBox(height: 20),

              // Show selected profiles (only for API mode)
              if (isUsingApi) _buildSelectedProfilesSection(),

              const SizedBox(height: 40),

              // Generate button
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
      ),
    );
  }

  /// 1) CSV UI
  Widget _buildCsvSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          readOnly: true,
          decoration: const InputDecoration(
            labelText: "QR CSV Datei auswählen",
          ),
          controller: _csvController,
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
                _csvController.text =
                    csvFilePath != null ? p.basename(csvFilePath!) : "";
                statusMessage =
                    "CSV-Datei ausgewählt: ${p.basename(csvFilePath!)}";
              });
            }
          },
          child: const Text("Durchsuchen"),
        ),
      ],
    );
  }

  /// 2) API + TypeAhead UI
  Widget _buildApiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<Profile>(
          onSelected: (Profile suggestion) {
            if (!selectedProfiles.contains(suggestion)) {
              setState(() {
                selectedProfiles.add(suggestion);
                statusMessage =
                    "${selectedProfiles.length} Profile ausgewählt.";
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil bereits ausgewählt.'),
                ),
              );
            }
          },
          suggestionsCallback: (pattern) async {
            if (pattern.trim().isEmpty) {
              return [];
            }
            final lower = pattern.trim().toLowerCase();
            return apiProfiles.where((profile) {
              return profile.title.toLowerCase().contains(lower) ||
                  profile.shortUrl.toLowerCase().contains(lower);
            }).toList();
          },
          itemBuilder: (context, Profile suggestion) {
            return ListTile(
              title: Text(suggestion.title),
              subtitle: Text(suggestion.shortUrl),
            );
          },
          builder: (context, textEditingController, focusNode) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: "Profil suchen",
                hintText: "Geben Sie einen Suchbegriff ein",
                prefixIcon: Icon(Icons.search),
              ),
              onTap: () async {
                if (apiProfiles.isEmpty) {
                  await _loadProfiles();
                }
              },
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          selectedProfiles.isNotEmpty
              ? "${selectedProfiles.length} Profile ausgewählt."
              : "Keine Profile ausgewählt.",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selectedProfiles.isNotEmpty ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  /// 3) Show selected profiles & allow deleting them
  Widget _buildSelectedProfilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Ausgewählte Profile:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        selectedProfiles.isNotEmpty
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedProfiles.length,
                itemBuilder: (context, index) {
                  final profile = selectedProfiles[index];
                  return Card(
                    child: ListTile(
                      title: Text(profile.title),
                      subtitle: Text(profile.shortUrl),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            selectedProfiles.removeAt(index);
                            statusMessage =
                                "${selectedProfiles.length} Profile ausgewählt.";
                          });
                        },
                      ),
                    ),
                  );
                },
              )
            : const Text(
                "Keine Profile ausgewählt.",
                style: TextStyle(color: Colors.red),
              ),
      ],
    );
  }

  /// 4) Generate QR Codes (CSV or API)
  Future<void> _generateQrCodes() async {
    if (outputDirectory == null) {
      // Ask user to select output directory
      String? selectedDir = await FilePicker.platform.getDirectoryPath();
      if (selectedDir != null) {
        setState(() {
          outputDirectory = selectedDir;
        });
      } else {
        setState(() {
          statusMessage = "Bitte ein Ausgabeverzeichnis auswählen.";
        });
        return;
      }
    }

    List<Map<String, dynamic>> dataRows = [];

    if (isUsingApi) {
      if (selectedProfiles.isEmpty) {
        setState(() {
          statusMessage = "Bitte wählen Sie mindestens ein Profil aus.";
        });
        return;
      }

      dataRows = selectedProfiles.map((profile) {
        return {
          'shortUrl': profile.shortUrl,
          'title': profile.title,
        };
      }).toList();
    } else {
      // CSV path
      if (csvFilePath == null) {
        setState(() {
          statusMessage = "Bitte eine CSV-Datei auswählen.";
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

      // Read CSV
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

      // Check CSV headers
      final headers = csvTable.first;
      final shortUrlIndex = headers.indexOf('shortUrl');
      final titleIndex = headers.indexOf('title');
      if (shortUrlIndex < 0 || titleIndex < 0) {
        setState(() {
          statusMessage = "CSV-Header müssen 'shortUrl' und 'title' enthalten.";
        });
        return;
      }

      final dataRowsRaw = csvTable.sublist(1);
      if (dataRowsRaw.isEmpty) {
        setState(() {
          statusMessage = "Keine Datenzeilen gefunden.";
        });
        return;
      }

      dataRows = dataRowsRaw.map((row) {
        return {
          'shortUrl': row[shortUrlIndex].toString(),
          'title': row[titleIndex].toString(),
        };
      }).toList();
    }

    if (dataRows.isEmpty) {
      setState(() {
        statusMessage = "Keine gültigen Daten zum Generieren gefunden.";
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

    setState(() {
      isGenerating = true;
      progressValue = 0;
      statusMessage = "Erstelle QR Codes...";
    });

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      String shortUrl = row['shortUrl']?.toString() ?? '';
      String title = row['title']?.toString() ?? '';

      if (shortUrl.isEmpty || title.isEmpty) {
        continue;
      }

      shortUrl = encodeSpacesInUrl(shortUrl);

      final safeFilename = sanitizeFilename(title);
      final svgPath = p.join(outputDirectory!, "$safeFilename.svg");

      try {
        final svgContent = generateQrSvgWithText(
          shortUrl: shortUrl,
          title: title,
        );
        final outFile = File(svgPath);
        await outFile.writeAsString(svgContent);
      } catch (e) {
        debugPrint("Fehler bei der QR-Code-Erstellung für $title: $e");
      }

      setState(() {
        progressValue = (i + 1) / dataRows.length;
      });

      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() {
      isGenerating = false;
      statusMessage =
          "QR Codes generiert und im Ausgabeverzeichnis gespeichert. Erledigt!";
    });
  }

  // Helpers

  String encodeSpacesInUrl(String url) {
    return url.replaceAll(' ', '%20');
  }

  String sanitizeFilename(String filename) {
    final illegalReg = RegExp(r'[<>:"/\\|?*]');
    return filename.replaceAll(illegalReg, '_');
  }

  String generateQrSvgWithText({
    required String shortUrl,
    required String title,
  }) {
    final displayText = getFirstWord(title);

    final qrCode = QrCode.fromData(
      data: shortUrl,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrCode.moduleCount;

    const pixelSize = 10;
    const margin = 20;
    const fontSize = 40;

    final totalSize = moduleCount * pixelSize;
    final fullWidth = totalSize + margin * 2;
    final fullHeight = totalSize + margin * 2 + fontSize + 10;
    final centerX = fullWidth / 2;
    final centerY = fullHeight / 2;

    final buffer = StringBuffer();
    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        final isDark = qrImage.isDark(r, c);
        if (isDark) {
          final x = c * pixelSize + margin;
          final y = r * pixelSize + margin;
          buffer.writeln(
              '<rect x="$x" y="$y" width="$pixelSize" height="$pixelSize" fill="#000000" />');
        }
      }
    }

    final textX = fullWidth / 2;
    final textY = totalSize + margin + fontSize;

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

  String getFirstWord(String text) {
    if (text.trim().isEmpty) return text;
    return text.split(' ').first;
  }
}
