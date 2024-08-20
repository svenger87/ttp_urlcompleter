// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pdf_service.dart';
import 'package:http/http.dart' as http;

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key});

  @override
  _PdfReaderPageState createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  List<String> _pdfs = [];

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

  Future<void> _openPdf(String fileName) async {
    try {
      final fullFileName =
          fileName.startsWith('ERLEDIGT_') ? fileName : fileName;
      final url =
          'http://wim-solution.sip.local:3001/api/pdf/picklists/$fullFileName';
      if (kDebugMode) {
        print('Attempting to open PDF: $fullFileName at URL: $url');
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fullFileName');

        await file.writeAsBytes(response.bodyBytes);

        // Use build context synchronously
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              filePath: file.path,
              fileName: fileName,
              onDelete: () => _deletePdf(fileName),
              onMarkAsDone: () => _markPdfAsDone(fileName),
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

  Future<void> _deletePdf(String fileName) async {
    try {
      if (kDebugMode) {
        print('Attempting to delete PDF: $fileName');
      }
      await PdfService.deletePdf('picklists', fileName);
      setState(() {
        _pdfs.remove(fileName);
      });
      if (kDebugMode) {
        print('Deleted PDF: $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting PDF: $e');
      }
    }
  }

  Future<void> _markPdfAsDone(String fileName) async {
    try {
      if (fileName.startsWith('ERLEDIGT_')) {
        if (kDebugMode) {
          print('File is already marked as done: $fileName');
        }
        return; // Exit early if the file is already marked as done
      }

      if (kDebugMode) {
        print('Attempting to mark PDF as done: $fileName');
      }
      await PdfService.markPdfAsDone('picklists', fileName);
      final doneFileName = 'ERLEDIGT_$fileName';

      setState(() {
        int index = _pdfs.indexOf(fileName);
        if (index != -1) {
          _pdfs[index] = doneFileName;
          if (kDebugMode) {
            print('Updated local list: $_pdfs');
          }
        }
      });

      _loadPdfs(); // Reload the PDFs to reflect the change
    } catch (e) {
      if (kDebugMode) {
        print('Error marking PDF as done: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Picklistenmanagement')),
      body: ListView.builder(
        itemCount: _pdfs.length,
        itemBuilder: (context, index) {
          final file = _pdfs[index];
          final isDone = file.startsWith('ERLEDIGT_');
          if (kDebugMode) {
            print('Displaying PDF: $file (Is Done: $isDone)');
          }

          return ListTile(
            title: Text(
              file.replaceFirst('ERLEDIGT_', ''),
              style: TextStyle(
                decoration:
                    isDone ? TextDecoration.lineThrough : TextDecoration.none,
                color: isDone ? Colors.grey : Colors.white,
              ),
            ),
            leading: Icon(
              Icons.check_circle,
              color: isDone
                  ? Colors.green
                  : Colors.transparent, // Show green check if done
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
                  onPressed: isDone ? null : () => _markPdfAsDone(file),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'PDF löschen',
                  onPressed: () => _deletePdf(file),
                ),
              ],
            ),
            onTap: () {
              if (kDebugMode) {
                print('Tapped on PDF: $file');
              }
              _openPdf(file); // Open the PDF when the ListTile is tapped
            },
          );
        },
      ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsDone;
  final bool isDone;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
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
  bool _isDone = false; // Track if the PDF is marked as done
  bool _isDeleted = false; // Track if the PDF is deleted

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
        final List<int> bytes = await _loadedDocument!.save();
        final dir = await getTemporaryDirectory();
        final outputFile = File('${dir.path}/modified_${widget.fileName}');
        await outputFile.writeAsBytes(bytes, flush: true);
        if (kDebugMode) {
          print('PDF saved to: ${outputFile.path}');
        }
        await PdfService.uploadPdf('picklists', widget.fileName, outputFile);
        if (kDebugMode) {
          print('PDF uploaded to server: ${widget.fileName}');
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
