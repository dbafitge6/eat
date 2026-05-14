import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class MealPhotoService {
  static final _picker = ImagePicker();

  static String _key(String date, int mealType) => 'photo_${date}_$mealType';

  static Future<File?> getPhoto(String date, int mealType) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(date, mealType));
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  static Future<File?> pick(
    String date,
    int mealType, {
    required bool fromCamera,
  }) async {
    final xfile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (xfile == null) return null;

    // 旧ファイルを削除してからアプリ内にコピー
    await _deleteFile(date, mealType);
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(
      dir.path,
      'meal_${date}_${mealType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));
    await File(xfile.path).copy(dest.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(date, mealType), dest.path);
    return dest;
  }

  static Future<void> delete(String date, int mealType) async {
    await _deleteFile(date, mealType);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(date, mealType));
  }

  static Future<void> _deleteFile(String date, int mealType) async {
    final old = await getPhoto(date, mealType);
    if (old != null) await old.delete().catchError((e) => old);
  }
}
