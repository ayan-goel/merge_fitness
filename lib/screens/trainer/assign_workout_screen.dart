import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout_template_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import '../../theme/app_styles.dart';
import 'create_template_screen.dart';
import 'template_preview_screen.dart';

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
  final TextEditingController _weeksController = TextEditingController(
    text: '4',
  );

  DateTime _selectedDate = DateTime.now();
  WorkoutTemplate? _selectedTemplate;
  bool _isAssigning = false;
  bool _isRecurring = false;
  int _recurringWeeks = 4;
  Set<int> _selectedDays = {}; // Days of week (1=Monday, 7=Sunday)

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

    // Validate recurring settings
    if (_isRecurring && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one day for recurring workouts',
          ),
        ),
      );
      return;
    }

    // Navigate to preview screen first
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => TemplatePreviewScreen(
              template: _selectedTemplate!,
              clientName: widget.clientName,
              scheduledDate: _selectedDate,
              notes:
                  _notesController.text.isEmpty ? null : _notesController.text,
              isRecurring: _isRecurring,
              recurringWeeks: _recurringWeeks,
            ),
      ),
    );

    // If user confirmed assignment, proceed with assignment
    if (confirmed != true) {
      return; // User cancelled or navigated back
    }

    setState(() {
      _isAssigning = true;
    });

    try {
      // If recurring with selected days, create multiple workout instances
      if (_isRecurring && _selectedDays.isNotEmpty) {
        final workouts = <AssignedWorkout>[];

        // Get the start of the week (Monday) for the selected date
        final startDate = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );

        for (int week = 0; week < _recurringWeeks; week++) {
          // For each selected day in the week
          for (int dayOfWeek in _selectedDays) {
            // Calculate the date for this day of the week
            final scheduledDate = startDate.add(
              Duration(days: (week * 7) + (dayOfWeek - 1)),
            );

            // Only create workout if it's today or in the future
            if (!scheduledDate.isBefore(
              DateTime.now().subtract(const Duration(days: 1)),
            )) {
              final workout = AssignedWorkout.fromTemplate(
                clientId: widget.clientId,
                workoutTemplateId: _selectedTemplate!.id,
                template: _selectedTemplate!,
                scheduledDate: scheduledDate,
                notes:
                    _notesController.text.isEmpty
                        ? null
                        : _notesController.text,
                isRecurring: true,
                recurringWeeks: _recurringWeeks,
                recurringDayOfWeek: dayOfWeek,
              );
              workouts.add(workout);
            }
          }
        }

        if (workouts.isEmpty) {
          throw Exception('No valid workout dates selected');
        }

        await _workoutService.assignRecurringWorkouts(workouts);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${workouts.length} workouts assigned successfully',
              ),
            ),
          );
        }
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

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout assigned successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error assigning workout: $e')));
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
      appBar: AppBar(title: Text('Assign Workout to ${widget.clientName}')),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
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
              stream: _workoutService.getTrainerTemplates(
                _workoutService.currentUserId ?? '',
              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        dropdownColor: AppStyles.offWhite,
                        elevation: 3,
                        items:
                            templates.map((template) {
                              return DropdownMenuItem<WorkoutTemplate>(
                                value: template,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppStyles.primarySage
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppStyles.mutedBlue
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
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
              style: const TextStyle(fontSize: 16, color: AppStyles.textDark),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 24.0),

            // Recurring workout options
            Text(
              'Recurring Schedule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),

            // Toggle for recurring
            InkWell(
              onTap: () {
                setState(() {
                  _isRecurring = !_isRecurring;
                  if (_isRecurring && _selectedDays.isEmpty) {
                    // Auto-select the day of the selected date
                    _selectedDays.add(_selectedDate.weekday);
                  }
                });
              },
              borderRadius: AppStyles.defaultBorderRadius,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppStyles.offWhite,
                  borderRadius: AppStyles.defaultBorderRadius,
                  border: Border.all(
                    color:
                        _isRecurring
                            ? AppStyles.primarySage
                            : AppStyles.slateGray.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            _isRecurring
                                ? AppStyles.primarySage.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.repeat,
                        size: 20,
                        color:
                            _isRecurring
                                ? AppStyles.primarySage
                                : AppStyles.slateGray,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repeat this workout',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  _isRecurring
                                      ? AppStyles.primarySage
                                      : AppStyles.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!_isRecurring)
                            Text(
                              'Assign once on ${DateFormat('MMM d').format(_selectedDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppStyles.slateGray,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      _isRecurring
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          _isRecurring
                              ? AppStyles.primarySage
                              : AppStyles.slateGray,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            // Recurring settings (show when recurring is enabled)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child:
                  _isRecurring
                      ? Column(
                        children: [
                          const SizedBox(height: 16.0),
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppStyles.defaultBorderRadius,
                              border: Border.all(
                                color: AppStyles.primarySage.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppStyles.primarySage.withOpacity(
                                    0.05,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Duration selector
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month,
                                      size: 20,
                                      color: AppStyles.primarySage,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Duration',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppStyles.offWhite,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppStyles.primarySage
                                              .withOpacity(0.3),
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
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppStyles.textDark,
                                          ),
                                          onSubmitted: (value) {
                                            // Only update on submit to avoid glitching
                                            int? weeks = int.tryParse(value);
                                            if (weeks != null) {
                                              if (weeks < 1) weeks = 1;
                                              if (weeks > 52) weeks = 52;
                                              _weeksController.text =
                                                  weeks.toString();
                                              _weeksController.selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset:
                                                          _weeksController
                                                              .text
                                                              .length,
                                                    ),
                                                  );
                                              setState(() {
                                                _recurringWeeks = weeks!;
                                              });
                                            }
                                            FocusScope.of(context).unfocus();
                                          },
                                          onChanged: (value) {
                                            // Only validate without setState to prevent glitching
                                            int? weeks = int.tryParse(value);
                                            if (weeks != null) {
                                              if (weeks < 1) weeks = 1;
                                              if (weeks > 52) weeks = 52;
                                              _recurringWeeks = weeks;
                                              if (weeks.toString() != value) {
                                                _weeksController.text =
                                                    weeks.toString();
                                                _weeksController.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            _weeksController
                                                                .text
                                                                .length,
                                                      ),
                                                    );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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

                                const SizedBox(height: 24),

                                // Days of week selector
                                Row(
                                  children: [
                                    Icon(
                                      Icons.today,
                                      size: 20,
                                      color: AppStyles.primarySage,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Days of the week',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildDayChip('Mon', 1),
                                    _buildDayChip('Tue', 2),
                                    _buildDayChip('Wed', 3),
                                    _buildDayChip('Thu', 4),
                                    _buildDayChip('Fri', 5),
                                    _buildDayChip('Sat', 6),
                                    _buildDayChip('Sun', 7),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Summary
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppStyles.primarySage.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppStyles.primarySage.withOpacity(
                                        0.2,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: AppStyles.primarySage,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _buildSummaryText(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppStyles.primarySage,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                      ...List.generate(_selectedTemplate!.exercises.length, (
                        index,
                      ) {
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
                  disabledBackgroundColor: AppStyles.primarySage.withOpacity(
                    0.5,
                  ),
                ),
                child:
                    _isAssigning
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
                            Icon(Icons.preview, size: 20),
                            SizedBox(width: 8),
                            Text('Preview & Assign'),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int dayOfWeek) {
    final isSelected = _selectedDays.contains(dayOfWeek);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(dayOfWeek);
          } else {
            _selectedDays.add(dayOfWeek);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppStyles.primarySage : AppStyles.offWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? AppStyles.primarySage
                    : AppStyles.slateGray.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppStyles.textDark,
          ),
        ),
      ),
    );
  }

  String _buildSummaryText() {
    if (_selectedDays.isEmpty) {
      return 'Select days to repeat this workout';
    }

    final sortedDays = _selectedDays.toList()..sort();
    final dayNames = sortedDays.map((day) => _getDayName(day)).toList();

    final totalWorkouts = _selectedDays.length * _recurringWeeks;

    String daysText;
    if (dayNames.length == 1) {
      daysText = 'every ${dayNames[0]}';
    } else if (dayNames.length == 2) {
      daysText = 'every ${dayNames[0]} and ${dayNames[1]}';
    } else {
      final lastDay = dayNames.removeLast();
      daysText = 'every ${dayNames.join(', ')}, and $lastDay';
    }

    return 'This will create $totalWorkouts workout${totalWorkouts == 1 ? '' : 's'} - $daysText for ${_recurringWeeks} week${_recurringWeeks == 1 ? '' : 's'}';
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
