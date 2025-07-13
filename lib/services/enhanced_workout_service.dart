import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/assigned_workout_model.dart';
import '../models/session_model.dart';
import 'workout_template_service.dart';
import 'calendly_service.dart';

class EnhancedWorkoutService {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final CalendlyService _calendlyService = CalendlyService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get combined workouts and sessions for today
  Stream<List<AssignedWorkout>> getCurrentWorkouts(String clientId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _workoutService.getCurrentWorkouts(clientId).asyncMap((regularWorkouts) async {
      try {
        // Get training sessions for today
        final sessions = await _getTodaySessions(clientId, startOfDay, endOfDay);
        
        // Convert sessions to AssignedWorkout objects
        // For family sessions, create an AssignedWorkout for each family member
        final sessionWorkouts = <AssignedWorkout>[];
        for (final session in sessions) {
          print('Processing session ${session.id} for client $clientId, isFamily: ${session.isBookingForFamily}');
          
          if (session.isBookingForFamily && session.familyMembers != null) {
            // Create an AssignedWorkout for each family member
            for (final member in session.familyMembers!) {
              final memberId = member['uid'] as String?;
              print('  Checking family member: $memberId');
              if (memberId != null && memberId == clientId) {
                print('  Creating AssignedWorkout for family member $memberId');
                // Only create for the current client being queried
                sessionWorkouts.add(AssignedWorkout.fromSession(session, overrideClientId: memberId));
              }
            }
          } else {
            // Regular session - only for the primary client
            if (session.clientId == clientId) {
              print('  Creating AssignedWorkout for primary client');
              sessionWorkouts.add(AssignedWorkout.fromSession(session));
            }
          }
        }
        
        // Log for debugging
        print('Enhanced service: Found ${regularWorkouts.length} current regular workouts and ${sessionWorkouts.length} current sessions for client $clientId');
        
        // Combine and sort by scheduled date
        final combinedWorkouts = [...regularWorkouts, ...sessionWorkouts];
        combinedWorkouts.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        
        return combinedWorkouts;
      } catch (e) {
        print('Error combining current workouts and sessions: $e');
        // Return just regular workouts if session fetching fails
        return regularWorkouts;
      }
    });
  }

  // Get combined workouts and sessions for a client
  Stream<List<AssignedWorkout>> getClientWorkouts(String clientId) {
    return _workoutService.getClientWorkouts(clientId).asyncMap((regularWorkouts) async {
      try {
        // Get all training sessions for the client
        final sessions = await _getAllClientSessions(clientId);
        
        // Convert sessions to AssignedWorkout objects
        // For family sessions, create an AssignedWorkout for each family member
        final sessionWorkouts = <AssignedWorkout>[];
        for (final session in sessions) {
          print('Processing all session ${session.id} for client $clientId, isFamily: ${session.isBookingForFamily}');
          
          if (session.isBookingForFamily && session.familyMembers != null) {
            // Create an AssignedWorkout for each family member
            for (final member in session.familyMembers!) {
              final memberId = member['uid'] as String?;
              print('  Checking all family member: $memberId');
              if (memberId != null && memberId == clientId) {
                print('  Creating AssignedWorkout for all family member $memberId');
                // Only create for the current client being queried
                sessionWorkouts.add(AssignedWorkout.fromSession(session, overrideClientId: memberId));
              }
            }
          } else {
            // Regular session - only for the primary client
            if (session.clientId == clientId) {
              print('  Creating AssignedWorkout for all primary client');
              sessionWorkouts.add(AssignedWorkout.fromSession(session));
            }
          }
        }
        
        // Log for debugging
        print('Enhanced service: Found ${regularWorkouts.length} regular workouts and ${sessionWorkouts.length} sessions for client $clientId');
        
        // Combine and sort by scheduled date
        final combinedWorkouts = [...regularWorkouts, ...sessionWorkouts];
        combinedWorkouts.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        
        return combinedWorkouts;
      } catch (e) {
        print('Error combining workouts and sessions: $e');
        // Return just regular workouts if session fetching fails
        return regularWorkouts;
      }
    });
  }

