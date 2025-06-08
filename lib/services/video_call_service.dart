import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_call_model.dart';
import '../models/session_model.dart';
import '../config/agora_config.dart';
import 'auth_service.dart';

class VideoCallService {
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  RtcEngine? _engine;
  StreamSubscription<DocumentSnapshot>? _callStatusSubscription;

  // Initialize Agora Engine
  Future<void> initializeAgora() async {
    if (_engine != null) {
      print('VideoCallService: Agora engine already initialized');
      return;
    }

    print('VideoCallService: Creating Agora RTC engine...');
    
    // Check if App ID is configured
    if (AgoraConfig.appId == "YOUR_AGORA_APP_ID_HERE" || AgoraConfig.appId.isEmpty) {
      throw Exception('Agora App ID not configured. Please set your Agora App ID in AgoraConfig.');
    }
    
    try {
      // Create RTC engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      print('VideoCallService: Enabling video and audio...');
      // Enable video and audio - Agora will request permissions if needed
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      
      // Start video preview to trigger permission request if needed
      await _engine!.startPreview();
      
      print('VideoCallService: Agora initialization complete');
    } catch (e) {
      print('VideoCallService: Error initializing Agora: $e');
      
      // Clean up if initialization failed
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }
      
      if (e.toString().contains('-101')) {
        throw Exception('Invalid Agora App ID. Please check your Agora configuration.');
      } else {
        throw Exception('Failed to initialize video engine: $e');
      }
    }
  }

  // Create a new video call
  Future<VideoCall> createVideoCall(String sessionId, {String? trainerId, String? clientId}) async {
    try {
      final user = await _authService.getUserModel();
      final channelName = _generateChannelName(sessionId);
      
      // Use provided trainer and client IDs directly
      // If not provided, use current user as trainer
      String finalTrainerId = trainerId ?? user.uid;
      String finalClientId = clientId ?? '';
      
      print('VideoCallService: Creating call for session $sessionId with trainer: $finalTrainerId, client: $finalClientId');
      print('VideoCallService: Channel name: $channelName');
      
      // First, end any existing active video calls for this session
      try {
        final existingCalls = await _firestore
            .collection('video_calls')
            .where('sessionId', isEqualTo: sessionId)
            .where('status', whereIn: [
              VideoCallStatus.waiting.name,
              VideoCallStatus.active.name
            ])
            .get();
            
        print('VideoCallService: Found ${existingCalls.docs.length} existing calls to clean up');
        
        for (final doc in existingCalls.docs) {
          await doc.reference.update({
            'status': VideoCallStatus.ended.name,
            'endedAt': FieldValue.serverTimestamp(),
          });
          print('VideoCallService: Ended existing call: ${doc.id}');
        }
      } catch (e) {
        print('VideoCallService: Error cleaning up existing calls: $e');
        // Continue anyway
      }
      
      final videoCall = VideoCall(
        id: '',
        sessionId: sessionId,
        trainerId: finalTrainerId,
        clientId: finalClientId,
        channelName: channelName,
        status: VideoCallStatus.waiting,
        trainerJoined: false,
        clientJoined: false,
        createdAt: DateTime.now(),
        agoraUid: _generateAgoraUid(),
      );

      print('VideoCallService: Video call object to save: ${videoCall.toMap()}');

      // Save to Firestore
      final docRef = await _firestore
          .collection('video_calls')
          .add(videoCall.toMap());

      print('VideoCallService: Video call saved to Firestore with ID: ${docRef.id}');
      
      final savedVideoCall = videoCall.copyWith(id: docRef.id);
      print('VideoCallService: Returning video call: ${savedVideoCall.toMap()}');
      
      return savedVideoCall;
    } catch (e) {
      print('VideoCallService: Error creating video call: $e');
      throw Exception('Failed to create video call: $e');
    }
  }

  // Join a video call
  Future<void> joinVideoCall(String callId, bool isTrainer) async {
    try {
      print('VideoCallService: joinVideoCall called - callId: $callId, isTrainer: $isTrainer');
      
      await initializeAgora();
      
      final callDoc = await _firestore
          .collection('video_calls')
          .doc(callId)
          .get();
      
      if (!callDoc.exists) {
        throw Exception('Video call not found');
      }
      
      final videoCall = VideoCall.fromFirestore(callDoc);
      print('VideoCallService: Retrieved video call from Firestore: ${videoCall.toMap()}');
      
      // Generate unique UID for this user
      final currentUser = await _authService.getUserModel();
      final userUid = _generateUserSpecificUid(currentUser.uid);
      
      print('VideoCallService: Joining channel ${videoCall.channelName} with UID $userUid');
      
      // Join Agora channel
      await _engine!.joinChannel(
        token: "", // Use empty string for testing, implement token server for production
        channelId: videoCall.channelName,
        uid: userUid,
        options: const ChannelMediaOptions(),
      );

      // Update join status in Firestore
      final updateData = {
        isTrainer ? 'trainerJoined' : 'clientJoined': true,
        'status': VideoCallStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
      };
      
      print('VideoCallService: Updating Firestore with: $updateData');
      
      await _firestore.collection('video_calls').doc(callId).update(updateData);
      
      print('VideoCallService: Successfully updated Firestore - ${isTrainer ? "trainer" : "client"} joined');
    } catch (e) {
      print('VideoCallService: Error in joinVideoCall: $e');
      throw Exception('Failed to join video call: $e');
    }
  }

  // Leave video call
  Future<void> leaveVideoCall(String callId, bool isTrainer) async {
    try {
      await _engine?.leaveChannel();
      
      // Update leave status in Firestore
      await _firestore.collection('video_calls').doc(callId).update({
        isTrainer ? 'trainerJoined' : 'clientJoined': false,
      });

      // Check if both users have left, then end the call
      final callDoc = await _firestore
          .collection('video_calls')
          .doc(callId)
          .get();
      
      if (callDoc.exists) {
        final data = callDoc.data() as Map<String, dynamic>;
        final trainerJoined = data['trainerJoined'] ?? false;
        final clientJoined = data['clientJoined'] ?? false;
        
        if (!trainerJoined && !clientJoined) {
          await endVideoCall(callId);
        }
      }
    } catch (e) {
      throw Exception('Failed to leave video call: $e');
    }
  }

  // End video call
  Future<void> endVideoCall(String callId) async {
    try {
      await _engine?.leaveChannel();
      
      await _firestore.collection('video_calls').doc(callId).update({
        'status': VideoCallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        'trainerJoined': false,
        'clientJoined': false,
      });
    } catch (e) {
      throw Exception('Failed to end video call: $e');
    }
  }

  // Get video call by session ID
  Future<VideoCall?> getVideoCallBySessionId(String sessionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('video_calls')
          .where('sessionId', isEqualTo: sessionId)
          .where('status', whereIn: [
            VideoCallStatus.waiting.name,
            VideoCallStatus.active.name
          ])
          .orderBy('createdAt', descending: true) // Get the most recent video call first
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return VideoCall.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get video call: $e');
    }
  }

  // Stream video call status
  Stream<VideoCall?> streamVideoCallBySessionId(String sessionId) {
    print('VideoCallService: Setting up stream for session ID: $sessionId');
    return _firestore
        .collection('video_calls')
        .where('sessionId', isEqualTo: sessionId)
        .where('status', whereIn: [
          VideoCallStatus.waiting.name,
          VideoCallStatus.active.name
        ])
        .orderBy('createdAt', descending: true) // Get the most recent video call first
        .limit(1)
        .snapshots()
        .map((snapshot) {
          print('VideoCallService: Stream snapshot received for session $sessionId, docs count: ${snapshot.docs.length}');
          if (snapshot.docs.isEmpty) {
            print('VideoCallService: No video calls found for session $sessionId');
            return null;
          }
          final videoCall = VideoCall.fromFirestore(snapshot.docs.first);
          print('VideoCallService: Found video call: ${videoCall.toMap()}');
          return videoCall;
        });
  }

  // Stream video call by ID
  Stream<VideoCall?> streamVideoCall(String callId) {
    return _firestore
        .collection('video_calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return VideoCall.fromFirestore(snapshot);
        });
  }

  // Toggle microphone
  Future<void> toggleMicrophone(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  // Toggle camera
  Future<void> toggleCamera(bool disabled) async {
    await _engine?.muteLocalVideoStream(disabled);
  }

  // Switch camera
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  // Set up event handlers
  void setEventHandlers({
    Function(RtcConnection connection, int remoteUid, int elapsed)? onUserJoined,
    Function(RtcConnection connection, int remoteUid, UserOfflineReasonType reason)? onUserOffline,
    Function(RtcConnection connection, RtcStats stats)? onRtcStats,
    Function(RtcConnection connection, RemoteVideoStats stats)? onRemoteVideoStats,
    Function(RtcConnection connection, RemoteAudioStats stats)? onRemoteAudioStats,
  }) {
    _engine?.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        print('Local user joined channel: ${connection.channelId}');
      },
      onUserJoined: onUserJoined,
      onUserOffline: onUserOffline,
      onRtcStats: onRtcStats,
      onRemoteVideoStats: onRemoteVideoStats,
      onRemoteAudioStats: onRemoteAudioStats,
      onError: (ErrorCodeType err, String msg) {
        print('Agora Error: $err - $msg');
      },
    ));
  }

  // Get RTC engine for video rendering
  RtcEngine? get engine => _engine;

  // Generate unique channel name based on session ID only
  String _generateChannelName(String sessionId) {
    // Use only session ID to ensure both trainer and client join the same channel
    return 'session_$sessionId';
  }

  // Generate random Agora UID (for video call creation)
  int _generateAgoraUid() {
    return Random().nextInt(1000000) + 1;
  }
  
  // Generate user-specific UID based on their Firebase UID
  int _generateUserSpecificUid(String firebaseUid) {
    // Create a consistent UID for each user based on their Firebase UID
    // This ensures the same user always gets the same Agora UID
    int hash = firebaseUid.hashCode;
    // Ensure it's positive and within Agora's allowed range (1 to 2^32-1)
    return (hash.abs() % 1000000) + 1;
  }

  // Force cleanup - ensures all resources are released
  Future<void> forceCleanup() async {
    try {
      print('VideoCallService: Force cleanup initiated...');
      
      // Cancel any subscriptions
      await _callStatusSubscription?.cancel();
      _callStatusSubscription = null;
      
      // Leave channel if still in one
      if (_engine != null) {
        print('VideoCallService: Leaving Agora channel...');
        await _engine!.leaveChannel();
        print('VideoCallService: Releasing Agora engine...');
        await _engine!.release();
        _engine = null;
      }
      
      print('VideoCallService: Force cleanup completed');
    } catch (e) {
      print('VideoCallService: Error during force cleanup: $e');
      // Ensure engine is null even if there was an error
      _engine = null;
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await forceCleanup();
  }

  // Check if user has camera and microphone permissions
  Future<bool> checkPermissions() async {
    try {
      final microphoneStatus = await Permission.microphone.status;
      final cameraStatus = await Permission.camera.status;
      
      print('VideoCallService: Microphone permission: $microphoneStatus');
      print('VideoCallService: Camera permission: $cameraStatus');
      
      return microphoneStatus.isGranted && cameraStatus.isGranted;
    } catch (e) {
      print('VideoCallService: Error checking permissions: $e');
      return false;
    }
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    try {
      print('VideoCallService: Requesting camera and microphone permissions...');
      
      // Request permissions individually to get better control
      final micPermission = await Permission.microphone.request();
      print('VideoCallService: Microphone permission result: $micPermission');
      
      final camPermission = await Permission.camera.request();
      print('VideoCallService: Camera permission result: $camPermission');
      
      final micGranted = micPermission.isGranted;
      final camGranted = camPermission.isGranted;
      
      print('VideoCallService: Microphone granted: $micGranted');
      print('VideoCallService: Camera granted: $camGranted');
      
      // If permissions are still denied, try requesting them again
      if (!micGranted || !camGranted) {
        print('VideoCallService: Permissions still denied, checking status...');
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay
        
        final micStatusAfter = await Permission.microphone.status;
        final camStatusAfter = await Permission.camera.status;
        
        print('VideoCallService: Mic status after delay: $micStatusAfter');
        print('VideoCallService: Cam status after delay: $camStatusAfter');
        
        return micStatusAfter.isGranted && camStatusAfter.isGranted;
      }
      
      return micGranted && camGranted;
    } catch (e) {
      print('VideoCallService: Error requesting permissions: $e');
      return false;
    }
  }

  // Debug method to get detailed permission status
  Future<Map<String, dynamic>> getDetailedPermissionStatus() async {
    try {
      final micStatus = await Permission.microphone.status;
      final camStatus = await Permission.camera.status;
      
      return {
        'microphone': {
          'status': micStatus.toString(),
          'isGranted': micStatus.isGranted,
          'isDenied': micStatus.isDenied,
          'isPermanentlyDenied': micStatus.isPermanentlyDenied,
          'isRestricted': micStatus.isRestricted,
          'isLimited': micStatus.isLimited,
        },
        'camera': {
          'status': camStatus.toString(),
          'isGranted': camStatus.isGranted,
          'isDenied': camStatus.isDenied,
          'isPermanentlyDenied': camStatus.isPermanentlyDenied,
          'isRestricted': camStatus.isRestricted,
          'isLimited': camStatus.isLimited,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
} 