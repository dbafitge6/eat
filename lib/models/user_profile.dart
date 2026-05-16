class UserProfile {
  final double heightCm;
  final double weightKg;
  final int age;
  final int sex; // 0=男 1=女
  final int activityLevel; // 0-4
  final int goal; // 0=減量 1=維持 2=増量
  final int dietIntensity; // 0=プチ 1=スタンダード 2=しっかり 3=本気
  final double targetKcal;
  final double targetWaterMl;

  const UserProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.sex,
    required this.activityLevel,
    required this.goal,
    this.dietIntensity = 1,
    required this.targetKcal,
    required this.targetWaterMl,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  double get bmr {
    if (sex == 0) {
      return 13.397 * weightKg + 4.799 * heightCm - 5.677 * age + 88.362;
    } else {
      return 9.247 * weightKg + 3.098 * heightCm - 4.330 * age + 447.593;
    }
  }

  static const activityLabels = [
    'デスクワーク中心',
    '軽い活動',
    '適度な活動',
    '活発な活動',
    'アスリート・肉体労働',
  ];

  static const activityFactors = [1.2, 1.375, 1.55, 1.725, 1.9];

  // diet intensity: deficit kcal/day
  static const intensityLabels = ['プチダイエット', 'スタンダード', 'しっかり絞る', '本気モード'];
  static const intensityDeficits = [-200, -500, -750, -1000];
  // estimated monthly weight change (kg) based on ~7200 kcal/kg fat
  static const intensityMonthlyKg = [0.2, 0.5, 0.8, 1.0];

  static double calcTargetKcal(double bmr, int activityLevel, int goal, [int dietIntensity = 1]) {
    final tdee = bmr * activityFactors[activityLevel.clamp(0, 4)];
    switch (goal) {
      case 0:
        final deficit = intensityDeficits[dietIntensity.clamp(0, 3)];
        return (tdee + deficit).clamp(bmr * 0.85, tdee); // 下限はBMRの85%
      case 2:
        return tdee + 300;
      default:
        return tdee;
    }
  }

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        heightCm: (m['height_cm'] as num).toDouble(),
        weightKg: (m['weight_kg'] as num).toDouble(),
        age: m['age'] as int,
        sex: m['sex'] as int,
        activityLevel: m['activity_level'] as int,
        goal: m['goal'] as int,
        dietIntensity: (m['diet_intensity'] as int?) ?? 1,
        targetKcal: (m['target_kcal'] as num).toDouble(),
        targetWaterMl: (m['target_water_ml'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'age': age,
        'sex': sex,
        'activity_level': activityLevel,
        'goal': goal,
        'diet_intensity': dietIntensity,
        'target_kcal': targetKcal,
        'target_water_ml': targetWaterMl,
      };
}
