import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';

class NutrientResult {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sodium;
  final double cholesterol;
  final double fiber;
  final double sugar;
  final String? errorMessage; // Added error message field
  
  const NutrientResult({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sodium,
    required this.cholesterol,
    required this.fiber,
    required this.sugar,
    this.errorMessage,
  });
  
  factory NutrientResult.fromJson(Map<String, dynamic> json) {
    return NutrientResult(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
      cholesterol: (json['cholesterol'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  // Create result with error
  factory NutrientResult.withError(String message) {
    return NutrientResult(
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      sodium: 0,
      cholesterol: 0,
      fiber: 0,
      sugar: 0,
      errorMessage: message,
    );
  }
  
  bool get hasError => errorMessage != null;
  
  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sodium': sodium,
      'cholesterol': cholesterol,
      'fiber': fiber,
      'sugar': sugar,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
  
  @override
  String toString() {
    return 'NutrientResult(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, sodium: $sodium, cholesterol: $cholesterol, fiber: $fiber, sugar: $sugar, errorMessage: $errorMessage)';
  }
}

class FoodRecognitionService {
  // Use API key from config file and use gemini-2.0-flash model instead of gemini-1.5-pro for free tier
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: ApiKeys.geminiApiKey,
    generationConfig: GenerationConfig(
      temperature: 0.1, // Low temperature for more predictable outputs
      topK: 16,
      topP: 0.95,
      responseMimeType: 'application/json', // Hint for JSON response
    ),
  );
  
  /// Analyzes a food image and returns nutritional information
  Future<NutrientResult> analyzeFoodImage(String imagePath, {int maxRetries = 2}) async {
    int attempts = 0;
    
    while (attempts <= maxRetries) {
      try {
        attempts++;
        
        // Read image file as bytes
        final File imageFile = File(imagePath);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        
        // Create a prompt that instructs Gemini to analyze the food and return structured data
        final prompt = '''
          Analyze this food image and provide detailed nutritional information.
          Your response must be ONLY a JSON object with these nutritional values:
          {
            "calories": number (kcal),
            "protein": number (g),
            "carbs": number (g),
            "fat": number (g),
            "sodium": number (mg),
            "cholesterol": number (mg),
            "fiber": number (g),
            "sugar": number (g)
          }
          
          Be as accurate as possible based on what you can see in the image.
          Do NOT include any text explanation, markdown formatting, or code blocks.
          Only return the JSON object itself.
        ''';
        
        // Create content with text prompt and image
        final content = Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]);
        
        // Generate content from Gemini
        final response = await _model.generateContent([content]);
        final responseText = response.text;
        
        if (responseText == null || responseText.isEmpty) {
          // If we've used all retries, return error result
          if (attempts > maxRetries) {
            return NutrientResult.withError('Empty response from AI. Please try again with a clearer image.');
          }
          debugPrint('Empty response, retrying (attempt $attempts)...');
          continue; // Retry
        }
        
        debugPrint('Gemini response: $responseText');
        
        // Try to extract JSON from the response using multiple approaches
        try {
          // First, try to parse the entire response directly
          return NutrientResult.fromJson(jsonDecode(responseText));
        } catch (e) {
          debugPrint('Direct JSON parsing failed: $e');
          
          // Second, try to extract JSON using regex for a JSON object
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final match = jsonRegExp.firstMatch(responseText);
          
          if (match != null) {
            final jsonString = match.group(0);
            if (jsonString != null) {
              try {
                return NutrientResult.fromJson(jsonDecode(jsonString));
              } catch (e) {
                debugPrint('Regex JSON parsing failed: $e');
              }
            }
          }
          
          // Third, try to extract from markdown code blocks
          final markdownRegExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
          final markdownMatch = markdownRegExp.firstMatch(responseText);
          
          if (markdownMatch != null && markdownMatch.groupCount >= 1) {
            final jsonString = markdownMatch.group(1);
            if (jsonString != null) {
              try {
                return NutrientResult.fromJson(jsonDecode(jsonString));
              } catch (e) {
                debugPrint('Markdown JSON parsing failed: $e');
              }
            }
          }
          
          // If all parsing fails and we have retries left, try again
          if (attempts <= maxRetries) {
            debugPrint('JSON parsing failed, retrying (attempt $attempts)...');
            continue; // Retry
          }
          
          // If all extraction attempts fail, return error result
          return NutrientResult.withError('Could not extract nutritional data. Please try again with a clearer image.');
        }
      } catch (e) {
        debugPrint('Error analyzing food image (attempt $attempts): $e');
        
        // Return error result on the final attempt
        if (attempts > maxRetries) {
          String errorMessage = 'Error analyzing food image.';
          
          // Provide more specific error messages
          if (e.toString().contains('quota') || e.toString().contains('rate limit')) {
            errorMessage = 'API usage limit reached. Please try again later.';
          } else if (e.toString().contains('network')) {
            errorMessage = 'Network error. Please check your internet connection.';
          } else if (e.toString().contains('Could not extract')) {
            errorMessage = 'Unable to analyze this food. Please try with a clearer image.';
          }
          
          return NutrientResult.withError(errorMessage);
        }
        
        // Wait a short time before retrying (exponential backoff)
        final waitTime = Duration(milliseconds: 200 * attempts);
        await Future.delayed(waitTime);
      }
    }
    
    // This should never be reached due to the return in the final attempt, but just in case
    return NutrientResult.withError('Failed to analyze food image after multiple attempts.');
  }
} 