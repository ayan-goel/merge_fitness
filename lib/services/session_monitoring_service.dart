import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import 'enhanced_workout_service.dart';

class SessionMonitoringService {
  static final SessionMonitoringService _instance = SessionMonitoringService._internal();
  factory SessionMonitoringService() => _instance;
  SessionMonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EnhancedWorkoutService _enhancedWorkoutService = EnhancedWorkoutService();
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // Start monitoring sessions
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    print('Starting session monitoring...');
    
    // Check every 5 minutes
    _monitoringTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _checkAndUpdateSessions();
    });
    
    // Initial check
    _checkAndUpdateSessions();
  }

  // Stop monitoring sessions
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('Stopped session monitoring');
  }

  // Check and update session statuses
  Future<void> _checkAndUpdateSessions() async {
    try {
      final now = DateTime.now();
      print('Checking session statuses at ${now.toString()}');
      
      // Get all scheduled sessions
      final snapshot = await _firestore.collection('sessions')
          .where('status', isEqualTo: 'scheduled')
          .get();

      int updatedSessions = 0;
      
      for (final doc in snapshot.docs) {
        try {
          final session = TrainingSession.fromFirestore(doc);
          
          // Check if session should be marked as completed (when current time is past the session end time)
          if (now.isAfter(session.endTime)) {
            await _markSessionAsCompleted(session.id);
            updatedSessions++;
            print('Auto-completed session ${session.id} for client ${session.clientName} (ended at ${session.endTime})');
          }
        } catch (e) {
          print('Error processing session ${doc.id}: $e');
        }
      }
      
      if (updatedSessions > 0) {
        print('Auto-completed $updatedSessions sessions');
      }
    } catch (e) {
      print('Error in session monitoring: $e');
    }
  }

  // Mark a session as completed
  Future<void> _markSessionAsCompleted(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'completed',
      });
    } catch (e) {
      print('Error marking session $sessionId as completed: $e');
      rethrow;
    }
  }

  // Force check all sessions (can be called manually)
  Future<void> checkAllSessions() async {
    await _checkAndUpdateSessions();
  }

  // Get monitoring status
  bool get isMonitoring => _isMonitoring;
} 