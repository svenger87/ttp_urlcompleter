// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/pdf_service.dart';
import 'package:http/http.dart' as http;

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key});

  @override
  _PdfReaderPageState createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  Map<String, dynamic> _pdfs = {};

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    try {
      final pdfs = await PdfService.fetchPdfs('picklists');
      setState(() {
        _pdfs = pdfs;
      });
      if (kDebugMode) {
        print('Loaded PDFs: $_pdfs');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching PDFs: $e');
      }
    }
  }

  List<Widget> _buildFileList(Map<String, dynamic> files,
      [String parentPath = '']) {
    List<Widget> fileWidgets = [];

    files.forEach((key, value) {
      String fullPath = parentPath.isEmpty ? key : '$parentPath/$key';

      if (value is String) {
        // It's a file
        final isDone = key.startsWith('ERLEDIGT_');

        // Use Builder to detect current theme and apply appropriate color
        fileWidgets.add(
          Builder(
            builder: (context) {
              final isLightMode =
                  Theme.of(context).brightness == Brightness.light;

              return ListTile(
                title: Text(
                  key.replaceFirst('ERLEDIGT_', ''),
                  style: TextStyle(
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: isDone
                        ? Colors.grey
                        : isLightMode
                            ? Colors.black // Use black text for light mode
                            : Colors.white, // Use white text for dark mode
                  ),
                ),
                leading: Icon(
                  Icons.check_circle,
                  color: isDone ? Colors.green : Colors.transparent,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check),
                      color: isDone ? Colors.grey : Colors.green,
                      tooltip: isDone
                          ? 'Bereits als erledigt markiert'
                          : 'Als erledigt markieren',
                      onPressed: isDone ? null : () => _markPdfAsDone(fullPath),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      tooltip: 'PDF löschen',
                      onPressed: () => _deletePdf(fullPath),
                    ),
                  ],
                ),
                onTap: () {
                  if (kDebugMode) {
                    print('Tapped on PDF: $fullPath');
                  }
                  _openPdf(fullPath);
                },
              );
            },
          ),
        );
      } else if (value is Map<String, dynamic>) {
        // It's a folder, recursively build the list
        fileWidgets.add(
          Builder(
            builder: (context) {
              final isLightMode =
                  Theme.of(context).brightness == Brightness.light;

              return ExpansionTile(
                title: Text(
                  key,
                  style: TextStyle(
                    color: isLightMode ? Colors.black : Colors.white,
                  ),
                ),
                children: _buildFileList(value, fullPath),
              );
            },
          ),
        );
      }
    });

    return fileWidgets;
  }

  Future<void> _openPdf(String fullPath) async {
    try {
      final fileName = fullPath.split('/').last;
      final url =
          'http://wim-solution.sip.local:3001/api/pdf/picklists/$fullPath';
      if (kDebugMode) {
        print('Attempting to open PDF: $fullPath at URL: $url');
      }
      final encodedUrl = Uri.encodeFull(url); // Ensure URL is properly encoded
      final response = await http.get(Uri.parse(encodedUrl));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        // Pass the correct full path when opening the PDF viewer
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              filePath: file.path,
              fileName: fileName,
              originalPath: fullPath, // Store the original path
              onDelete: () => _deletePdf(fullPath),
              onMarkAsDone: () => _markPdfAsDone(fullPath),
              isDone: fileName.startsWith('ERLEDIGT_'),
            ),
          ),
        );

        if (result == true) {
          _loadPdfs();
        }
      } else {
        if (kDebugMode) {
          print('Error: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opening PDF: $e');
      }
    }
  }

  Future<void> _deletePdf(String fullPath) async {
    try {
      if (kDebugMode) {
        print('Attempting to delete PDF: $fullPath');
      }
      await PdfService.deletePdf('picklists', fullPath);
      setState(() {
        final keys = fullPath.split('/');
        Map<String, dynamic> currentLevel = _pdfs;
        for (int i = 0; i < keys.length - 1; i++) {
          currentLevel = currentLevel[keys[i]];
        }
        currentLevel.remove(keys.last);
      });
      if (kDebugMode) {
        print('Deleted PDF: $fullPath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting PDF: $e');
      }
    }
  }

  Future<void> _markPdfAsDone(String fullPath) async {
    try {
      final fileName = fullPath.split('/').last;
      if (fileName.startsWith('ERLEDIGT_')) {
        if (kDebugMode) {
          print('File is already marked as done: $fileName');
        }
        return;
      }

      if (kDebugMode) {
        print('Attempting to mark PDF as done: $fileName');
      }
      await PdfService.markPdfAsDone('picklists', fullPath);
      final doneFileName = 'ERLEDIGT_$fileName';

      setState(() {
        final keys = fullPath.split('/');
        Map<String, dynamic> currentLevel = _pdfs;
        for (int i = 0; i < keys.length - 1; i++) {
          currentLevel = currentLevel[keys[i]];
        }
        currentLevel[doneFileName] = currentLevel.remove(fileName);
      });

      _loadPdfs();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking PDF as done: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Picklistenmanagement'),
        backgroundColor: const Color(0xFF104382), // AppBar color
        titleTextStyle: const TextStyle(
          color: Colors.white, // Set the text color to white
          fontSize: 20, // Optionally adjust the font size
          fontWeight: FontWeight.bold, // Optionally adjust the font weight
        ),
      ),
      body: _pdfs.isNotEmpty
          ? ListView(
              children: _buildFileList(_pdfs),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String originalPath; // New variable to hold the original path
  final VoidCallback onDelete;
  final VoidCallback onMarkAsDone;
  final bool isDone;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.originalPath, // Pass the original path to this widget
    required this.onDelete,
    required this.onMarkAsDone,
    required this.isDone,
  });

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfDocument? _loadedDocument;
  Uint8List? _documentBytes;
  int _tappedPageNumber = 0;
  Offset _tappedOffset = Offset.zero;
  Offset? _offset;
  double? _zoomLevel;
  final double _circleSize = 30;
  bool _isDone = false;
  bool _isDeleted = false;

  @override
  void initState() {
    _isDone = widget.isDone;
    _getPdfBytes();
    super.initState();
  }

  Future<void> _getPdfBytes() async {
    try {
      _documentBytes = await File(widget.filePath).readAsBytes();
      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error reading PDF file: $e');
      }
    }
  }

  void _addCircle() async {
    if (_loadedDocument != null &&
        _tappedPageNumber > 0 &&
        _tappedPageNumber <= _loadedDocument!.pages.count) {
      final PdfPage page = _loadedDocument!.pages[_tappedPageNumber - 1];

      page.graphics.drawEllipse(
        Rect.fromLTWH(_tappedOffset.dx - _circleSize / 2,
            _tappedOffset.dy - _circleSize / 2, _circleSize, _circleSize),
        brush: PdfBrushes.green,
      );

      final List<int> bytes = await _loadedDocument!.save();
      setState(() {
        _documentBytes = Uint8List.fromList(bytes);
      });
    } else {
      if (kDebugMode) {
        print('Error: _loadedDocument is null or _tappedPageNumber is invalid');
      }
    }
  }

  Future<void> _savePdf() async {
    if (_loadedDocument != null) {
      try {
        // Save the modified PDF to a temporary location
        final List<int> bytes = await _loadedDocument!.save();
        final dir = await getTemporaryDirectory();
        final outputFile = File('${dir.path}/modified_${widget.fileName}');
        await outputFile.writeAsBytes(bytes, flush: true);
        if (kDebugMode) {
          print('PDF saved to: ${outputFile.path}');
        }

        // Use widget.originalPath for the correct relative path on the server
        String relativePath = widget.originalPath;

        if (kDebugMode) {
          print('Relative Path for upload: $relativePath');
        }

        // Upload the file using the original server path but the file from the temp directory
        await PdfService.uploadPdf('picklists', relativePath, outputFile);
        if (kDebugMode) {
          print('PDF uploaded to server: $relativePath');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving or uploading PDF: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('Error: _loadedDocument is null');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF104382),
        title: Text(widget.fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (!_isDeleted) {
              await _savePdf(); // Save and upload the PDF when navigating back
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: _isDone ? Colors.grey : Colors.green,
            onPressed: _isDone
                ? null
                : () async {
                    await _savePdf(); // Save and upload the PDF when marking as done
                    widget.onMarkAsDone();
                    setState(() {
                      _isDone = true;
                    });
                  },
            tooltip: 'Als erledigt markieren',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: _isDeleted ? Colors.grey : Colors.red,
            onPressed: _isDeleted
                ? null
                : () {
                    widget.onDelete();
                    setState(() {
                      _isDeleted = true;
                    });
                  },
            tooltip: 'PDF löschen',
          ),
        ],
      ),
      body: _documentBytes != null
          ? SfPdfViewer.memory(
              _documentBytes!,
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              initialZoomLevel: _zoomLevel ?? 1.0,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                _loadedDocument = details.document;

                if (_offset != null) {
                  _pdfViewerController.jumpTo(
                      xOffset: _offset!.dx, yOffset: _offset!.dy);
                }
              },
              onTap: (PdfGestureDetails details) {
                _offset = _pdfViewerController.scrollOffset;
                _tappedPageNumber = details.pageNumber;
                _tappedOffset = details.pagePosition;
                _zoomLevel = _pdfViewerController.zoomLevel;

                _addCircle();
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _loadedDocument?.dispose();
    super.dispose();
  }
}
