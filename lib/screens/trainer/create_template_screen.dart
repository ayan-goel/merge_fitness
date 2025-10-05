import 'package:flutter/material.dart';
import '../../models/workout_template_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/auth_service.dart';
import '../../services/video_service.dart';

class CreateTemplateScreen extends StatefulWidget {
  final WorkoutTemplate? template;

  const CreateTemplateScreen({
    super.key,
    this.template,
  });

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  List<ExerciseTemplate> _exercises = [];
  bool _isLoading = false;
  bool _isEditing = false;
  late String _trainerId;
  String? _selectedFullWorkoutVideoId;
  String? _selectedFullWorkoutVideoUrl;
  String? _selectedFullWorkoutVideoName;
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.template != null;
    _loadUserData();
    
    if (_isEditing) {
      _nameController.text = widget.template!.name;
      _descriptionController.text = widget.template?.description ?? '';
      _exercises = List.from(widget.template!.exercises);
      _selectedFullWorkoutVideoId = widget.template!.fullWorkoutVideoId;
      _selectedFullWorkoutVideoUrl = widget.template!.fullWorkoutVideoUrl;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _trainerId = user.uid;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }
  
  void _addExercise() async {
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    final exercise = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (context) => const ExerciseDialog(),
    );
    
    if (exercise != null) {
      setState(() {
        _exercises.add(exercise);
      });
    }
  }
  
  void _editExercise(int index) async {
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    final exercise = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (context) => ExerciseDialog(exercise: _exercises[index]),
    );
    
    if (exercise != null) {
      setState(() {
        _exercises[index] = exercise;
      });
    }
  }
  
  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }
  
  Future<void> _selectFullWorkoutVideo() async {
    final VideoService videoService = VideoService();
    
    // Fetch trainer's videos
    final videosStream = videoService.getTrainerVideos(_trainerId);
    final videos = await videosStream.first;
    
    if (!mounted) return;
    
    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos available. Please upload videos first.')),
      );
      return;
    }
    
    // Show video selection dialog with search
    final selectedVideo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _VideoSelectionDialog(videos: videos);
      },
    );
    
    if (selectedVideo != null) {
      setState(() {
        _selectedFullWorkoutVideoId = selectedVideo['id'] as String?;
        _selectedFullWorkoutVideoUrl = selectedVideo['url'] as String?;
        _selectedFullWorkoutVideoName = selectedVideo['name'] as String?;
      });
    }
  }
  
  void _removeFullWorkoutVideo() {
    setState(() {
      _selectedFullWorkoutVideoId = null;
      _selectedFullWorkoutVideoUrl = null;
      _selectedFullWorkoutVideoName = null;
    });
  }
  
  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }
  
    Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }
    
    // Dismiss keyboard before saving
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });

    try {
      WorkoutTemplate template;
      
      if (_isEditing) {
        template = widget.template!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          exercises: _exercises,
          fullWorkoutVideoId: _selectedFullWorkoutVideoId,
          fullWorkoutVideoUrl: _selectedFullWorkoutVideoUrl,
          updatedAt: DateTime.now(),
        );
        await _workoutService.updateTemplate(template);
      } else {
        template = WorkoutTemplate.create(
          trainerId: _trainerId,
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );
        template = template.copyWith(
          exercises: _exercises,
          fullWorkoutVideoId: _selectedFullWorkoutVideoId,
          fullWorkoutVideoUrl: _selectedFullWorkoutVideoUrl,
        );
        template = await _workoutService.createTemplate(template);
      }
      
      if (mounted) {
        Navigator.pop(context, template);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Workout Template' : 'Create Workout Template'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form fields
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Template Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24.0),
                    
                    // Full Workout Video Section
                    const Text(
                      'Full Workout Video (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    if (_selectedFullWorkoutVideoId != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.video_library,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFullWorkoutVideoName ?? 'Video Selected',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Full workout video',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _removeFullWorkoutVideo,
                              tooltip: 'Remove video',
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _selectFullWorkoutVideo,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Add Full Workout Video'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Exercises section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exercises',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exercise'),
                      onPressed: _addExercise,
                    ),
                  ],
                ),
              ),
              
              // Exercise list
              if (_exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No exercises added yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exercises.length,
                    onReorder: _reorderExercises,
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      return ExerciseListItem(
                        key: Key('exercise_${exercise.id}_$index'),
                        exercise: exercise,
                        onEdit: () => _editExercise(index),
                        onDelete: () => _removeExercise(index),
                      );
                    },
                  ),
                ),
                
              // Extra space at bottom for the bottom button
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56.0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveTemplate,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24.0,
                      width: 24.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0)
                    )
                  : Text(
                      _isEditing ? 'Update Template' : 'Save Template',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseListItem extends StatelessWidget {
  final ExerciseTemplate exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const ExerciseListItem({
    super.key,
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.fitness_center, size: 16.0),
                const SizedBox(width: 8.0),
                Text('${exercise.sets} sets × ${exercise.reps} reps'),
              ],
            ),
            if (exercise.difficulty != null) ...[
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 16.0),
                  const SizedBox(width: 8.0),
                  Text('Difficulty: ${exercise.difficulty}/5'),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.help_outline, size: 16.0),
                  const SizedBox(width: 8.0),
                  Text('Difficulty: N/A'),
                ],
              ),
            ],
            if (exercise.restSeconds != null) ...[
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.timer, size: 16.0),
                  const SizedBox(width: 8.0),
                  Text('Rest: ${exercise.restSeconds} seconds'),
                ],
              ),
            ],
            if (exercise.description != null && exercise.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16.0, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      exercise.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Video Selection Dialog with Search
class _VideoSelectionDialog extends StatefulWidget {
  final List videos;
  
  const _VideoSelectionDialog({required this.videos});
  
  @override
  State<_VideoSelectionDialog> createState() => _VideoSelectionDialogState();
}

class _VideoSelectionDialogState extends State<_VideoSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List _filteredVideos = [];
  
  @override
  void initState() {
    super.initState();
    _filteredVideos = widget.videos;
    _searchController.addListener(_filterVideos);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterVideos() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVideos = widget.videos;
      } else {
        _filteredVideos = widget.videos.where((video) {
          return video.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Full Workout Video'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search videos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            
            // Video list
            Expanded(
              child: _filteredVideos.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty 
                            ? 'No videos available'
                            : 'No videos found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredVideos.length,
                      itemBuilder: (context, index) {
                        final video = _filteredVideos[index];
                        return ListTile(
                          title: Text(video.name),
                          leading: const Icon(Icons.video_library),
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                Navigator.of(context).pop(<String, dynamic>{
                                  'id': video.id,
                                  'url': video.videoUrl,
                                  'name': video.name,
                                });
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class ExerciseDialog extends StatefulWidget {
  final ExerciseTemplate? exercise;
  
  const ExerciseDialog({
    super.key,
    this.exercise,
  });
  
  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  int _selectedDifficulty = 3; // Default to medium difficulty
  
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  
  String? _selectedVideoId;
  String? _selectedVideoUrl;
  String? _selectedVideoName;
  String? _trainerId;
  bool _isLoadingVideos = false;
  List<TrainerVideo> _videos = [];
  
  @override
  void initState() {
    super.initState();
    
    if (widget.exercise != null) {
      final e = widget.exercise!;
      _nameController.text = e.name;
      _descriptionController.text = e.description ?? '';
      _setsController.text = e.sets.toString();
      _repsController.text = e.reps.toString();
      _restController.text = e.restSeconds?.toString() ?? '';
      _selectedVideoId = e.videoId;
      _selectedVideoUrl = e.videoUrl;
      _selectedDifficulty = e.difficulty ?? 3; // Default to 3 if not set
      // Merge any existing notes into the description if both exist
      if (e.notes != null && e.notes!.isNotEmpty) {
        if (_descriptionController.text.isNotEmpty) {
          _descriptionController.text += '\n\n' + e.notes!;
        } else {
          _descriptionController.text = e.notes!;
        }
      }
    } else {
      // Default values
      _setsController.text = '3';
      _repsController.text = '10';
    }
    
    _loadTrainerData();
  }
  
  Future<void> _loadTrainerData() async {
    setState(() {
      _isLoadingVideos = true;
    });
    
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _trainerId = user.uid;
      });
      
      await _loadVideos();
    } catch (e) {
      print('Error loading trainer data: $e');
    } finally {
      setState(() {
        _isLoadingVideos = false;
      });
    }
  }
  
  Future<void> _loadVideos() async {
    if (_trainerId == null) return;
    
    try {
      _videoService.getTrainerVideos(_trainerId!).listen((videos) {
        if (mounted) {
          setState(() {
            _videos = videos;
            
            // If we have a selected video ID, update the URL and name
            if (_selectedVideoId != null) {
              final video = _videos.firstWhere(
                (v) => v.id == _selectedVideoId, 
                orElse: () => TrainerVideo(
                  id: '', 
                  trainerId: '',
                  name: 'Unknown Video',
                  videoUrl: '',
                  createdAt: DateTime.now()
                )
              );
              
              if (video.id.isNotEmpty) {
                _selectedVideoUrl = video.videoUrl;
                _selectedVideoName = video.name;
              }
            }
          });
        }
      });
    } catch (e) {
      print('Error loading videos: $e');
    }
  }
  
  void _selectVideo() async {
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    if (_videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos available. Add videos in Video Gallery.')),
      );
      return;
    }
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Video'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Implement search functionality if needed
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return ListTile(
                      leading: const Icon(Icons.video_library),
                      title: Text(video.name),
                      selected: _selectedVideoId == video.id,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context, video.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          if (_selectedVideoId != null)
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, 'clear');
              },
              child: const Text('Clear Selection'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
    );
    
    if (result == null) {
      return;
    }
    
    if (result == 'clear') {
      setState(() {
        _selectedVideoId = null;
        _selectedVideoUrl = null;
        _selectedVideoName = null;
      });
      return;
    }
    
    final selectedVideo = _videos.firstWhere((v) => v.id == result);
    setState(() {
      _selectedVideoId = selectedVideo.id;
      _selectedVideoUrl = selectedVideo.videoUrl;
      _selectedVideoName = selectedVideo.name;
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    super.dispose();
  }
  
  ExerciseTemplate _createExercise() {
    // Generate a truly unique ID
    final id = widget.exercise?.id ?? 'exercise_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString()}';

    return ExerciseTemplate(
      id: id,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      videoUrl: _selectedVideoUrl,
      videoId: _selectedVideoId,
      sets: int.parse(_setsController.text),
      reps: int.parse(_repsController.text),
      restSeconds: _restController.text.isEmpty ? null : int.parse(_restController.text),
      notes: null, // No longer using separate notes field
      difficulty: _selectedDifficulty,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise == null ? 'Add Exercise' : 'Edit Exercise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Exercise Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description/Instructions (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              // Demo video selector
              InkWell(
                onTap: _selectVideo,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_library,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _isLoadingVideos
                            ? const Text('Loading videos...')
                            : Text(
                                _selectedVideoName ?? 'Select Demo Video (Optional)',
                                style: TextStyle(
                                  color: _selectedVideoName != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsController,
                      decoration: InputDecoration(
                        labelText: 'Sets',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      decoration: InputDecoration(
                        labelText: 'Reps',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _restController,
                decoration: InputDecoration(
                  labelText: 'Rest Seconds (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Invalid';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Difficulty Level',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final difficulty = index + 1;
                        final isSelected = _selectedDifficulty == difficulty;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDifficulty = difficulty;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                difficulty.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '1 - Easiest',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '5 - Hardest',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _createExercise());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 