  // Get sessions for today (works for both trainers and clients)
  Future<List<TrainingSession>> _getTodaySessions(String clientId, DateTime startOfDay, DateTime endOfDay) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return [];
      }
      
      // Check if current user is the client or trainer
      if (user.uid == clientId) {
        // Client querying their own sessions - query by clientId and family sessions
        print('Client querying their own sessions for today');
        
        // Get regular sessions where client is primary booking client
        final regularSnapshot = await _firestore.collection('sessions')
            .where('clientId', isEqualTo: clientId)
            .where('startTime', isGreaterThanOrEqualTo: startOfDay)
            .where('startTime', isLessThanOrEqualTo: endOfDay)
            .get();
        
        // Get family sessions for today where client is a family member
        final familySnapshot = await _firestore.collection('sessions')
            .where('isBookingForFamily', isEqualTo: true)
            .where('startTime', isGreaterThanOrEqualTo: startOfDay)
            .where('startTime', isLessThanOrEqualTo: endOfDay)
            .get();
        
        print('Found ${familySnapshot.docs.length} family sessions for today');
        
        // Combine regular sessions
        List<TrainingSession> clientSessions = regularSnapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        print('Found ${clientSessions.length} regular sessions for today for client $clientId');
        
        // Add family sessions where this client is a member
        final familySessions = familySnapshot.docs
            .map((doc) => TrainingSession.fromFirestore(doc))
            .where((session) {
              if (session.familyMembers == null) {
                print('Today session ${session.id} has no family members');
                return false;
              }
              
              print('Today session ${session.id} family members: ${session.familyMembers}');
              final isClientInFamily = session.familyMembers!.any((member) => member['uid'] == clientId);
              print('Client $clientId is in today family session ${session.id}: $isClientInFamily');
              
              return isClientInFamily;
            })
            .toList();
        
        print('Found ${familySessions.length} family sessions for today for client $clientId');
        
        clientSessions.addAll(familySessions);
        
        // Remove duplicates (in case client is both primary and family member)
        final seenIds = <String>{};
        clientSessions = clientSessions.where((session) {
          if (seenIds.contains(session.id)) return false;
          seenIds.add(session.id);
          return true;
        }).toList();
        
        return clientSessions;
      } else {
        // Trainer querying client sessions - query by trainerId then filter
        print('Trainer querying client sessions');
        final snapshot = await _firestore.collection('sessions')
            .where('trainerId', isEqualTo: user.uid)
            .where('startTime', isGreaterThanOrEqualTo: startOfDay)
            .where('startTime', isLessThanOrEqualTo: endOfDay)
            .get();

        // Filter sessions for the specific client
        final allSessions = snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        return allSessions.where((session) => session.clientId == clientId).toList();
      }
    } catch (e) {
      // Only log non-permission errors to avoid spam
      if (!e.toString().contains('permission-denied')) {
        print('Error getting today\'s sessions: $e');
      }
      
      // Fallback without date filtering if indexes aren't ready
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return [];
        
        QuerySnapshot snapshot;
        if (user.uid == clientId) {
          // Client fallback
          snapshot = await _firestore.collection('sessions')
              .where('clientId', isEqualTo: clientId)
              .get();
        } else {
          // Trainer fallback
          snapshot = await _firestore.collection('sessions')
              .where('trainerId', isEqualTo: user.uid)
              .get();
        }

        return snapshot.docs
            .map((doc) => TrainingSession.fromFirestore(doc))
            .where((session) => 
                session.clientId == clientId &&
                session.startTime.isAfter(startOfDay.subtract(Duration(seconds: 1))) &&
                session.startTime.isBefore(endOfDay.add(Duration(seconds: 1))))
            .toList();
      } catch (fallbackError) {
        // Only log non-permission errors to avoid spam
        if (!fallbackError.toString().contains('permission-denied')) {
          print('Fallback error getting today\'s sessions: $fallbackError');
        }
        return [];
      }
    }
  }

  // Get all sessions for a client (works for both trainers and clients)
  Future<List<TrainingSession>> _getAllClientSessions(String clientId) async {
    try {
      print('Enhanced service: Fetching sessions for client $clientId');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return [];
      }
      
      List<TrainingSession> clientSessions;
      
      // Check if current user is the client or trainer
      if (user.uid == clientId) {
        // Client querying their own sessions - query by clientId and family sessions
        print('Client querying their own sessions');
        
        // Get regular sessions where client is primary booking client
        final regularSnapshot = await _firestore.collection('sessions')
            .where('clientId', isEqualTo: clientId)
            .get();
        
        // Get family sessions where client is a family member
        print('Querying for family sessions...');
        final familySnapshot = await _firestore.collection('sessions')
            .where('isBookingForFamily', isEqualTo: true)
            .get();
        
        print('Found ${familySnapshot.docs.length} family sessions total');
        
        // Combine regular sessions
        clientSessions = regularSnapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        print('Found ${clientSessions.length} regular sessions for client $clientId');
        
        // Add family sessions where this client is a member
        final familySessions = familySnapshot.docs
            .map((doc) => TrainingSession.fromFirestore(doc))
            .where((session) {
              if (session.familyMembers == null) {
                print('Session ${session.id} has no family members');
                return false;
              }
              
              print('Session ${session.id} family members: ${session.familyMembers}');
              final isClientInFamily = session.familyMembers!.any((member) => member['uid'] == clientId);
              print('Client $clientId is in family session ${session.id}: $isClientInFamily');
              
              return isClientInFamily;
            })
            .toList();
        
        print('Found ${familySessions.length} family sessions for client $clientId');
        
        clientSessions.addAll(familySessions);
        
        // Remove duplicates (in case client is both primary and family member)
        final seenIds = <String>{};
        clientSessions = clientSessions.where((session) {
          if (seenIds.contains(session.id)) return false;
          seenIds.add(session.id);
          return true;
        }).toList();
        
        print('Enhanced service: Found ${clientSessions.length} total sessions for client $clientId (including family sessions)');
      } else {
        // Trainer querying client sessions - query by trainerId then filter
        print('Trainer querying client sessions');
        final snapshot = await _firestore.collection('sessions')
            .where('trainerId', isEqualTo: user.uid)
            .get();

        // Filter sessions for the specific client
        final allSessions = snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        clientSessions = allSessions.where((session) => session.clientId == clientId).toList();
        
        print('Enhanced service: Found ${clientSessions.length} sessions for client $clientId (out of ${allSessions.length} total trainer sessions)');
      }
      
      // Log details of each session for debugging
      for (var session in clientSessions) {
        print('  Session: ${session.id}, status: ${session.status}, startTime: ${session.startTime}, client: ${session.clientName}, isFamily: ${session.isBookingForFamily}');
        if (session.isBookingForFamily && session.familyMembers != null) {
          print('    Family members: ${session.familyMembers}');
        }
      }
      
      return clientSessions;
    } catch (e) {
      // Only log non-permission errors to avoid spam
      if (!e.toString().contains('permission-denied')) {
        print('Error getting all client sessions: $e');
      } else {
        print('Permission denied for getting client sessions (this is expected)');
      }
      return [];
    }
  }

  // Mark session as completed (called automatically when session ends)
  Future<void> markSessionAsCompleted(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'completed',
      });
      print('Marked session $sessionId as completed');
    } catch (e) {
      print('Error marking session as completed: $e');
    }
  }

  // Check and update session statuses (to be called periodically)
  Future<void> updateSessionStatuses() async {
    try {
      final now = DateTime.now();
      
      // Get all scheduled sessions that should be marked as completed
      final snapshot = await _firestore.collection('sessions')
          .where('status', isEqualTo: 'scheduled')
          .get();

      for (final doc in snapshot.docs) {
        final session = TrainingSession.fromFirestore(doc);
        
        // Check if session should be marked as completed (when current time is past the session end time)
        if (now.isAfter(session.endTime)) {
          await markSessionAsCompleted(session.id);
        }
      }
    } catch (e) {
      print('Error updating session statuses: $e');
    }
  }

  // Get workouts in a date range (including sessions)
  Stream<List<AssignedWorkout>> getWorkoutsInDateRange(String clientId, DateTime startDate, DateTime endDate) {
    return _workoutService.getWorkoutsInDateRange(clientId, startDate, endDate).asyncMap((regularWorkouts) async {
      try {
        // Get training sessions in the date range
        final sessions = await _getSessionsInDateRange(clientId, startDate, endDate);
        
        // Convert sessions to AssignedWorkout objects
        // For family sessions, create an AssignedWorkout for each family member
        final sessionWorkouts = <AssignedWorkout>[];
        for (final session in sessions) {
          print('Processing date range session ${session.id} for client $clientId, isFamily: ${session.isBookingForFamily}');
          
          if (session.isBookingForFamily && session.familyMembers != null) {
            // Create an AssignedWorkout for each family member
            for (final member in session.familyMembers!) {
              final memberId = member['uid'] as String?;
              print('  Checking date range family member: $memberId');
              if (memberId != null && memberId == clientId) {
                print('  Creating AssignedWorkout for date range family member $memberId');
                // Only create for the current client being queried
                sessionWorkouts.add(AssignedWorkout.fromSession(session, overrideClientId: memberId));
              }
            }
          } else {
            // Regular session - only for the primary client
            if (session.clientId == clientId) {
              print('  Creating AssignedWorkout for date range primary client');
              sessionWorkouts.add(AssignedWorkout.fromSession(session));
            }
          }
        }
        
        // Log for debugging
        print('Enhanced service: Found ${regularWorkouts.length} regular workouts and ${sessionWorkouts.length} sessions in date range for client $clientId');
        
        // Combine and sort by scheduled date
        final combinedWorkouts = [...regularWorkouts, ...sessionWorkouts];
        combinedWorkouts.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        
        return combinedWorkouts;
      } catch (e) {
        print('Error combining workouts and sessions in date range: $e');
        // Return just regular workouts if session fetching fails
        return regularWorkouts;
      }
    });
  }

  // Get sessions in a date range (works for both trainers and clients)
  Future<List<TrainingSession>> _getSessionsInDateRange(String clientId, DateTime startDate, DateTime endDate) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return [];
      }
      
      // Check if current user is the client or trainer
      if (user.uid == clientId) {
        // Client querying their own sessions - query by clientId and family sessions
        print('Client querying their own sessions in date range');
        
        // Get regular sessions where client is primary booking client
        final regularSnapshot = await _firestore.collection('sessions')
            .where('clientId', isEqualTo: clientId)
            .where('startTime', isGreaterThanOrEqualTo: startDate)
            .where('startTime', isLessThanOrEqualTo: endDate)
            .get();
        
        // Get family sessions in date range where client is a family member
        final familySnapshot = await _firestore.collection('sessions')
            .where('isBookingForFamily', isEqualTo: true)
            .where('startTime', isGreaterThanOrEqualTo: startDate)
            .where('startTime', isLessThanOrEqualTo: endDate)
            .get();
        
        print('Found ${familySnapshot.docs.length} family sessions in date range');
        
        // Combine regular sessions
        List<TrainingSession> clientSessions = regularSnapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        print('Found ${clientSessions.length} regular sessions in date range for client $clientId');
        
        // Add family sessions where this client is a member
        final familySessions = familySnapshot.docs
            .map((doc) => TrainingSession.fromFirestore(doc))
            .where((session) {
              if (session.familyMembers == null) {
                print('Date range session ${session.id} has no family members');
                return false;
              }
              
              print('Date range session ${session.id} family members: ${session.familyMembers}');
              final isClientInFamily = session.familyMembers!.any((member) => member['uid'] == clientId);
              print('Client $clientId is in date range family session ${session.id}: $isClientInFamily');
              
              return isClientInFamily;
            })
            .toList();
        
        print('Found ${familySessions.length} family sessions in date range for client $clientId');
        
        clientSessions.addAll(familySessions);
        
        // Remove duplicates (in case client is both primary and family member)
        final seenIds = <String>{};
        clientSessions = clientSessions.where((session) {
          if (seenIds.contains(session.id)) return false;
          seenIds.add(session.id);
          return true;
        }).toList();
        
        return clientSessions;
      } else {
        // Trainer querying client sessions - query by trainerId then filter
        print('Trainer querying client sessions in date range');
        final snapshot = await _firestore.collection('sessions')
            .where('trainerId', isEqualTo: user.uid)
            .where('startTime', isGreaterThanOrEqualTo: startDate)
            .where('startTime', isLessThanOrEqualTo: endDate)
            .get();

        // Filter sessions for the specific client
        final allSessions = snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
        return allSessions.where((session) => session.clientId == clientId).toList();
      }
    } catch (e) {
      // Only log non-permission errors to avoid spam
      if (!e.toString().contains('permission-denied')) {
        print('Error getting sessions in date range: $e');
      }
      
      // Fallback without date filtering if indexes aren't ready
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return [];
        
        QuerySnapshot snapshot;
        if (user.uid == clientId) {
          // Client fallback
          snapshot = await _firestore.collection('sessions')
              .where('clientId', isEqualTo: clientId)
              .get();
        } else {
          // Trainer fallback
          snapshot = await _firestore.collection('sessions')
              .where('trainerId', isEqualTo: user.uid)
              .get();
        }

        return snapshot.docs
            .map((doc) => TrainingSession.fromFirestore(doc))
            .where((session) => 
                session.clientId == clientId &&
                session.startTime.isAfter(startDate.subtract(Duration(seconds: 1))) &&
                session.startTime.isBefore(endDate.add(Duration(seconds: 1))))
            .toList();
      } catch (fallbackError) {
        // Only log non-permission errors to avoid spam
        if (!fallbackError.toString().contains('permission-denied')) {
          print('Fallback error getting sessions in date range: $fallbackError');
        }
        return [];
      }
    }
  }
} 