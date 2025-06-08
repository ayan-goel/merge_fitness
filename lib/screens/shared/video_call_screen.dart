import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/video_call_model.dart';
import '../../models/tabata_timer_model.dart';
import '../../services/video_call_service.dart';
import '../../services/tabata_service.dart';
import '../../theme/app_styles.dart';
import '../../widgets/tabata_timer_widget.dart';
import '../../widgets/tabata_config_dialog.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isTrainer;
  final String sessionId;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isTrainer,
    required this.sessionId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  final TabataService _tabataService = TabataService();

  VideoCall? _currentCall;
  TabataTimer? _currentTimer;
  
  bool _isLocalVideoMuted = false;
  bool _isLocalAudioMuted = false;
  bool _isJoined = false;
  bool _isLoading = true;
  int? _remoteUid;
  
  StreamSubscription<VideoCall?>? _callSubscription;
  StreamSubscription<TabataTimer?>? _timerSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    print('VideoCallScreen: dispose() called');
    
    // Cancel all subscriptions immediately to prevent further updates
    _callSubscription?.cancel();
    _timerSubscription?.cancel();
    _callSubscription = null;
    _timerSubscription = null;
    
    // Mark as not joined to prevent any further operations
    _isJoined = false;
    
    // Dispose services
    _tabataService.dispose();
    
    // Schedule cleanup of video service for next frame to avoid blocking dispose
    if (_videoCallService.engine != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _videoCallService.forceCleanup().catchError((e) {
          print('VideoCallScreen: Error in post-dispose cleanup: $e');
        });
      });
    }
    
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      print('VideoCallScreen: Starting call initialization...');
      
      // Skip permission_handler completely and let Agora handle permissions
      print('VideoCallScreen: Initializing Agora directly...');
      
      try {
        // Initialize Agora - it will request permissions internally
        await _videoCallService.initializeAgora();
        print('VideoCallScreen: Agora initialized successfully');
      } catch (e) {
        print('VideoCallScreen: Agora initialization failed: $e');
        
        // If Agora fails, it might be permissions - show user-friendly message
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Camera & Microphone Access'),
              content: const Text(
                'This video call requires camera and microphone access. Please ensure these permissions are enabled in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          
          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
        
        _showErrorAndExit('Please enable camera and microphone permissions in device settings, then try again.');
        return;
      }
      
      print('VideoCallScreen: Setting up event handlers...');
      // Set up event handlers
      _videoCallService.setEventHandlers(
        onUserJoined: _onUserJoined,
        onUserOffline: _onUserOffline,
      );

      print('VideoCallScreen: Joining video call...');
      // Join the call
      await _videoCallService.joinVideoCall(widget.callId, widget.isTrainer);
      
      print('VideoCallScreen: Setting up listeners...');
      // Start listening to call updates
      _callSubscription = _videoCallService
          .streamVideoCall(widget.callId)
          .listen(_onCallUpdated);

      // Start listening to timer updates
      _timerSubscription = _tabataService
          .streamTabataTimerByCallId(widget.callId)
          .listen(_onTimerUpdated);

      print('VideoCallScreen: Call initialization complete!');
      setState(() {
        _isJoined = true;
        _isLoading = false;
      });
    } catch (e) {
      print('VideoCallScreen: Error during initialization: $e');
      _showErrorAndExit('Failed to join call: $e');
    }
  }

  void _onCallUpdated(VideoCall? call) {
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Ignoring call update - widget unmounted or not joined');
      return;
    }
    
    final previousCall = _currentCall;
    setState(() {
      _currentCall = call;
    });
    
    // If call ended, properly clean up and exit
    if (call?.isEnded == true) {
      print('VideoCallScreen: Call ended detected, performing cleanup...');
      _handleCallEnded();
      return;
    }
    
    // If we're a client and trainer just left, also clean up and exit
    if (!widget.isTrainer && call != null) {
      final trainerJustLeft = (previousCall?.trainerJoined == true && call.trainerJoined == false);
      if (trainerJustLeft) {
        print('VideoCallScreen: Trainer left, client leaving...');
        _handleCallEnded();
        return;
      }
    }
    
    // If we're a trainer and client just left, update UI but don't exit
    if (widget.isTrainer && call != null) {
      final clientJustLeft = (previousCall?.clientJoined == true && call.clientJoined == false);
      if (clientJustLeft) {
        print('VideoCallScreen: Client left the call');
        // Trainer stays in call, just update UI
      }
    }
  }

  Future<void> _handleCallEnded() async {
    try {
      print('VideoCallScreen: Handling call ended...');
      
      // Prevent multiple cleanup calls or operations after dispose
      if (!_isJoined || !mounted) {
        print('VideoCallScreen: Already cleaning up or widget disposed, skipping...');
        return;
      }
      
      // First, make sure we leave the Agora channel properly
      await _videoCallService.engine?.leaveChannel();
      
      // Then do full cleanup
      await _cleanup();
      
      // Finally exit the screen (only if still mounted)
      if (mounted) {
        await _exitCall();
      }
    } catch (e) {
      print('VideoCallScreen: Error handling call ended: $e');
      // Even if cleanup fails, try to exit (only if still mounted)
      if (mounted) {
        await _exitCall();
      }
    }
  }

  void _onTimerUpdated(TabataTimer? timer) {
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Ignoring timer update - widget unmounted or not joined');
      return;
    }
    
    setState(() {
      _currentTimer = timer;
    });
  }

  void _onUserJoined(RtcConnection connection, int remoteUid, int elapsed) {
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Ignoring user joined - widget unmounted or not joined');
      return;
    }
    
    setState(() {
      _remoteUid = remoteUid;
    });
  }

  void _onUserOffline(RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
    print('VideoCallScreen: User $remoteUid went offline with reason: $reason');
    
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Ignoring user offline - widget unmounted or not joined');
      return;
    }
    
    setState(() {
      _remoteUid = null;
    });
    
    // If we're the client and the remote user (trainer) went offline, 
    // we should also leave to ensure clean state
    if (!widget.isTrainer && reason == UserOfflineReasonType.userOfflineQuit) {
      print('VideoCallScreen: Remote user quit, client should also leave...');
      // Don't immediately exit here as it might be handled by the call status update
      // Just log for debugging
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      await _videoCallService.toggleMicrophone(!_isLocalAudioMuted);
      setState(() {
        _isLocalAudioMuted = !_isLocalAudioMuted;
      });
    } catch (e) {
      _showSnackBar('Failed to toggle microphone: $e');
    }
  }

  Future<void> _toggleCamera() async {
    try {
      await _videoCallService.toggleCamera(!_isLocalVideoMuted);
      setState(() {
        _isLocalVideoMuted = !_isLocalVideoMuted;
      });
    } catch (e) {
      _showSnackBar('Failed to toggle camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _videoCallService.switchCamera();
    } catch (e) {
      _showSnackBar('Failed to switch camera: $e');
    }
  }

  Future<void> _endCall() async {
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Cannot end call - widget disposed or not joined');
      return;
    }
    
    try {
      print('VideoCallScreen: Ending call...');
      
      // Add timeout to prevent hanging
      await Future.wait([
        _cleanup(),
        _videoCallService.endVideoCall(widget.callId),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('VideoCallScreen: End call operations timed out');
          return [];
        },
      );
      
      if (mounted) {
        await _exitCall();
      }
    } catch (e) {
      print('VideoCallScreen: Error ending call: $e');
      _showSnackBar('Failed to end call: $e');
      if (mounted) {
        await _exitCall();
      }
    }
  }

  Future<void> _leaveCall() async {
    if (!mounted || !_isJoined) {
      print('VideoCallScreen: Cannot leave call - widget disposed or not joined');
      return;
    }
    
    try {
      print('VideoCallScreen: Leaving call...');
      
      // Add timeout to prevent hanging
      await Future.wait([
        _cleanup(),
        _videoCallService.leaveVideoCall(widget.callId, widget.isTrainer),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('VideoCallScreen: Leave call operations timed out');
          return [];
        },
      );
      
      if (mounted) {
        await _exitCall();
      }
    } catch (e) {
      print('VideoCallScreen: Error leaving call: $e');
      _showSnackBar('Failed to leave call: $e');
      if (mounted) {
        await _exitCall();
      }
    }
  }

  Future<void> _handleBackPress() async {
    // Handle back button press properly
    print('VideoCallScreen: Back button pressed');
    if (widget.isTrainer) {
      await _endCall();
    } else {
      await _leaveCall();
    }
  }

  Future<void> _exitCall() async {
    print('VideoCallScreen: Exiting call...');
    if (mounted) {
      try {
        // First try normal pop
        Navigator.of(context, rootNavigator: false).pop();
        print('VideoCallScreen: Navigation pop completed');
      } catch (e) {
        print('VideoCallScreen: Error with normal pop: $e');
        if (mounted) {
          try {
            // If that fails, try root navigator
            Navigator.of(context, rootNavigator: true).pop();
            print('VideoCallScreen: Root navigator pop completed');
          } catch (e2) {
            print('VideoCallScreen: Error with root navigator pop: $e2');
            if (mounted) {
              try {
                // Last resort - force navigation to home
                Navigator.of(context).popUntil((route) => route.isFirst);
                print('VideoCallScreen: Force navigation to first route completed');
              } catch (e3) {
                print('VideoCallScreen: All navigation attempts failed: $e3');
              }
            }
          }
        }
      }
    }
  }

  Future<void> _cleanup() async {
    try {
      print('VideoCallScreen: Starting cleanup...');
      
      // First, ensure we're not in joined state to prevent further operations
      _isJoined = false;
      
      // Cancel subscriptions first
      await _callSubscription?.cancel();
      await _timerSubscription?.cancel();
      _callSubscription = null;
      _timerSubscription = null;
      
      // Explicitly leave the Agora channel and dispose
      if (_videoCallService.engine != null) {
        print('VideoCallScreen: Leaving Agora channel...');
        await _videoCallService.engine!.leaveChannel();
      }
      
      // Force cleanup of video service to ensure all resources are released
      await _videoCallService.forceCleanup();
      
      // Dispose other services
      _tabataService.dispose();
      
      // Reset state variables
      _remoteUid = null;
      _currentCall = null;
      _currentTimer = null;
      
      print('VideoCallScreen: Cleanup completed successfully');
    } catch (e) {
      print('VideoCallScreen: Error during cleanup: $e');
      // Continue anyway - don't let cleanup errors block navigation
    }
  }

  void _showErrorAndExit(String message) {
    if (mounted && _isJoined) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop();
      } catch (e) {
        print('VideoCallScreen: Error showing error message: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted && _isJoined) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        print('VideoCallScreen: Error showing snackbar: $e');
      }
    }
  }

  Future<void> _showTabataConfigDialog() async {
    // If there's an active timer, ask for confirmation to replace it
    if (_currentTimer != null && !_currentTimer!.isFinished) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Current Timer?'),
          content: Text(
            'There is currently ${_currentTimer!.isActive ? 'an active' : 'a paused'} '
            'Tabata timer. Do you want to stop it and start a new one?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace Timer'),
            ),
          ],
        ),
      );
      
      if (shouldReplace != true) return;
      
      // Stop the current timer before creating a new one
      try {
        await _tabataService.stopTimer(_currentTimer!.id);
        // Optionally delete the old timer
        await _tabataService.deleteTabataTimer(_currentTimer!.id);
      } catch (e) {
        print('Error stopping/deleting previous timer: $e');
        // Continue anyway to create new timer
      }
    }

    final config = await showDialog<TabataConfig>(
      context: context,
      builder: (context) => const TabataConfigDialog(),
    );

    if (config != null) {
      try {
        final timer = await _tabataService.createTabataTimer(widget.callId, config);
        setState(() {
          _currentTimer = timer;
        });
        _showSnackBar('New Tabata timer created!');
      } catch (e) {
        _showSnackBar('Failed to create timer: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return WillPopScope(
        onWillPop: () async {
          await _cleanup();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Joining call...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        print('VideoCallScreen: WillPopScope triggered');
        await _handleBackPress();
        return false; // Let our custom handler manage the navigation
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video views
            _buildVideoViews(),
            
            // Call controls
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: _buildCallControls(),
            ),
            
            // Tabata timer overlay (positioned above call controls)
            if (_currentTimer != null)
              Positioned(
                bottom: 140, // Position above the call controls (50 + 90 for controls height)
                left: 16,
                right: 16,
                child: TabataTimerWidget(
                  timer: _currentTimer!,
                  isTrainer: widget.isTrainer,
                  onTimerAction: _handleTimerAction,
                  onNewTimer: widget.isTrainer ? _showTabataConfigDialog : null,
                ),
              ),
            
            // Top bar with call info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoViews() {
    return Stack(
      children: [
        // Remote video (full screen)
        if (_remoteUid != null && _videoCallService.engine != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _videoCallService.engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: _currentCall?.channelName),
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for ${widget.isTrainer ? 'client' : 'trainer'} to join...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Local video (small overlay)
        Positioned(
          top: 100,
          right: 16,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _isLocalVideoMuted
                  ? Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                    )
                  : _videoCallService.engine != null
                      ? AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _videoCallService.engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBackPress,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Training Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentCall != null)
                  Text(
                    _remoteUid != null ? 'Connected' : 'Connecting...',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.isTrainer)
            IconButton(
              onPressed: _showTabataConfigDialog,
              icon: const Icon(Icons.timer, color: Colors.white),
              tooltip: _currentTimer == null ? 'Start Tabata Timer' : 'Start New Tabata Timer',
            ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone toggle
          _buildControlButton(
            icon: _isLocalAudioMuted ? Icons.mic_off : Icons.mic,
            onPressed: _toggleMicrophone,
            backgroundColor: _isLocalAudioMuted ? Colors.red : Colors.grey[800] ?? Colors.grey,
          ),
          
          // Camera toggle
          _buildControlButton(
            icon: _isLocalVideoMuted ? Icons.videocam_off : Icons.videocam,
            onPressed: _toggleCamera,
            backgroundColor: _isLocalVideoMuted ? Colors.red : Colors.grey[800] ?? Colors.grey,
          ),
          
          // Switch camera
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onPressed: _switchCamera,
            backgroundColor: Colors.grey[800] ?? Colors.grey,
          ),
          
          // End call
          _buildControlButton(
            icon: Icons.call_end,
            onPressed: widget.isTrainer ? _endCall : _leaveCall,
            backgroundColor: Colors.red,
            size: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  Future<void> _handleTimerAction(String action) async {
    if (_currentTimer == null) return;

    try {
      switch (action) {
        case 'start':
          await _tabataService.startTimer(_currentTimer!.id);
          if (widget.isTrainer) {
            _tabataService.startLocalTimer(_currentTimer!.id, _currentTimer!);
          }
          break;
        case 'pause':
          await _tabataService.pauseTimer(_currentTimer!.id);
          break;
        case 'stop':
          await _tabataService.stopTimer(_currentTimer!.id);
          break;
        case 'reset':
          await _tabataService.resetTimer(_currentTimer!.id);
          break;
      }
    } catch (e) {
      _showSnackBar('Timer action failed: $e');
    }
  }
} 