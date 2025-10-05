import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Play whistle sound at the start of exercise interval
  Future<void> playWhistleSound() async {
    try {
      // Play a whistle-like sound using system notification sound
      // On iOS and Android, this will play a short beep/notification sound
      await SystemSound.play(SystemSoundType.click);
      
      // For a more distinct sound, we can also vibrate
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing whistle sound: $e');
    }
  }
  
  // Play ding ding ding sound at the end of exercise interval
  Future<void> playDingSound() async {
    try {
      // Play three consecutive "dings" using system sounds
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.mediumImpact();
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      print('Error playing ding sound: $e');
    }
  }
  
  // Alternative method using tone generation (if we want to use audioplayers)
  // This would require actual audio files, so we'll stick with system sounds for now
  
  void dispose() {
    _audioPlayer.dispose();
  }
}

