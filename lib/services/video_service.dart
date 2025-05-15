import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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

  // Upload a video from file
  Future<TrainerVideo> uploadVideo(File videoFile, String name) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final String videoId = const Uuid().v4();
    final String videoPath = 'videos/$currentUserId/$videoId.mp4';
    
    // Upload video to Firebase Storage
    final storageRef = _storage.ref().child(videoPath);
    final uploadTask = storageRef.putFile(videoFile);
    final snapshot = await uploadTask;
    
    // Get the download URL
    final videoUrl = await snapshot.ref.getDownloadURL();
    
    // Create the video document
    final video = TrainerVideo(
      id: videoId,
      trainerId: currentUserId!,
      name: name,
      videoUrl: videoUrl,
      createdAt: DateTime.now(),
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
  Stream<List<TrainerVideo>> getTrainerVideos(String trainerId) {
    return _videosCollection
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TrainerVideo.fromFirestore(doc))
              .toList();
        });
  }

  // Get a specific video
  Future<TrainerVideo?> getVideo(String videoId) async {
    final doc = await _videosCollection.doc(videoId).get();
    if (!doc.exists) return null;
    return TrainerVideo.fromFirestore(doc);
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    // Get the video first to find the storage path
    final video = await getVideo(videoId);
    if (video == null) return;
    
    // Delete from storage
    try {
      final storageRef = _storage.refFromURL(video.videoUrl);
      await storageRef.delete();
      
      // Delete thumbnail if exists
      if (video.thumbnailUrl != null) {
        final thumbnailRef = _storage.refFromURL(video.thumbnailUrl!);
        await thumbnailRef.delete();
      }
    } catch (e) {
      print('Error deleting video from storage: $e');
    }
    
    // Delete from Firestore
    await _videosCollection.doc(videoId).delete();
  }
} 