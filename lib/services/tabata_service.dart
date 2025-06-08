import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tabata_timer_model.dart';
import '../models/video_call_model.dart';
import 'auth_service.dart';

class TabataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  Timer? _localTimer;
  StreamSubscription<DocumentSnapshot>? _timerSubscription;

  // Create a new tabata timer
  Future<TabataTimer> createTabataTimer(String callId, TabataConfig config) async {
    try {
      final user = await _authService.getUserModel();
      final now = DateTime.now();
      
      // Get video call details to extract trainer and client IDs
      VideoCall? videoCall;
      try {
        final callDoc = await _firestore.collection('video_calls').doc(callId).get();
        if (callDoc.exists) {
          final callData = callDoc.data() as Map<String, dynamic>;
          // Create a temporary VideoCall object to access the data
          videoCall = VideoCall(
            id: callDoc.id,
            sessionId: callData['sessionId'] ?? '',
            trainerId: callData['trainerId'] ?? '',
            clientId: callData['clientId'] ?? '',
            channelName: callData['channelName'] ?? '',
            status: VideoCallStatus.waiting,
            trainerJoined: false,
            clientJoined: false,
            createdAt: DateTime.now(),
          );
        }
      } catch (e) {
        print('TabataService: Could not fetch video call details: $e');
      }
      
      final tabataTimer = TabataTimer(
        id: '',
        callId: callId,
        exerciseTime: config.exerciseTime,
        restTime: config.restTime,
        totalExercises: config.totalExercises,
        currentExercise: 1,
        status: TabataStatus.created,
        currentPhase: TabataPhase.exercise,
        timeRemaining: config.exerciseTime,
        createdBy: user.uid,
        trainerId: videoCall?.trainerId ?? user.uid, // Add trainerId field
        clientId: videoCall?.clientId ?? '', // Add clientId field
        createdAt: now,
        updatedAt: now,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('tabata_timers')
          .add(tabataTimer.toMap());

      return tabataTimer.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create tabata timer: $e');
    }
  }

  // Start the timer
  Future<void> startTimer(String timerId) async {
    try {
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'status': TabataStatus.active.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to start timer: $e');
    }
  }

  // Pause the timer
  Future<void> pauseTimer(String timerId) async {
    try {
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'status': TabataStatus.paused.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to pause timer: $e');
    }
  }

  // Stop the timer
  Future<void> stopTimer(String timerId) async {
    try {
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'status': TabataStatus.finished.name,
        'currentPhase': TabataPhase.finished.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to stop timer: $e');
    }
  }

  // Reset timer to beginning
  Future<void> resetTimer(String timerId) async {
    try {
      final timerDoc = await _firestore
          .collection('tabata_timers')
          .doc(timerId)
          .get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }
      
      final timer = TabataTimer.fromFirestore(timerDoc);
      
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'status': TabataStatus.created.name,
        'currentPhase': TabataPhase.exercise.name,
        'currentExercise': 1,
        'timeRemaining': timer.exerciseTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reset timer: $e');
    }
  }

  // Get tabata timer by call ID
  Future<TabataTimer?> getTabataTimerByCallId(String callId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tabata_timers')
          .where('callId', isEqualTo: callId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return TabataTimer.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get tabata timer: $e');
    }
  }

  // Stream tabata timer by call ID
  Stream<TabataTimer?> streamTabataTimerByCallId(String callId) {
    return _firestore
        .collection('tabata_timers')
        .where('callId', isEqualTo: callId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return TabataTimer.fromFirestore(snapshot.docs.first);
        });
  }

  // Stream tabata timer by ID
  Stream<TabataTimer?> streamTabataTimer(String timerId) {
    return _firestore
        .collection('tabata_timers')
        .doc(timerId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return TabataTimer.fromFirestore(snapshot);
        });
  }

  // Start local timer countdown (for trainer only)
  void startLocalTimer(String timerId, TabataTimer initialTimer) {
    _stopLocalTimer();
    
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Check if service is disposed
        if (_localTimer == null || !timer.isActive) {
          return;
        }
        
        // Get current timer state from Firestore
        final timerDoc = await _firestore
            .collection('tabata_timers')
            .doc(timerId)
            .get();
        
        if (!timerDoc.exists) {
          _stopLocalTimer();
          return;
        }
        
        final currentTimer = TabataTimer.fromFirestore(timerDoc);
        
        // Only update if timer is active
        if (!currentTimer.isActive) {
          return;
        }
        
        // Calculate new time remaining
        int newTimeRemaining = currentTimer.timeRemaining - 1;
        
        if (newTimeRemaining <= 0) {
          // Phase completed, move to next phase or exercise
          await _handlePhaseCompletion(timerId, currentTimer);
        } else {
          // Update time remaining
          await _firestore.collection('tabata_timers').doc(timerId).update({
            'timeRemaining': newTimeRemaining,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Error updating timer: $e');
      }
    });
  }

  // Handle phase completion logic
  Future<void> _handlePhaseCompletion(String timerId, TabataTimer timer) async {
    if (timer.isExercisePhase) {
      // Exercise phase completed, move to rest
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'currentPhase': TabataPhase.rest.name,
        'timeRemaining': timer.restTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (timer.isRestPhase) {
      // Rest phase completed
      if (timer.currentExercise >= timer.totalExercises) {
        // All exercises completed, finish timer
        await _firestore.collection('tabata_timers').doc(timerId).update({
          'status': TabataStatus.finished.name,
          'currentPhase': TabataPhase.finished.name,
          'timeRemaining': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _stopLocalTimer();
      } else {
        // Move to next exercise
        await _firestore.collection('tabata_timers').doc(timerId).update({
          'currentPhase': TabataPhase.exercise.name,
          'currentExercise': timer.currentExercise + 1,
          'timeRemaining': timer.exerciseTime,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Stop local timer
  void _stopLocalTimer() {
    _localTimer?.cancel();
    _localTimer = null;
  }

  // Update timer configuration
  Future<void> updateTimerConfig(String timerId, TabataConfig config) async {
    try {
      await _firestore.collection('tabata_timers').doc(timerId).update({
        'exerciseTime': config.exerciseTime,
        'restTime': config.restTime,
        'totalExercises': config.totalExercises,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update timer config: $e');
    }
  }

  // Delete tabata timer
  Future<void> deleteTabataTimer(String timerId) async {
    try {
      _stopLocalTimer();
      await _firestore.collection('tabata_timers').doc(timerId).delete();
    } catch (e) {
      throw Exception('Failed to delete timer: $e');
    }
  }

  // Check if user is the creator of the timer
  Future<bool> isTimerCreator(String timerId) async {
    try {
      final user = await _authService.getUserModel();
      final timerDoc = await _firestore
          .collection('tabata_timers')
          .doc(timerId)
          .get();
      
      if (!timerDoc.exists) return false;
      
      final timer = TabataTimer.fromFirestore(timerDoc);
      return timer.createdBy == user.uid;
    } catch (e) {
      return false;
    }
  }

  // Get timer statistics
  Future<Map<String, dynamic>> getTimerStats(String timerId) async {
    try {
      final timerDoc = await _firestore
          .collection('tabata_timers')
          .doc(timerId)
          .get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }
      
      final timer = TabataTimer.fromFirestore(timerDoc);
      
      final totalDuration = (timer.exerciseTime + timer.restTime) * timer.totalExercises;
      final completedExercises = timer.isFinishedPhase 
          ? timer.totalExercises 
          : timer.currentExercise - (timer.isExercisePhase ? 1 : 0);
      final remainingExercises = timer.totalExercises - completedExercises;
      
      return {
        'totalDuration': totalDuration,
        'completedExercises': completedExercises,
        'remainingExercises': remainingExercises,
        'currentPhase': timer.phaseDisplayName,
        'progress': completedExercises / timer.totalExercises,
      };
    } catch (e) {
      throw Exception('Failed to get timer stats: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _stopLocalTimer();
    _timerSubscription?.cancel();
    _timerSubscription = null;
  }
} 