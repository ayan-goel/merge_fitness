import 'package:flutter/material.dart';
import '../models/tabata_timer_model.dart';
import '../theme/app_styles.dart';

class TabataConfigDialog extends StatefulWidget {
  const TabataConfigDialog({super.key});

  @override
  State<TabataConfigDialog> createState() => _TabataConfigDialogState();
}

class _TabataConfigDialogState extends State<TabataConfigDialog> {
  int _exerciseTime = 45; // seconds
  int _restTime = 15; // seconds
  int _totalExercises = 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppStyles.offWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Configure Tabata Timer',
        style: TextStyle(
          color: AppStyles.textDark,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Exercise time
            _buildTimeSelector(
              title: 'Exercise Time',
              value: _exerciseTime,
              unit: 'seconds',
              min: 10,
              max: 120,
              onChanged: (value) => setState(() => _exerciseTime = value),
            ),
            
            const SizedBox(height: 20),
            
            // Rest time
            _buildTimeSelector(
              title: 'Rest Time',
              value: _restTime,
              unit: 'seconds',
              min: 5,
              max: 60,
              onChanged: (value) => setState(() => _restTime = value),
            ),
            
            const SizedBox(height: 20),
            
            // Total exercises
            _buildTimeSelector(
              title: 'Total Exercises',
              value: _totalExercises,
              unit: 'rounds',
              min: 1,
              max: 20,
              onChanged: (value) => setState(() => _totalExercises = value),
            ),
            
            const SizedBox(height: 20),
            
            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.primarySage.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppStyles.primarySage.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Workout Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Duration: ${_formatTotalDuration()}',
                    style: const TextStyle(color: AppStyles.slateGray),
                  ),
                  Text(
                    'Format: ${_exerciseTime}s work / ${_restTime}s rest',
                    style: const TextStyle(color: AppStyles.slateGray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppStyles.slateGray,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createTimer,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppStyles.primarySage,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Start Timer'),
        ),
      ],
    );
  }

  Widget _buildTimeSelector({
    required String title,
    required int value,
    required String unit,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppStyles.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Decrease button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppStyles.primarySage.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppStyles.primarySage.withOpacity(0.3),
                ),
              ),
              child: IconButton(
                onPressed: value > min ? () => onChanged(value - (title.contains('Exercise') ? 5 : title.contains('Rest') ? 5 : 1)) : null,
                icon: const Icon(Icons.remove, size: 20),
                color: AppStyles.primarySage,
                padding: EdgeInsets.zero,
              ),
            ),
            
            // Value display
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.dividerGrey,
                  ),
                ),
                child: Text(
                  '$value $unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppStyles.textDark,
                  ),
                ),
              ),
            ),
            
            // Increase button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppStyles.primarySage.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppStyles.primarySage.withOpacity(0.3),
                ),
              ),
              child: IconButton(
                onPressed: value < max ? () => onChanged(value + (title.contains('Exercise') ? 5 : title.contains('Rest') ? 5 : 1)) : null,
                icon: const Icon(Icons.add, size: 20),
                color: AppStyles.primarySage,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        
        // Slider for fine control
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: title.contains('Total') ? (max - min) : ((max - min) ~/ 5),
          activeColor: AppStyles.primarySage,
          inactiveColor: AppStyles.primarySage.withOpacity(0.3),
          onChanged: (double newValue) {
            onChanged(newValue.round());
          },
        ),
      ],
    );
  }

  String _formatTotalDuration() {
    final totalSeconds = (_exerciseTime + _restTime) * _totalExercises;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _createTimer() {
    final config = TabataConfig(
      exerciseTime: _exerciseTime,
      restTime: _restTime,
      totalExercises: _totalExercises,
    );
    
    Navigator.of(context).pop(config);
  }
} 