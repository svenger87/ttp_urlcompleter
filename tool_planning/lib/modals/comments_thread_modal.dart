import 'package:flutter/foundation.dart'; // Ensure this import is present
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class CommentsThreadModal extends StatefulWidget {
  final List<Map<String, dynamic>> comments;
  final int projectId;
  final int? taskId;

  const CommentsThreadModal({
    super.key,
    required this.comments,
    required this.projectId,
    this.taskId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CommentsThreadModalState createState() => _CommentsThreadModalState();
}

class _CommentsThreadModalState extends State<CommentsThreadModal> {
  List<Map<String, dynamic>> comments = [];
  TextEditingController commentController = TextEditingController();
  bool isLoading = false;
  List<PlatformFile> selectedFiles = [];
  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    comments = widget.comments;
  }

  Future<void> _addComment() async {
    String commentText = commentController.text.trim();
    if (commentText.isEmpty && selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kommentar oder Anhang erforderlich')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      List<String> uploadedFileCodes = [];

      // Upload attachments if any
      for (var file in selectedFiles) {
        if (file.path != null) {
          // Upload each file and get the file code (make it nullable String?)
          String? uploadedFileCode =
              await ApiService.uploadAttachment(file.path!);

          if (uploadedFileCode != null) {
            uploadedFileCodes
                .add(uploadedFileCode); // Store the uploaded file code
          } else {
            throw Exception('Failed to upload file: ${file.name}');
          }
        } else {
          throw Exception('Dateipfad ist null für Datei: ${file.name}');
        }
      }

      print('Uploaded File Codes: $uploadedFileCodes');

      // Prepare the comment data with the uploaded file codes
      Map<String, dynamic> commentData = {
        'body': commentText,
        'attach_uploaded_files':
            uploadedFileCodes, // List of uploaded file codes
      };

      print('Comment Data: $commentData');

      // Add comment via API
      if (widget.taskId != null) {
        await ApiService.addCommentToTask(
          taskId: widget.taskId!,
          commentData: commentData,
        );
      } else {
        await ApiService.addCommentToProject(
          projectId: widget.projectId,
          commentData: commentData,
        );
      }

      // Update the comments
      List<Map<String, dynamic>> updatedComments;
      if (widget.taskId != null) {
        updatedComments =
            await ApiService.fetchCommentsForTask(taskId: widget.taskId!);
      } else {
        updatedComments = await ApiService.fetchCommentsForProject(
            projectId: widget.projectId);
      }

      print('Fetched Updated Comments: $updatedComments');

      setState(() {
        comments = updatedComments;
        commentController.clear();
        selectedFiles.clear();
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kommentar erfolgreich hinzugefügt')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error adding comment: $e');
      }
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Hinzufügen des Kommentars')),
      );
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        selectedFiles = result.files;
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        selectedFiles.add(PlatformFile(
          name: photo.name,
          path: photo.path,
          size: File(photo.path).lengthSync(),
        ));
      });
    }
  }

  // Helper function to open images
  void _openImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
      ),
    );
  }

  // Helper function to open PDFs
  void _openPDF(String pdfUrl, String fileName) async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Download PDF
      var response = await http.get(Uri.parse(pdfUrl));
      var dir = await getApplicationDocumentsDirectory();
      File file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      // Dismiss loading indicator
      Navigator.pop(context);

      // Navigate to PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(filePath: file.path),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Öffnen der PDF: $e')),
      );
    }
  }

  // Helper function to open other files externally
  void _openFileExternally(String url) async {
    Uri fileUri = Uri.parse(url);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte die Datei nicht öffnen')),
      );
    }
  }

  // Widget to build attachment chips with appropriate icons and handlers
  Widget _buildAttachmentChip(Map<String, dynamic> attachment) {
    String mimeType = attachment['mime_type'] ?? '';
    String downloadUrl = attachment['download_url'] ?? '';
    String name = attachment['name'] ?? 'Datei';
    IconData iconData;

    if (mimeType.startsWith('image/')) {
      iconData = Icons.image;
    } else if (mimeType == 'application/pdf') {
      iconData = Icons.picture_as_pdf;
    } else {
      iconData = Icons.insert_drive_file;
    }

    return GestureDetector(
      onTap: () {
        if (mimeType.startsWith('image/')) {
          _openImage(downloadUrl);
        } else if (mimeType == 'application/pdf') {
          _openPDF(downloadUrl, name);
        } else {
          _openFileExternally(downloadUrl);
        }
      },
      child: Chip(
        label: Text(name),
        avatar: Icon(iconData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kommentare'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height *
            0.7, // Adjust the height as needed
        child: Column(
          children: [
            Expanded(
              child: comments.isEmpty
                  ? const Center(child: Text('Keine Kommentare verfügbar'))
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          title: Text(
                            comment['created_by_name'] ??
                                'Unbekannter Benutzer',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment['body_plain_text'] ??
                                  'Kein Inhalt verfügbar'),
                              const SizedBox(height: 5),
                              if (comment['attachments'] != null &&
                                  comment['attachments'].isNotEmpty)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: List.generate(
                                      comment['attachments'].length,
                                      (attachmentIndex) {
                                    final attachment =
                                        comment['attachments'][attachmentIndex];
                                    return _buildAttachmentChip(attachment);
                                  }),
                                ),
                            ],
                          ),
                          trailing: Text(
                            DateTime.fromMillisecondsSinceEpoch(
                                    (comment['created_on'] ?? 0) * 1000)
                                .toLocal()
                                .toString()
                                .substring(0, 10), // Convert timestamp to date
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Neuen Kommentar hinzufügen',
              ),
              maxLines: null,
            ),
            const SizedBox(height: 10),
            if (selectedFiles.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: selectedFiles.map((file) {
                  return Chip(
                    label: Text(file.name),
                    onDeleted: () {
                      setState(() {
                        selectedFiles.remove(file);
                      });
                    },
                  );
                }).toList(),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Anhang hinzufügen'),
                ),
                TextButton.icon(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Foto aufnehmen'),
                ),
                const Spacer(),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _addComment,
                        child: const Text('Absenden'),
                      ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}

// Image Viewer Screen
class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bild anzeigen'),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
      ),
    );
  }
}

// PDF Viewer Screen
class PDFViewerScreen extends StatelessWidget {
  final String filePath;

  const PDFViewerScreen({Key? key, required this.filePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF anzeigen'),
      ),
      body: PDFView(
        filePath: filePath,
      ),
    );
  }
}
