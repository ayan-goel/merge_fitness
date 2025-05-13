import 'package:flutter/material.dart';

class ProfileImageService {
  // Generate a color from a string (user's name) for consistent avatar colors
  Color getColorFromName(String name) {
    final List<Color> colors = [
      Colors.red.shade300,
      Colors.pink.shade300,
      Colors.purple.shade300,
      Colors.deepPurple.shade300,
      Colors.indigo.shade300,
      Colors.blue.shade300,
      Colors.lightBlue.shade300,
      Colors.cyan.shade300,
      Colors.teal.shade300,
      Colors.green.shade300,
      Colors.lightGreen.shade300,
      Colors.lime.shade300,
      Colors.amber.shade300,
      Colors.orange.shade300,
      Colors.deepOrange.shade300,
    ];
    
    // Generate a deterministic index based on the name
    int hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    // Use abs to ensure positive and modulo for the range
    return colors[hash.abs() % colors.length];
  }
  
  // Get initials from a name
  String getInitials(String name) {
    if (name.isEmpty) return '';
    
    List<String> nameSplit = name.split(" ");
    String initials = "";
    
    if (nameSplit.length > 1) {
      // Get first and last name initials
      initials = nameSplit[0][0] + nameSplit[nameSplit.length - 1][0];
    } else {
      // If only one name, use the first two letters or just first if too short
      initials = name.length > 1 ? name.substring(0, 2) : name[0];
    }
    
    return initials.toUpperCase();
  }
  
  // Widget to display initials avatar
  Widget getProfileImage({
    required String name,
    double radius = 40,
    double fontSize = 20,
  }) {
    return getInitialsAvatar(name, radius: radius, fontSize: fontSize);
  }
  
  // Generate an initials avatar as a Widget
  Widget getInitialsAvatar(String name, {double radius = 40, double fontSize = 20}) {
    final initials = getInitials(name);
    final bgColor = getColorFromName(name);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
} 