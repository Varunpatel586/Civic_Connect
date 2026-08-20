import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/issue_categories.dart';

/// Files a new complaint: evidence, classification, description, location.
///
/// Coordinates are mandatory. A complaint the municipality cannot locate is one
/// it cannot dispatch anyone to, so this screen resolves the position itself
/// when the camera could not, and refuses to submit without one.
class IssueSubmissionScreen extends StatefulWidget {
  final XFile initialImage;
  final double? latitude;
  final double? longitude;

  const IssueSubmissionScreen({
    super.key,
    required this.initialImage,
    this.latitude,
    this.longitude,
  });

  @override
  State<IssueSubmissionScreen> createState() => _IssueSubmissionScreenState();
}

class _IssueSubmissionScreenState extends State<IssueSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _apiClient = ApiClient();
  final _locationService = LocationService();

  final List<XFile> _additionalImages = [];
  String _category = 'pothole';
  bool _isSubmitting = false;

  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLocating = false;
  String? _locationError;

  bool get _hasLocation => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    _latitude = widget.latitude;
    _longitude = widget.longitude;

    if (_hasLocation) {
      _describeLocation();
    } else {
      // The camera screen could not get a fix; try again here rather than
      // silently filing a complaint at coordinates 0, 0.
      _resolveLocation();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLocating = false;
      });
      await _describeLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError =
            'Location unavailable. Turn on location services and try again.';
      });
    }
  }

  /// Best-effort reverse geocode. Failure is not fatal — the coordinates are
  /// what the municipality dispatches on; the address is for humans reading it.
  Future<void> _describeLocation() async {
    if (!_hasLocation) return;
    try {
      final address = await _locationService.getAddressFromLatLng(
        _latitude!,
        _longitude!,
      );
      if (!mounted) return;
      setState(() => _address = address);
    } catch (e) {
      debugPrint('Could not reverse geocode: $e');
    }
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (picked.isEmpty || !mounted) return;

    setState(() {
      _additionalImages.addAll(picked);
    });
  }

  Future<String> _upload(XFile image) async {
    final response = await _apiClient.uploadMultipart(
      '/issues/upload',
      fields: const {},
      files: [image],
      fileFieldName: 'photo',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final url = data['url']?.toString() ?? '';
      if (url.isEmpty) throw Exception('Upload returned no URL');
      return url;
    }
    throw Exception('Photo upload failed (${response.statusCode})');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A complaint needs a location before it can be filed.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final appProvider = context.read<AppProvider>();

    try {
      final imageUrls = <String>[await _upload(widget.initialImage)];
      for (final image in _additionalImages) {
        imageUrls.add(await _upload(image));
      }

      // Through the provider rather than the API directly, so the feed and the
      // citizen's own list both refresh before they land back on them.
      await appProvider.reportIssue(
        category: _category,
        description: _descriptionController.text,
        imageUrls: imageUrls,
        latitude: _latitude!,
        longitude: _longitude!,
        address: _address,
      );

      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Complaint filed. You can track it in your profile.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not file the complaint: $e'),
          backgroundColor: StatusColors.rejected.foreground,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _EvidenceStrip(
              initialImage: widget.initialImage,
              additional: _additionalImages,
              onAdd: _pickImages,
              onRemove: (index) =>
                  setState(() => _additionalImages.removeAt(index)),
            ),
            _Section(
              label: 'CATEGORY',
              child: _CategoryPicker(
                selected: _category,
                onChanged: (value) => setState(() => _category = value),
              ),
            ),
            _Section(
              label: 'WHAT IS WRONG',
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Describe the problem, how long it has been there, and '
                      'anything that makes it urgent.',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Describe the issue';
                  if (v.length < 15) {
                    return 'Add a little more detail (at least 15 characters)';
                  }
                  return null;
                },
              ),
            ),
            _Section(
              label: 'LOCATION',
              child: _LocationCard(
                latitude: _latitude,
                longitude: _longitude,
                address: _address,
                isLocating: _isLocating,
                error: _locationError,
                onRetry: _resolveLocation,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: ElevatedButton(
                onPressed: _isSubmitting || !_hasLocation ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('File complaint'),
              ),
            ),
            if (!_hasLocation && !_isLocating)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Filing is disabled until a location is available.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;

  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.sectionLabel()),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EvidenceStrip extends StatelessWidget {
  final XFile initialImage;
  final List<XFile> additional;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _EvidenceStrip({
    required this.initialImage,
    required this.additional,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _Photo(file: initialImage, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < additional.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: _Photo(file: additional[i], fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => onRemove(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.navy900.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                InkWell(
                  onTap: onAdd,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.slate200),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 18,
                          color: AppColors.slate600,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ADD',
                          style: AppTypography.badge(color: AppColors.slate600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The taxonomy as a grid rather than a dropdown: eight options is few enough
/// to show at once, and seeing them all helps a citizen pick the right one.
class _CategoryPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final category in IssueCategories.all)
          InkWell(
            onTap: () => onChanged(category.value),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: selected == category.value
                    ? AppColors.navy900
                    : AppColors.surface,
                border: Border.all(
                  color: selected == category.value
                      ? AppColors.navy900
                      : AppColors.slate200,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: 14,
                    color: selected == category.value
                        ? Colors.white
                        : AppColors.slate600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 12.5,
                      color: selected == category.value
                          ? Colors.white
                          : AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isLocating;
  final String? error;
  final VoidCallback onRetry;

  const _LocationCard({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isLocating,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocating) {
      return Row(
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 11),
          Text(
            'Finding your location…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    if (latitude == null || longitude == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StatusColors.overdue.background,
          border: Border.all(color: StatusColors.overdue.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 16,
                  color: StatusColors.overdue.foreground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error ?? 'Location unavailable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: StatusColors.overdue.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 16,
              color: AppColors.navy700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                address ?? 'Address not resolved',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
            style: AppTypography.recordId(),
          ),
        ),
      ],
    );
  }
}

/// Renders a captured or picked photograph on any platform.
///
/// `Image.file` needs a `dart:io` handle, which web does not have. Reading the
/// bytes works everywhere and is cheap here — these are single previews, not a
/// scrolling gallery.
class _Photo extends StatelessWidget {
  final XFile file;
  final BoxFit fit;

  const _Photo({required this.file, required this.fit});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: AppColors.canvas,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.slate200,
            ),
          );
        }
        if (!snapshot.hasData) {
          return Container(color: AppColors.canvas);
        }
        return Image.memory(snapshot.data!, fit: fit);
      },
    );
  }
}
