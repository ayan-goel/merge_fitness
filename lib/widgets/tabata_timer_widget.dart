import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/tabata_timer_model.dart';
import '../theme/app_styles.dart';

class TabataTimerWidget extends StatelessWidget {
  final TabataTimer timer;
  final bool isTrainer;
  final Function(String) onTimerAction;
  final VoidCallback? onNewTimer;

  const TabataTimerWidget({
    super.key,
    required this.timer,
    required this.isTrainer,
    required this.onTimerAction,
    this.onNewTimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: timer.isExercisePhase ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Timer display
          Row(
            children: [
              // Circular progress indicator
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    // Background circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey[600]!,
                          width: 4,
                        ),
                      ),
                    ),
                    // Progress circle
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: CircularProgressPainter(
                        progress: timer.progress,
                        color: timer.isExercisePhase ? Colors.green : Colors.orange,
                      ),
                    ),
                    // Time text
                    Center(
                      child: Text(
                        timer.formattedTimeRemaining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Timer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phase indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timer.isExercisePhase ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timer.phaseDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Exercise counter
                    Text(
                      'Exercise ${timer.currentExercise} of ${timer.totalExercises}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    // Timer status
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Controls (only for trainer)
          if (isTrainer) ...[
            const SizedBox(height: 16),
            _buildTrainerControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainerControls() {
    // If timer is finished, show "New Timer" button prominently
    if (timer.isFinished && onNewTimer != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // New Timer button (prominent when finished)
          _buildControlButton(
            icon: Icons.add_circle,
            label: 'New Timer',
            onPressed: onNewTimer!,
            color: Colors.green,
          ),
          
          // Reset button (still available)
          _buildControlButton(
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: () => onTimerAction('reset'),
            color: Colors.blue,
          ),
        ],
      );
    }
    
    // Normal controls for active/paused timers
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Start/Pause button
        _buildControlButton(
          icon: timer.isActive ? Icons.pause : Icons.play_arrow,
          label: timer.isActive ? 'Pause' : 'Start',
          onPressed: () => onTimerAction(timer.isActive ? 'pause' : 'start'),
          color: timer.isActive ? Colors.orange : Colors.green,
        ),
        
        // Stop button
        _buildControlButton(
          icon: Icons.stop,
          label: 'Stop',
          onPressed: () => onTimerAction('stop'),
          color: Colors.red,
        ),
        
        // Reset button
        _buildControlButton(
          icon: Icons.refresh,
          label: 'Reset',
          onPressed: () => onTimerAction('reset'),
          color: Colors.blue,
        ),
        
        // New Timer button (smaller when timer is running)
        if (onNewTimer != null)
          _buildControlButton(
            icon: Icons.add,
            label: 'New',
            onPressed: onNewTimer!,
            color: Colors.purple,
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    if (timer.isFinished) {
      return 'Workout Complete!';
    } else if (timer.isActive) {
      return 'Timer Running';
    } else if (timer.isPaused) {
      return 'Timer Paused';
    } else {
      return 'Ready to Start';
    }
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  CircularProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Progress angle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
} 