import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionTimeSlot extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  final bool isSelected;
  final VoidCallback onTap;
  
  const SessionTimeSlot({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final formattedStartTime = DateFormat('h:mm a').format(startTime);
    final formattedEndTime = DateFormat('h:mm a').format(endTime);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        ),
        child: Text(
          '$formattedStartTime - $formattedEndTime',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected 
              ? Theme.of(context).colorScheme.onPrimary 
              : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
} 