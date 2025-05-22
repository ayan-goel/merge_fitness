import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_styles.dart';

class PhotoCaptureWidget extends StatefulWidget {
  final Function(File) onPhotoSelected;
  final List<String> existingPhotos;
  final List<File> pendingPhotos;
  final Function(File) onRemovePhoto;

  const PhotoCaptureWidget({
    super.key,
    required this.onPhotoSelected,
    this.existingPhotos = const [],
    this.pendingPhotos = const [],
    required this.onRemovePhoto,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final ImagePicker _picker = ImagePicker();
  
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (photo != null) {
        widget.onPhotoSelected(File(photo.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }
  
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile>? photos = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photos != null && photos.isNotEmpty) {
        for (final photo in photos) {
          widget.onPhotoSelected(File(photo.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing and pending photos
        if (widget.existingPhotos.isNotEmpty || widget.pendingPhotos.isNotEmpty) ...[
          const Text(
            'Your gym setup photos:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Pending (local) photos
                ...widget.pendingPhotos.map((file) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => widget.onRemovePhoto(file),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                // Existing (network) photos
                ...widget.existingPhotos.map((url) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 120,
                          width: 120,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Add photo buttons
        const Text(
          'Add photos of your workout space:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.primarySage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppStyles.primarySage,
                  side: BorderSide(color: AppStyles.primarySage),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppStyles.primarySage.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppStyles.primarySage,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These photos help your trainer understand your available equipment and workout space to create more personalized workouts.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppStyles.textDark.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 