import 'package:image_picker/image_picker.dart';
import 'gemini_service.dart';

class NutritionScanService {
  static final NutritionScanService instance = NutritionScanService._();
  NutritionScanService._();

  Future<Map<String, double>?> scanFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1280,
    );
    if (photo == null) return null;
    return GeminiService.instance.extractNutritionFromImage(photo.path);
  }

  Future<Map<String, double>?> scanFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return GeminiService.instance.extractNutritionFromImage(photo.path);
  }
}
