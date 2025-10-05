import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout_template_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import '../../theme/app_styles.dart';
import 'create_template_screen.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const AssignWorkoutScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<AssignWorkoutScreen> createState() => _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _weeksController = TextEditingController(text: '2');
  
  DateTime _selectedDate = DateTime.now();
  WorkoutTemplate? _selectedTemplate;
  bool _isAssigning = false;
  bool _isRecurring = false;
  int _recurringWeeks = 2;
  
  @override
  void dispose() {
    _notesController.dispose();
    _weeksController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _assignWorkout() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workout template')),
      );
      return;
    }
    
    setState(() {
      _isAssigning = true;
    });
    
    try {
      // If recurring, create multiple workout instances
      if (_isRecurring && _recurringWeeks > 1) {
        final workouts = <AssignedWorkout>[];

        for (int week = 0; week < _recurringWeeks; week++) {
          final scheduledDate = _selectedDate.add(Duration(days: week * 7));
          final workout = AssignedWorkout.fromTemplate(
            clientId: widget.clientId,
            workoutTemplateId: _selectedTemplate!.id,
            template: _selectedTemplate!,
            scheduledDate: scheduledDate,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            isRecurring: true,
            recurringWeeks: _recurringWeeks,
            recurringDayOfWeek: _selectedDate.weekday,
          );
          workouts.add(workout);
        }

        await _workoutService.assignRecurringWorkouts(workouts);
      } else {
        // Single workout assignment
      final workout = AssignedWorkout.fromTemplate(
        clientId: widget.clientId,
        workoutTemplateId: _selectedTemplate!.id,
        template: _selectedTemplate!,
        scheduledDate: _selectedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      
      await _workoutService.assignWorkout(workout);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isRecurring && _recurringWeeks > 1
              ? '$_recurringWeeks recurring workouts assigned successfully'
              : 'Workout assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning workout: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Workout to ${widget.clientName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selection
            Text(
              'Schedule Date',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                decoration: BoxDecoration(
                  color: AppStyles.offWhite,
                  borderRadius: AppStyles.defaultBorderRadius,
                  border: Border.all(
                    color: AppStyles.slateGray.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppStyles.slateGray.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppStyles.primarySage.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: AppStyles.primarySage,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          DateFormat('MM/dd/yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppStyles.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppStyles.primarySage.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_calendar,
                        size: 18,
                        color: AppStyles.primarySage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24.0),
            
            // Template selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Workout Template',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                  onPressed: () async {
                    final newTemplate = await Navigator.push<WorkoutTemplate>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateTemplateScreen(),
                      ),
                    );
                    
                    if (newTemplate != null) {
                      setState(() {
                        _selectedTemplate = newTemplate;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            
            StreamBuilder<List<WorkoutTemplate>>(
              stream: _workoutService.getTrainerTemplates(_workoutService.currentUserId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final templates = snapshot.data ?? [];
                
                if (templates.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No workout templates found. Create one to get started.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                return Container(
                  decoration: BoxDecoration(
                    color: AppStyles.offWhite,
                    borderRadius: AppStyles.defaultBorderRadius,
                    border: Border.all(
                      color: AppStyles.slateGray.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.slateGray.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<WorkoutTemplate>(
                        value: _selectedTemplate,
                        isExpanded: true,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppStyles.primarySage.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppStyles.primarySage,
                            size: 20,
                          ),
                        ),
                        borderRadius: AppStyles.defaultBorderRadius,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 20,
                                color: AppStyles.slateGray.withOpacity(0.7),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select a workout template',
                                style: TextStyle(
                                  color: AppStyles.slateGray,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        dropdownColor: AppStyles.offWhite,
                        elevation: 3,
                        items: templates.map((template) {
                          return DropdownMenuItem<WorkoutTemplate>(
                            value: template,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppStyles.primarySage.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.fitness_center,
                                      size: 16,
                                      color: AppStyles.primarySage,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                    template.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: AppStyles.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppStyles.mutedBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${template.exercises.length} ex',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppStyles.mutedBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTemplate = value;
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24.0),
            
            // Notes
            Text(
              'Notes (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add notes for the client',
                filled: true,
                fillColor: AppStyles.offWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: AppStyles.defaultBorderRadius,
                  borderSide: BorderSide(
                    color: AppStyles.slateGray.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppStyles.defaultBorderRadius,
                  borderSide: BorderSide(
                    color: AppStyles.slateGray.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppStyles.defaultBorderRadius,
                  borderSide: BorderSide(
                    color: AppStyles.primarySage,
                    width: 1.5,
                  ),
                ),
              ),
              maxLines: 3,
              style: const TextStyle(
                fontSize: 16,
                color: AppStyles.textDark,
              ),
              textInputAction: TextInputAction.done,
            ),
            
            const SizedBox(height: 24.0),

            // Recurring workout options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _isRecurring = !_isRecurring;
                    });
                  },
                  borderRadius: AppStyles.defaultBorderRadius,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: AppStyles.offWhite,
                      borderRadius: AppStyles.defaultBorderRadius,
                      border: Border.all(
                        color: _isRecurring 
                            ? AppStyles.primarySage 
                            : AppStyles.slateGray.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppStyles.slateGray.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isRecurring 
                                ? AppStyles.primarySage.withOpacity(0.1) 
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.repeat,
                            size: 18,
                            color: _isRecurring ? AppStyles.primarySage : AppStyles.slateGray,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            'Repeat weekly',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isRecurring ? AppStyles.primarySage : AppStyles.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          _isRecurring ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _isRecurring ? AppStyles.primarySage : AppStyles.slateGray,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),

                // Duration settings (show when recurring is enabled)
                if (_isRecurring) ...[
                  const SizedBox(height: 16.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: AppStyles.offWhite,
                      borderRadius: AppStyles.defaultBorderRadius,
                      border: Border.all(
                        color: AppStyles.slateGray.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppStyles.slateGray.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'For ',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppStyles.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppStyles.slateGray.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: _weeksController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppStyles.textDark,
                                  ),
                                  onChanged: (value) {
                                    int? weeks = int.tryParse(value);
                                    if (weeks != null) {
                                      if (weeks < 1) weeks = 1;
                                      if (weeks > 52) weeks = 52;
                                      setState(() {
                                        _recurringWeeks = weeks!;
                                      });
                                      if (weeks.toString() != value) {
                                        _weeksController.text = weeks.toString();
                                        _weeksController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _weeksController.text.length),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _recurringWeeks == 1 ? 'week' : 'weeks',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppStyles.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Every ${_getDayName(_selectedDate.weekday)} starting ${DateFormat('MMM d').format(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppStyles.slateGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24.0),
            
            // Selected template preview
            if (_selectedTemplate != null) ...[
              Text(
                'Selected Template Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTemplate!.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedTemplate!.description != null) ...[
                        const SizedBox(height: 8.0),
                        Text(_selectedTemplate!.description!),
                      ],
                      const SizedBox(height: 16.0),
                      Text(
                        '${_selectedTemplate!.exercises.length} exercise${_selectedTemplate!.exercises.length != 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8.0),
                      ...List.generate(_selectedTemplate!.exercises.length, (index) {
                        final exercise = _selectedTemplate!.exercises[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Text('${index + 1}. ${exercise.name}'),
                              const Spacer(),
                              Text('${exercise.sets} × ${exercise.reps}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32.0),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAssigning ? null : _assignWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.primarySage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.defaultBorderRadius,
                  ),
                  elevation: 1,
                  shadowColor: AppStyles.primarySage.withOpacity(0.3),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  disabledBackgroundColor: AppStyles.primarySage.withOpacity(0.5),
                ),
                child: _isAssigning
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Assign Workout'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
} 