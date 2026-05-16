import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pfc_score.dart';

class DietTypeService {
  static final DietTypeService instance = DietTypeService._();
  DietTypeService._();

  static const _key = 'diet_type';

  DietType current = DietType.calorie;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    current = DietType.values[index.clamp(0, DietType.values.length - 1)];
  }

  Future<void> save(DietType type) async {
    current = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, type.index);
  }
}
