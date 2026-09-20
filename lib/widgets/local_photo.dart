import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

/// Renders a captured or picked photograph on any platform.
///
/// `Image.file` needs a `dart:io` handle, which web does not have. Reading the
/// bytes works everywhere and is cheap here — these are single previews, not a
/// scrolling gallery.
///
/// Shared between the citizen's submission form and the officer's proof-of-fix
/// sheet, which need identical behaviour.
class LocalPhoto extends StatelessWidget {
  final XFile file;
  final BoxFit fit;

  const LocalPhoto({super.key, required this.file, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: AppColors.slate100,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.slate400,
            ),
          );
        }
        if (!snapshot.hasData) {
          return Container(color: AppColors.slate100);
        }
        return Image.memory(snapshot.data!, fit: fit);
      },
    );
  }
}
