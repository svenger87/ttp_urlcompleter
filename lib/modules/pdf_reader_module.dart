import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path; // Import for extracting file names
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFReaderModule extends StatefulWidget {
  final String pdfUrl;

  const PDFReaderModule({super.key, required this.pdfUrl});

  @override
  // ignore: library_private_types_in_public_api
  _PDFReaderModuleState createState() => _PDFReaderModuleState();
}

class _PDFReaderModuleState extends State<PDFReaderModule> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _localPdfPath;
  String _fileName = "PDF Viewer"; // Default title
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _downloadAndOpenPdf();
  }

  Future<void> _downloadAndOpenPdf() async {
    try {
      // Download the PDF from the provided URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      if (response.statusCode == 200) {
        // Get the cache directory for storing the downloaded PDF
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/temp_pdf.pdf';

        // Save the downloaded PDF to the cache directory
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Extract the filename from the URL
        String fileNameWithExtension = path.basename(widget.pdfUrl);

        // Remove the extension from the filename
        String fileNameWithoutExtension =
            path.basenameWithoutExtension(fileNameWithExtension);

        // Set the path for the loaded PDF and update the AppBar title
        setState(() {
          _localPdfPath = filePath;
          _fileName =
              fileNameWithoutExtension; // Update the AppBar title dynamically
          _isLoading = false;
        });
      } else {
        // If the server response is not successful, set the error state
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors that occur during the download and opening process
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Error loading PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName),
        backgroundColor: const Color(
            0xFF104382), // Display the dynamically updated file name
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              _pdfViewerKey.currentState?.openBookmarkView();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Failed to load PDF.'))
              : SfPdfViewer.file(
                  File(_localPdfPath!),
                  key: _pdfViewerKey,
                  enableDocumentLinkAnnotation: true,
                  canShowHyperlinkDialog: true,
                ),
    );
  }
}
