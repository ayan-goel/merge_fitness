# Food Recognition Feature

The Merge Fitness app now has an AI-powered food recognition feature that allows users to take a photo of their food to automatically analyze and populate nutritional information. This document provides instructions for setting up and using this feature.

## Setup Instructions

To use the AI food recognition feature, you need to obtain a Gemini API key from Google AI Studio.

### Step 1: Get a Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new API key
4. Copy the API key

### Step 2: Configure the App

1. Open the file `lib/config/api_keys.dart`
2. Replace `YOUR_GEMINI_API_KEY` with your actual API key:

```dart
static const String geminiApiKey = 'your-actual-api-key-here';
```

### Step 3: Install Dependencies

Make sure all required dependencies are installed by running:

```bash
flutter pub get
```

## Using the Food Recognition Feature

1. When adding or editing a meal, you'll see a new "AI Food Analysis" card at the top of the screen
2. Choose one of two options:
   - **Take Photo**: Opens the camera to take a picture of your food
   - **Upload Image**: Opens the gallery to select an existing food image

3. Wait for the analysis to complete (it may take a few seconds)
4. The app will automatically populate:
   - Calories
   - Macronutrients (protein, carbs, fat)
   - Micronutrients (sodium, cholesterol, fiber, sugar)

5. You can adjust any values manually if needed before saving the meal

## Technical Implementation

The feature uses:
- Google's Gemini Pro 1.5 model for image analysis
- Flutter's `image_picker` for capturing images
- A custom prompt that instructs the AI to return structured nutritional data

## Troubleshooting

If you experience issues:

1. **No values returned**: Ensure the image clearly shows the food and try again
2. **Inaccurate values**: The AI makes its best estimate; adjust values manually as needed
3. **API errors**: Verify your API key is correct and that you haven't exceeded rate limits
4. **Camera permission issues**: Make sure to grant camera permissions to the app

## Privacy Note

Food images are only sent to Google's Gemini API for analysis and are not stored permanently. The app respects user privacy and follows Google's API usage guidelines. 