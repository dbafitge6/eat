import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'gemini_service.dart';

class NutritionScanService {
  static final NutritionScanService instance = NutritionScanService._();
  NutritionScanService._();

  Future<Map<String, double>?> scanFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return _extractNutrition(photo.path);
  }

  Future<Map<String, double>?> scanFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return _extractNutrition(photo.path);
  }

  Future<Map<String, double>?> _extractNutrition(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      final text = recognized.text;
      if (text.trim().isEmpty) return null;
      return GeminiService.instance.extractNutritionFromText(text);
    } finally {
      recognizer.close();
    }
  }
}
