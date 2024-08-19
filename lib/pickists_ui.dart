import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fullFileName');

        await file.writeAsBytes(response.bodyBytes);

        // ignore: use_build_context_synchronously
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              filePath: file.path,
              fileName: fileName,
              onDelete: () => _deletePdf(fileName),
              onMarkAsDone: () => _markPdfAsDone(fileName),
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
      appBar: AppBar(title: const Text('PDF Reader')),
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
                  tooltip: isDone ? 'Already marked as done' : 'Mark as Done',
                  onPressed: isDone ? null : () => _markPdfAsDone(file),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Delete PDF',
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

class PdfViewerPage extends StatelessWidget {
  final String filePath;
  final String fileName;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsDone;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.onDelete,
    required this.onMarkAsDone,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('Opening PDF Viewer for: $fileName at path: $filePath');
    }
    final pdfController =
        PdfController(document: PdfDocument.openFile(filePath));

    final isDone = fileName.startsWith('ERLEDIGT_');

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context)
                .pop(false); // Simply go back without refreshing
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.green,
            onPressed: isDone
                ? null
                : () {
                    onMarkAsDone();
                    Navigator.of(context)
                        .pop(true); // Mark as done and refresh the list
                  },
            tooltip: isDone ? 'Already marked as done' : 'Mark as Done',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () {
              onDelete();
              Navigator.of(context).pop(true); // Delete and refresh the list
            },
            tooltip: 'Delete PDF',
          ),
        ],
      ),
      body: PdfView(controller: pdfController),
    );
  }
}
