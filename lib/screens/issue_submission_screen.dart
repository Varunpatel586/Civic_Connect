import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/UpvoteButton.dart';
import '../services/api_client.dart';

class IssueSubmissionScreen extends StatefulWidget {
  final File initialImage;
  final double? latitude;
  final double? longitude;
  final String?
  issueId; // Add this to receive issue ID if editing existing issue

  const IssueSubmissionScreen({
    Key? key,
    required this.initialImage,
    this.latitude,
    this.longitude,
    this.issueId, // Add this parameter
  }) : super(key: key);

  @override
  _IssueSubmissionScreenState createState() => _IssueSubmissionScreenState();
}

class _IssueSubmissionScreenState extends State<IssueSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'pothole';
  final List<File> _additionalImages = [];
  bool _isSubmitting = false;
  final ApiClient _apiClient = ApiClient();
  int _upvoteCount = 0; // Add upvote count state
  bool _hasUpvoted = false; // Add upvote state

  final List<Map<String, String>> _categories = [
    {'value': 'pothole', 'label': 'Pothole'},
    {'value': 'street_light', 'label': 'Street Light'},
    {'value': 'water', 'label': 'Water Supply'},
    {'value': 'electricity', 'label': 'Electricity'},
    {'value': 'garbage', 'label': 'Garbage'},
    {'value': 'road', 'label': 'Road Damage'},
    {'value': 'drainage', 'label': 'Drainage'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    // If we have an issueId, fetch the existing data
    if (widget.issueId != null) {
      _fetchIssueData();
    }
  }

  Future<void> _fetchIssueData() async {
    try {
      if (widget.issueId == null) {
        throw Exception('Issue ID is required for fetching issue details');
      }
      
      final response = await _apiClient.get('/issues/${widget.issueId}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        final upvotesResponse = await _apiClient.get('/issues/${widget.issueId}/upvote/count');
        final int upvotesCount = upvotesResponse.statusCode == 200 
            ? jsonDecode(upvotesResponse.body)['count'] ?? 0 
            : 0;

        setState(() {
          _descriptionController.text = data['description'] ?? '';
          _selectedCategory = data['category'] ?? 'pothole';
          _upvoteCount = upvotesCount;
        });
      }
    } catch (e) {
      print('Error fetching issue data: $e');
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _additionalImages.addAll(
          pickedFiles.map((file) => File(file.path)).toList(),
        );
      });
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().toIso8601String();

      // Upload all images
      final List<String> imageUrls = [];

      // Upload initial image
      final initialImageUrl = await _uploadImage(
        widget.initialImage,
        'initial_$now',
      );
      imageUrls.add(initialImageUrl);

      // Upload additional images
      for (var i = 0; i < _additionalImages.length; i++) {
        final url = await _uploadImage(
          _additionalImages[i],
          'additional_${now}_$i',
        );
        imageUrls.add(url);
      }

      // Save issue to database
      final response = await _apiClient.post('/issues', {
        'title': '${_selectedCategory.replaceAll('_', ' ').toUpperCase()}',
        'category': _selectedCategory,
        'description': _descriptionController.text,
        'imageUrl': imageUrls.first,
        'imageUrls': imageUrls,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'created_at': now,
        'status': 'Pending',
      });

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to submit issue to MongoDB REST: ${response.body}');
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting issue: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String> _uploadImage(File image, String name) async {
    final response = await _apiClient.uploadMultipart(
      '/issues/upload',
      fields: {},
      files: [image],
      fileFieldName: 'photo',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'] ?? '';
    } else {
      throw Exception('Failed to upload image to MongoDB REST: ${response.body}');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.issueId != null ? 'Edit Issue' : 'Report Issue'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isSubmitting ? null : _submitIssue,
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main image preview
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(widget.initialImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Additional images
              if (_additionalImages.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _additionalImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _additionalImages[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _additionalImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Add more images button
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add More Images'),
              ),
              const SizedBox(height: 24),

              // Category dropdown
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category['value'],
                    child: Text(category['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Location info
              if (widget.latitude != null && widget.longitude != null) ...[
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Latitude: ${widget.latitude!.toStringAsFixed(6)}\nLongitude: ${widget.longitude!.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],

              // Upvote button (only show if editing existing issue)
              if (widget.issueId != null) ...[
                UpvoteButton(
                  issueId: widget.issueId!,
                  initialCount: _upvoteCount,
                  initialHasUpvoted: _hasUpvoted,
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitIssue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.issueId != null
                            ? 'Update Issue'
                            : 'Submit Issue',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
