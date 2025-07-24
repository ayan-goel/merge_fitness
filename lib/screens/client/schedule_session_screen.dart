import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/calendly_service.dart';
import '../../services/payment_service.dart';
import '../../services/family_service.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../models/family_model.dart';
import '../../widgets/session_time_slot.dart';
import '../../widgets/profile_avatar.dart';
import '../../theme/app_styles.dart';


class ScheduleSessionScreen extends StatefulWidget {
  final String clientId;
  final String trainerId;
  final String trainerName;
  
  const ScheduleSessionScreen({
    super.key,
    required this.clientId,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  State<ScheduleSessionScreen> createState() => _ScheduleSessionScreenState();
}

class _ScheduleSessionScreenState extends State<ScheduleSessionScreen> 
    with TickerProviderStateMixin {
  final CalendlyService _calendlyService = CalendlyService();
  final PaymentService _paymentService = PaymentService();
  final FamilyService _familyService = FamilyService();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableTimeSlots = [];
  Map<String, dynamic>? _selectedTimeSlot;
  bool _isSubmitting = false;
  UserModel? _trainer;
  UserModel? _currentUser;
  Family? _family;
  List<UserModel> _familyMembers = [];
  Set<String> _selectedFamilyMembers = {};
  bool _isBookingForFamily = false;
  
  // Group time slots by date
  Map<DateTime, List<Map<String, dynamic>>> _timeSlotsByDate = {};
  
  // Track which date sections are expanded
  Set<DateTime> _expandedDates = {};
  
  // Animation controllers for each date
  Map<DateTime, AnimationController> _animationControllers = {};
  Map<DateTime, Animation<double>> _slideAnimations = {};
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
    _loadAvailability();
    _loadFamilyData();
  }
  
  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    // Dispose animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimationControllers(List<DateTime> dates) {
    // Dispose existing controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    _slideAnimations.clear();
    
    // Create new controllers for each date
    for (final date in dates) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
      
      _animationControllers[date] = controller;
      _slideAnimations[date] = animation;
    }
  }
  
  Future<void> _loadTrainerData() async {
    try {
      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.trainerId)
          .get();
      
      if (trainerDoc.exists) {
        setState(() {
          _trainer = UserModel.fromMap(
            trainerDoc.data() as Map<String, dynamic>,
            uid: trainerDoc.id,
            email: trainerDoc.data()?['email'] ?? '',
          );
        });
      }
    } catch (e) {
      print("Error loading trainer data: $e");
    }
  }

  Future<void> _loadFamilyData() async {
    try {
      // Load current user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();
      
      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(
          userDoc.data() as Map<String, dynamic>,
          uid: userDoc.id,
          email: userDoc.data()?['email'] ?? '',
        );
      }

      // Load family data if user is in a family
      if (_currentUser?.familyId != null) {
        final family = await _familyService.getCurrentUserFamily();
        if (family != null) {
          // Verify user is actually a member of this family
          if (family.isMember(widget.clientId)) {
            final members = await _familyService.getFamilyMembers(family.id);
            
            setState(() {
              _family = family;
              _familyMembers = members;
              // Pre-select current user
              _selectedFamilyMembers = {widget.clientId};
            });
            
            print('Family data loaded: User ${widget.clientId} is member of family ${family.id}');
          } else {
            print('User ${widget.clientId} is not a member of family ${family.id}, clearing family data');
            setState(() {
              _family = null;
              _familyMembers = [];
              _selectedFamilyMembers = {};
              _isBookingForFamily = false;
            });
          }
        } else {
          // Family is null, clear any existing family state
          setState(() {
            _family = null;
            _familyMembers = [];
            _selectedFamilyMembers = {};
            _isBookingForFamily = false;
          });
        }
      }
    } catch (e) {
      print("Error loading family data: $e");
    }
  }
  
  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get availability starting 1 hour from now (to ensure start_time is always in the future)
      // and ending 7 days later (Calendly limit)
      final now = DateTime.now();
      final startDate = now.add(const Duration(hours: 1));
      final endDate = startDate.add(const Duration(days: 7));
      
      print('ScheduleSessionScreen: Loading availability from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      final slots = await _calendlyService.getTrainerAvailability(
        widget.trainerId,
        startDate: startDate,
        endDate: endDate,
      );
      
      // Group time slots by date
      final Map<DateTime, List<Map<String, dynamic>>> slotsByDate = {};
      
      for (final slot in slots) {
        final startTime = slot['start_time'] as DateTime;
        final normalizedDate = DateTime(startTime.year, startTime.month, startTime.day);
        
        if (!slotsByDate.containsKey(normalizedDate)) {
          slotsByDate[normalizedDate] = [];
        }
        
        slotsByDate[normalizedDate]!.add(slot);
      }
      
      setState(() {
        _availableTimeSlots = slots;
        _timeSlotsByDate = slotsByDate;
        _isLoading = false;
        // Initialize animation controllers for each date
        _initializeAnimationControllers(slotsByDate.keys.toList());
        
        // All date sections start collapsed
      });
      
      print('ScheduleSessionScreen: Loaded ${slots.length} available time slots across ${slotsByDate.length} days');
    } catch (e) {
      print('Error loading availability: $e');
      
      String errorMessage = 'Unable to load trainer availability';
      String debugInfo = '';
      
      // Check for specific error types and provide better user messages
      if (e.toString().contains('start_time must be in the future')) {
        errorMessage = 'Error with scheduling timeframe. Please try again.';
        debugInfo = 'Time validation error';
      } else if (e.toString().contains('date range can be no greater than 1 week')) {
        errorMessage = 'Cannot fetch availability beyond 7 days. Please try again.';
        debugInfo = 'Date range error';
      } else if (e.toString().contains('Trainer has not connected their Calendly account')) {
        errorMessage = 'This trainer has not fully set up their scheduling calendar yet.';
        debugInfo = 'No Calendly token found';
      } else if (e.toString().contains('Trainer has no event types configured')) {
        errorMessage = 'This trainer has not created any appointment types yet.';
        debugInfo = 'No event types in Calendly';
      } else if (e.toString().contains('Trainer has no active event types')) {
        errorMessage = 'This trainer does not have any active calendars configured.';
        debugInfo = 'Event types exist but none are active';
      } else if (e.toString().contains('token has expired') || e.toString().contains('401')) {
        errorMessage = 'Trainer\'s calendar connection has expired. They need to reconnect.';
        debugInfo = 'Authentication token expired';
      } else {
        debugInfo = 'Unknown error: ${e.toString()}';
      }
      
      // Add trainer ID to debug info
      debugInfo += '\nTrainer ID: ${widget.trainerId}';
      
      setState(() {
        _isLoading = false;
      });
      
      // Show error snackbar with debug option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Debug',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug Information'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Technical Details:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(debugInfo),
                        const SizedBox(height: 16),
                        const Text(
                          'Use the debug tool (bug icon in top right) for detailed connection analysis.',
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),

                    ],
                  ),
                );
              },
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }
  
  Future<void> _scheduleSession() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }
    
    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }

    // If booking for family, ensure at least one member is selected
    if (_isBookingForFamily && _selectedFamilyMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one family member')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Determine who pays for the session with proper validation
      String payingClientId = widget.clientId;
      if (_isBookingForFamily && _family != null) {
        // CRITICAL: Double-check that user is still a family member before using organizer's credits
        final isStillMember = _family!.isMember(widget.clientId);
        if (!isStillMember) {
          throw Exception('You are no longer a member of this family. Please refresh the page.');
        }
        
        // Family organizer pays for family sessions
        payingClientId = _family!.organizerId;
        
        print('Family booking: User ${widget.clientId} booking for family ${_family!.id}, organizer ${_family!.organizerId} pays');
      } else {
        print('Individual booking: User ${widget.clientId} pays for their own session');
      }

      // Check if paying client has available sessions before booking
      final canBook = await _paymentService.canBookSession(
        payingClientId,
        widget.trainerId,
      );
      
      if (!canBook) {
        setState(() {
          _isSubmitting = false;
        });
        
        // Show dialog asking if they want to purchase sessions
        final shouldPurchase = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Sessions Remaining'),
            content: Text(
              _isBookingForFamily
                ? 'Your family organizer doesn\'t have any sessions remaining. Would you like to purchase more sessions to book this appointment?'
                : 'You don\'t have any sessions remaining. Would you like to purchase more sessions to book this appointment?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Purchase Sessions'),
              ),
            ],
          ),
        );
        
        if (shouldPurchase == true && mounted) {
          // Navigate to payment screen
          Navigator.pushNamed(context, '/payment');
        }
        return;
      }
      
      // Consume a session before booking
      final sessionConsumed = await _paymentService.consumeSession(
        payingClientId,
        widget.trainerId,
      );
      
      if (!sessionConsumed) {
        throw Exception('Failed to consume session. Please try again.');
      }
      
      // Prepare family member information for the session
      List<Map<String, dynamic>> familyMemberInfo = [];
      if (_isBookingForFamily && _selectedFamilyMembers.isNotEmpty) {
        familyMemberInfo = _familyMembers
            .where((member) => _selectedFamilyMembers.contains(member.uid))
            .map((member) => {
              'uid': member.uid,
              'name': member.displayName,
              'email': member.email,
            })
            .toList();
      }

      // Use the scheduleSession method which handles Calendly API integration
      await _calendlyService.scheduleSession(
        trainerId: widget.trainerId, 
        clientId: widget.clientId,
        timeSlot: _selectedTimeSlot!,
        location: _locationController.text,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        familyMembers: familyMemberInfo,
        isBookingForFamily: _isBookingForFamily,
        payingClientId: payingClientId,
      );
      
      // Show success message and pop back
      if (mounted) {
        final memberCount = _isBookingForFamily ? _selectedFamilyMembers.length : 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Session scheduled successfully${memberCount > 1 ? ' for $memberCount family members' : ''}!'
          )),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error scheduling session: $e');
      
      // If session was consumed but scheduling failed, refund the session
      try {
        final payingClientId = _isBookingForFamily && _family != null 
            ? _family!.organizerId 
            : widget.clientId;
        await _paymentService.refundSession(payingClientId, widget.trainerId);
      } catch (refundError) {
        print('Error refunding session: $refundError');
      }
      
      setState(() {
        _isSubmitting = false;
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling session: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Schedule with ${widget.trainerName}'),
        actions: [],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
      bottomNavigationBar: _selectedTimeSlot != null
        ? _buildBottomBar()
        : const SizedBox.shrink(),
    );
  }
  
  Widget _buildContent() {
    if (_availableTimeSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: AppStyles.slateGray.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No available time slots',
              style: TextStyle(
                fontSize: 18,
                color: AppStyles.darkCharcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later or contact your trainer',
              style: TextStyle(
                fontSize: 16,
                color: AppStyles.slateGray,
              ),
            ),
          ],
        ),
      );
    }
    
    // Sort dates chronologically
    final sortedDates = _timeSlotsByDate.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120), // Account for bottom bar
      itemCount: sortedDates.length + (_family != null ? 2 : 1), // +1 for trainer info card, +1 for family section if in family
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTrainerInfoCard();
        }
        
        if (_family != null && index == 1) {
          return _buildFamilyMemberSelection();
        }
        
        final dateIndex = _family != null ? index - 2 : index - 1;
        final date = sortedDates[dateIndex];
        final slots = _timeSlotsByDate[date]!;
        
        return _buildDateSection(date, slots);
      },
    );
  }

  Widget _buildTrainerInfoCard() {
    if (_trainer == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppStyles.primarySage.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 32,
                color: AppStyles.primarySage,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trainerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loading contact info...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.slateGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppStyles.primarySage.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                child: Text(
                  _trainer!.displayName?.isNotEmpty == true
                      ? _trainer!.displayName![0].toUpperCase()
                      : _trainer!.firstName?.isNotEmpty == true
                          ? _trainer!.firstName![0].toUpperCase()
                          : 'T',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primarySage,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trainer!.displayName ?? 
                      '${_trainer!.firstName ?? ''} ${_trainer!.lastName ?? ''}'.trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your Trainer',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppStyles.slateGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            width: double.infinity,
            color: AppStyles.slateGray.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.email,
                size: 18,
                color: AppStyles.primarySage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _trainer!.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppStyles.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          if (_trainer!.phoneNumber != null && _trainer!.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 18,
                  color: AppStyles.primarySage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _trainer!.phoneNumber!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppStyles.darkCharcoal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFamilyMemberSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppStyles.primarySage.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.family_restroom,
                color: AppStyles.primarySage,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Book for Family',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.darkCharcoal,
                  ),
                ),
              ),
              Switch(
                value: _isBookingForFamily,
                onChanged: (value) {
                  // Additional validation: ensure user is still a family member
                  if (value && _family != null && !_family!.isMember(widget.clientId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You are no longer a member of this family. Please refresh the page.')),
                    );
                    return;
                  }
                  
                  setState(() {
                    _isBookingForFamily = value;
                    if (!value) {
                      _selectedFamilyMembers.clear();
                      _selectedFamilyMembers.add(widget.clientId);
                    }
                  });
                },
                activeColor: AppStyles.primarySage,
              ),
            ],
          ),
          if (_isBookingForFamily) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              width: double.infinity,
              color: AppStyles.slateGray.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Family Members',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppStyles.darkCharcoal,
              ),
            ),
            const SizedBox(height: 12),
            if (_familyMembers.isNotEmpty) ...[
              ..._familyMembers.map((member) {
                final isSelected = _selectedFamilyMembers.contains(member.uid);
                final isCurrentUser = member.uid == widget.clientId;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedFamilyMembers.add(member.uid);
                        } else {
                          _selectedFamilyMembers.remove(member.uid);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        ProfileAvatar(
                          name: member.displayName ?? 'Unknown User',
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            member.displayName ?? 'Unknown User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.darkCharcoal,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    activeColor: AppStyles.primarySage,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
              if (_family?.organizerId != widget.clientId) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Colors.amber.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Family sessions are paid by the family organizer.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDateSection(DateTime date, List<Map<String, dynamic>> slots) {
    final isExpanded = _expandedDates.contains(date);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header (clickable)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(date);
                  if (_animationControllers[date] != null) {
                    _animationControllers[date]!.reverse();
                  }
                } else {
                  _expandedDates.add(date);
                  if (_animationControllers[date] != null) {
                    _animationControllers[date]!.forward();
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppStyles.mutedBlue.withOpacity(isExpanded ? 0.15 : 0.1),
                    AppStyles.mutedBlue.withOpacity(isExpanded ? 0.1 : 0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: isExpanded 
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )
                  : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppStyles.mutedBlue.withOpacity(isExpanded ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: AppStyles.mutedBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppStyles.darkCharcoal,
                          ),
                        ),
                        Text(
                          '${slots.length} time${slots.length == 1 ? '' : 's'} available',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppStyles.slateGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dropdown arrow
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppStyles.mutedBlue,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable time slots section
          if (_slideAnimations[date] != null)
            ClipRect(
              child: AnimatedBuilder(
                animation: _slideAnimations[date]!,
                builder: (context, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, -1.0),
                      end: const Offset(0.0, 0.0),
                    ).animate(_slideAnimations[date]!),
                    child: SizeTransition(
                      sizeFactor: _slideAnimations[date]!,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: AppStyles.slateGray.withOpacity(0.1),
                            ),
                            const SizedBox(height: 20),
                            _buildTimeSlotGrid(slots),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: AppStyles.slateGray.withOpacity(0.1),
                  ),
                  const SizedBox(height: 20),
                  _buildTimeSlotGrid(slots),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotGrid(List<Map<String, dynamic>> slots) {
    // Group slots into rows of 2
    final List<List<Map<String, dynamic>>> rows = [];
    for (int i = 0; i < slots.length; i += 2) {
      final row = slots.skip(i).take(2).toList();
      rows.add(row);
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildTimeSlotCard(row[0]),
              ),
              if (row.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSlotCard(row[1]),
                ),
              ] else ...[
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotCard(Map<String, dynamic> slot) {
    final startTime = slot['start_time'] as DateTime;
    final endTime = slot['end_time'] as DateTime;
    final isSelected = _selectedTimeSlot == slot;
    
    final formattedStartTime = DateFormat('h:mm a').format(startTime);
    final formattedEndTime = DateFormat('h:mm a').format(endTime);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeSlot = slot;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected 
            ? AppStyles.primaryGradient
            : null,
          color: isSelected 
            ? null 
            : AppStyles.lightCharcoal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? AppStyles.mutedBlue
              : AppStyles.slateGray.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: AppStyles.mutedBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isSelected 
                    ? Colors.white.withOpacity(0.9)
                    : AppStyles.mutedBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  formattedStartTime,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSelected 
                      ? Colors.white
                      : AppStyles.darkCharcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 1,
              color: isSelected 
                ? Colors.white.withOpacity(0.5)
                : AppStyles.slateGray.withOpacity(0.4),
            ),
            const SizedBox(height: 4),
            Text(
              formattedEndTime,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: isSelected 
                  ? Colors.white.withOpacity(0.9)
                  : AppStyles.slateGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0), // Added extra bottom padding
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected time info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.mutedBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.mutedBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppStyles.darkCharcoal,
                    ),
                    children: [
                      const TextSpan(text: 'Selected time: '),
                      TextSpan(
                        text: _getFormattedTimeSlot(_selectedTimeSlot!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppStyles.mutedBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Location input
              _buildStyledTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'e.g., Gym, Park, Virtual',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              
              // Notes input
              _buildStyledTextField(
                controller: _notesController,
                label: 'Notes (optional)',
                hint: 'Any special instructions or requests',
                icon: Icons.note_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              
              // Schedule button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppStyles.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppStyles.mutedBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _scheduleSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm Booking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppStyles.slateGray.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 16,
          color: AppStyles.darkCharcoal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: AppStyles.slateGray,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: AppStyles.slateGray.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: AppStyles.mutedBlue,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppStyles.mutedBlue,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat('MMMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
  
  String _getFormattedTimeSlot(Map<String, dynamic> slot) {
    final startTime = slot['start_time'] as DateTime;
    final endTime = slot['end_time'] as DateTime;
    
    final dateFormatter = DateFormat('E, MMM d');
    final timeFormatter = DateFormat('h:mm a');
    
    final date = dateFormatter.format(startTime);
    final start = timeFormatter.format(startTime);
    final end = timeFormatter.format(endTime);
    
    return '$date, $start - $end';
  }
} 