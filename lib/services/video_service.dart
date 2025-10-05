import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class TrainerVideo {
  final String id;
  final String trainerId;
  final String name;
  final String videoUrl;
  final DateTime createdAt;
  final String? thumbnailUrl;

  TrainerVideo({
    required this.id,
    required this.trainerId,
    required this.name,
    required this.videoUrl,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory TrainerVideo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TrainerVideo(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      name: data['name'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      thumbnailUrl: data['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'name': name,
      'videoUrl': videoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference get _videosCollection => _firestore.collection('trainerVideos');

  // Generate thumbnail from video file
  Future<String?> _generateThumbnail(File videoFile, String videoId, String trainerId) async {
    try {
      // Generate thumbnail with specific dimensions
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: null,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 80,
      );

      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);

        // Check if file exists and has content
        if (await thumbnailFile.exists() && await thumbnailFile.length() > 0) {
          final thumbnailStoragePath = 'thumbnails/$trainerId/$videoId.jpg';

          // Upload thumbnail to Firebase Storage
          final thumbnailRef = _storage.ref().child(thumbnailStoragePath);
          final uploadTask = thumbnailRef.putFile(thumbnailFile);
          final snapshot = await uploadTask;

          // Get the download URL
          final thumbnailUrl = await snapshot.ref.getDownloadURL();

          // Clean up local thumbnail file
          await thumbnailFile.delete();

          return thumbnailUrl;
        } else {
          print('Generated thumbnail file is empty or does not exist');
        }
      } else {
        print('VideoThumbnail.thumbnailFile returned null');
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
    return null;
  }

  // Upload a video from file
  Future<TrainerVideo> uploadVideo(File videoFile, String name) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final String videoId = const Uuid().v4();
    final String trainerId = currentUserId!;
    final String videoPath = 'videos/$trainerId/$videoId.mp4';

    // Upload video to Firebase Storage
    final storageRef = _storage.ref().child(videoPath);
    final uploadTask = storageRef.putFile(videoFile);
    final snapshot = await uploadTask;

    // Get the download URL
    final videoUrl = await snapshot.ref.getDownloadURL();

    // Generate and upload thumbnail
    final thumbnailUrl = await _generateThumbnail(videoFile, videoId, trainerId);

    // Create the video document
    final video = TrainerVideo(
      id: videoId,
      trainerId: trainerId,
      name: name,
      videoUrl: videoUrl,
      createdAt: DateTime.now(),
      thumbnailUrl: thumbnailUrl,
    );

    // Save to Firestore
    await _videosCollection.doc(videoId).set(video.toMap());

    return video;
  }

  // Record a video using camera
  Future<TrainerVideo?> recordVideo(String name) async {
    final XFile? videoFile = await _picker.pickVideo(source: ImageSource.camera);
    
    if (videoFile == null) {
      return null;
    }
    
    return uploadVideo(File(videoFile.path), name);
  }

  // Pick a video from gallery
  Future<TrainerVideo?> pickVideoFromGallery(String name) async {
    final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
    
    if (videoFile == null) {
      return null;
    }
    
    return uploadVideo(File(videoFile.path), name);
  }

  // Get all videos for a trainer
  // Get all trainer videos (shared across all trainers)
  Stream<List<TrainerVideo>> getTrainerVideos(String trainerId, {String? searchQuery}) {
    // Note: trainerId parameter kept for backwards compatibility but not used
    // All trainers now have access to all videos
    return _videosCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          var videos = snapshot.docs
              .map((doc) => TrainerVideo.fromFirestore(doc))
              .toList();

          // Apply client-side filtering if search query is provided
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final query = searchQuery.toLowerCase().trim();
            videos = videos.where((video) {
              return video.name.toLowerCase().contains(query);
            }).toList();
          }

          return videos;
        });
  }

  // Get a specific video
  Future<TrainerVideo?> getVideo(String videoId) async {
    final doc = await _videosCollection.doc(videoId).get();
    if (!doc.exists) return null;
    return TrainerVideo.fromFirestore(doc);
  }

  // Update video name
  Future<void> updateVideoName(String videoId, String newName) async {
    try {
      await _videosCollection.doc(videoId).update({
        'name': newName,
      });
    } catch (e) {
      print('Error updating video name: $e');
      rethrow;
    }
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    // Get the video first to find the storage paths
    final video = await getVideo(videoId);
    if (video == null) return;

    // Delete video from storage
    try {
      final videoStorageRef = _storage.refFromURL(video.videoUrl);
      await videoStorageRef.delete();
    } catch (e) {
      print('Error deleting video from storage: $e');
    }

    // Delete thumbnail from storage if it exists
    try {
      if (video.thumbnailUrl != null) {
        final thumbnailStorageRef = _storage.refFromURL(video.thumbnailUrl!);
        await thumbnailStorageRef.delete();
      }
    } catch (e) {
      print('Error deleting thumbnail from storage: $e');
    }

    // Delete from Firestore
    await _videosCollection.doc(videoId).delete();
  }

  // Regenerate thumbnail for existing video (for videos uploaded before thumbnail feature)
  Future<String?> regenerateThumbnail(String videoId) async {
    try {
      // Get the video document
      final videoDoc = await _videosCollection.doc(videoId).get();
      if (!videoDoc.exists) return null;

      final video = TrainerVideo.fromFirestore(videoDoc);

      // Download the video file locally (this would require the video to be accessible)
      // For now, we'll just return null since we can't easily regenerate thumbnails for existing videos
      // without re-uploading them

      print('Cannot regenerate thumbnail for existing video without re-upload');
      return null;

    } catch (e) {
      print('Error regenerating thumbnail: $e');
      return null;
    }
  }
} 