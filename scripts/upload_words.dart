import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:english_learning_app/firebase_options.dart';
import 'package:english_learning_app/app_config.dart';

// --- רשימת המילים שברצונך להוסיף ---
const List<String> wordsToUpload = [
  'Apple',
  'Banana',
  'Car',
  'Dog',
  'Cat',
  'House',
  'Tree',
  'Sun',
  'Moon',
  'Star',
];

// ---- הפונקציה הראשית ----
void main() async {
  // אתחול שירותי Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  final batch = firestore.batch();

  if (!AppConfig.hasFirebaseUserId) {
    print(
      '❌ Missing FIREBASE_USER_ID_FOR_UPLOAD. Provide it via --dart-define.',
    );
    return;
  }
  if (!AppConfig.hasPixabay) {
    print('❌ Missing PIXABAY_API_KEY. Provide it via --dart-define.');
    return;
  }

  final wordsCollection = firestore
      .collection('users')
      .doc(AppConfig.firebaseUserIdForUpload)
      .collection('words');

  print("Starting to process ${wordsToUpload.length} words...");

  for (String word in wordsToUpload) {
    try {
      print("\nProcessing word: '$word'");

      // 1. חפש תמונה ב-Pixabay
      final imageUrl = await searchImageOnPixabay(
        word,
        AppConfig.pixabayApiKey,
      );
      if (imageUrl == null) {
        print("  - Could not find image for '$word'. Skipping.");
        continue;
      }
      print("  - Found image URL: $imageUrl");

      // 2. הורד את התמונה מהאינטרנט
      final imageBytes = await downloadImage(imageUrl);
      print("  - Downloaded image successfully.");

      // 3. העלה את התמונה ל-Firebase Storage
      final storagePath = 'word_images/${word.toLowerCase()}.jpg';
      final finalImageUrl = await uploadImageToStorage(
        storage,
        imageBytes,
        storagePath,
      );
      print("  - Uploaded to Firebase Storage at: $finalImageUrl");

      // 4. הוסף את המידע ל-Firestore Batch
      final docRef = wordsCollection.doc();
      batch.set(docRef, {
        'word': word,
        'imageUrl': finalImageUrl,
        'isCompleted': false,
      });
      print("  - Added '$word' to the batch for Firestore.");
    } catch (e) {
      print("  - An error occurred while processing '$word': $e");
    }
  }

  // 5. בצע את כל הכתיבות ל-Firestore
  print("\nCommitting all words to Firestore...");
  await batch.commit();
  print("✅ Done! All words have been uploaded successfully.");
}

// ---- פונקציות עזר ----

// פונקציה לחיפוש תמונה ב-Pixabay
Future<String?> searchImageOnPixabay(String query, String apiKey) async {
  final url = Uri.parse(
    'https://pixabay.com/api/?key=$apiKey&q=${Uri.encodeComponent(query)}&image_type=illustration&orientation=horizontal&per_page=3',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // --- נוסיף הדפסה של התשובה המלאה שקיבלנו ---
    print("  - Received a 200 OK response from Pixabay.");
    print("  - Response body: ${response.body}");

    final data = jsonDecode(response.body);
    if (data['hits'] != null && (data['hits'] as List).isNotEmpty) {
      // אם יש תוצאות, ניקח את כתובת התמונה הראשונה
      final imageUrl = data['hits'][0]['webformatURL'];
      return imageUrl;
    } else {
      // --- נוסיף הדפסה למקרה שאין תוצאות ---
      print("  - Pixabay found 0 images for '$query'.");
      return null;
    }
  } else {
    // --- נוסיף הדפסה למקרה של שגיאה ---
    print(
      "  - Pixabay request failed with status code: ${response.statusCode}",
    );
    print("  - Response body: ${response.body}");
    return null;
  }
}

// פונקציה להורדת התמונה מהכתובת שנמצאה
Future<List<int>> downloadImage(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  throw Exception('Failed to download image');
}

// פונקציה להעלאת התמונה ל-Firebase Storage וקבלת הקישור הסופי
Future<String> uploadImageToStorage(
  FirebaseStorage storage,
  List<int> imageBytes,
  String path,
) async {
  final ref = storage.ref().child(path);
  final uploadTask = ref.putData(Uint8List.fromList(imageBytes));
  final snapshot = await uploadTask.whenComplete(() => {});
  return await snapshot.ref.getDownloadURL();
}
