import 'package:flutter/foundation.dart'; // Ensure this import is present
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';

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
      List<int> uploadedFileIds = [];

      // Upload attachments if any
      for (var file in selectedFiles) {
        int uploadedFileId = await ApiService.uploadAttachment(file.path!);
        uploadedFileIds.add(uploadedFileId); // Save uploaded file ID
      }

      // Prepare the comment data
      Map<String, dynamic> commentData = {
        'body': commentText,
        'attach_uploaded_files': uploadedFileIds, // Include uploaded files' IDs
      };

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

      // Refresh comments
      List<Map<String, dynamic>> updatedComments;
      if (widget.taskId != null) {
        updatedComments =
            await ApiService.fetchCommentsForTask(taskId: widget.taskId!);
      } else {
        updatedComments = await ApiService.fetchCommentsForProject(
            projectId: widget.projectId);
      }

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
                                    return GestureDetector(
                                      onTap: () {
                                        // Handle attachment click, e.g., open PDF or download
                                        print(
                                            'Opening attachment: ${attachment['download_url']}');
                                      },
                                      child: Chip(
                                        label: Text(attachment['name']),
                                        avatar: const Icon(Icons.attachment),
                                      ),
                                    );
                                  }),
                                ),
                            ],
                          ),
                          trailing: Text(
                            DateTime.fromMillisecondsSinceEpoch(
                                    comment['created_on'] * 1000)
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
