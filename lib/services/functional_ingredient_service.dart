class FunctionalIngredient {
  final String name;
  final String effect;
  final List<String> synergyFoods;
  final String emoji;

  const FunctionalIngredient({
    required this.name,
    required this.effect,
    required this.synergyFoods,
    required this.emoji,
  });
}

class FunctionalIngredientService {
  static const _db = <String, FunctionalIngredient>{
    'イミダペプチド': FunctionalIngredient(
      name: 'イミダペプチド',
      emoji: '⚡',
      effect: '疲労回復・抗酸化作用。鶏むね肉に豊富に含まれ、持続的な疲労感を軽減します。',
      synergyFoods: ['トマト', 'ブロッコリー', 'レモン（ビタミンC）'],
    ),
    'DHA': FunctionalIngredient(
      name: 'DHA',
      emoji: '🧠',
      effect: '脳・神経機能の維持、記憶力向上、中性脂肪の低下に役立ちます。',
      synergyFoods: ['緑黄色野菜', 'ビタミンE食品', 'レモン'],
    ),
    'EPA': FunctionalIngredient(
      name: 'EPA',
      emoji: '❤️',
      effect: '血液をサラサラにし、心疾患リスクを低下。抗炎症作用もあります。',
      synergyFoods: ['玉ねぎ', 'にんにく', 'ショウガ'],
    ),
    'GABA': FunctionalIngredient(
      name: 'GABA',
      emoji: '😌',
      effect: 'リラックス・睡眠の質向上・血圧低下。ストレス軽減に効果的です。',
      synergyFoods: ['牛乳', 'バナナ', 'チーズ（トリプトファン）'],
    ),
    '乳酸菌': FunctionalIngredient(
      name: '乳酸菌',
      emoji: '🦠',
      effect: '腸内環境改善・免疫力向上。善玉菌を増やし腸の働きを整えます。',
      synergyFoods: ['食物繊維（野菜・きのこ）', 'オリゴ糖（玉ねぎ・バナナ）'],
    ),
    'ビフィズス菌': FunctionalIngredient(
      name: 'ビフィズス菌',
      emoji: '🌱',
      effect: '腸内環境改善・便秘解消・免疫機能のサポート。',
      synergyFoods: ['食物繊維', 'オリゴ糖', 'ヨーグルト'],
    ),
    'カテキン': FunctionalIngredient(
      name: 'カテキン',
      emoji: '🍵',
      effect: '抗酸化・抗菌・脂肪燃焼促進。体脂肪の低下に役立ちます。',
      synergyFoods: ['ビタミンC食品', 'レモン（吸収促進）'],
    ),
    'リコピン': FunctionalIngredient(
      name: 'リコピン',
      emoji: '🍅',
      effect: '強力な抗酸化作用。生活習慣病予防・紫外線ダメージ軽減に効果的。',
      synergyFoods: ['オリーブオイル（吸収促進）', 'アボカド', 'チーズ'],
    ),
    'β-グルカン': FunctionalIngredient(
      name: 'β-グルカン',
      emoji: '🍄',
      effect: '免疫力向上・血糖値スパイク抑制・コレステロール低下。',
      synergyFoods: ['ビタミンD食品', '野菜', '発酵食品'],
    ),
    'ルテイン': FunctionalIngredient(
      name: 'ルテイン',
      emoji: '👁️',
      effect: '目の疲れ軽減・ブルーライト対策・加齢黄斑変性の予防。',
      synergyFoods: ['オリーブオイル（吸収促進）', 'ほうれん草', 'アボカド'],
    ),
    'コラーゲン': FunctionalIngredient(
      name: 'コラーゲン',
      emoji: '✨',
      effect: '肌の弾力維持・関節軟骨の保護・骨の健康維持。',
      synergyFoods: ['ビタミンC食品（合成促進）', 'レモン', 'キウイ'],
    ),
    'ポリフェノール': FunctionalIngredient(
      name: 'ポリフェノール',
      emoji: '🍇',
      effect: '強い抗酸化作用で老化・動脈硬化・がんのリスクを低下させます。',
      synergyFoods: ['ビタミンC', 'ビタミンE', '緑黄色野菜'],
    ),
  };

  // food name → functional ingredients mapping
  static const _foodToIngredients = <String, List<String>>{
    '鶏むね': ['イミダペプチド'],
    '鶏胸': ['イミダペプチド'],
    'チキン': ['イミダペプチド'],
    'サーモン': ['DHA', 'EPA'],
    '鮭': ['DHA', 'EPA'],
    'マグロ': ['DHA', 'EPA'],
    'いわし': ['DHA', 'EPA'],
    'さば': ['DHA', 'EPA'],
    'サバ': ['DHA', 'EPA'],
    'まぐろ': ['DHA', 'EPA'],
    '青魚': ['DHA', 'EPA'],
    'ヨーグルト': ['乳酸菌', 'ビフィズス菌'],
    'チーズ': ['乳酸菌'],
    '納豆': ['GABA', 'ポリフェノール'],
    '緑茶': ['カテキン', 'GABA'],
    'お茶': ['カテキン'],
    'トマト': ['リコピン', 'ポリフェノール'],
    'きのこ': ['β-グルカン'],
    'しいたけ': ['β-グルカン'],
    'マッシュルーム': ['β-グルカン'],
    '卵': ['ルテイン', 'コラーゲン'],
    'エッグ': ['ルテイン'],
    '手羽': ['コラーゲン', 'イミダペプチド'],
    'ぶた': ['コラーゲン'],
    '豚足': ['コラーゲン'],
    'ブルーベリー': ['ルテイン', 'ポリフェノール'],
    'ぶどう': ['ポリフェノール'],
    'ワイン': ['ポリフェノール'],
    'チョコ': ['ポリフェノール'],
    'カカオ': ['ポリフェノール'],
  };

  static List<FunctionalIngredient> detectFromFoodName(String foodName) {
    final lower = foodName.toLowerCase();
    final ingredientNames = <String>{};

    for (final entry in _foodToIngredients.entries) {
      if (lower.contains(entry.key) || foodName.contains(entry.key)) {
        ingredientNames.addAll(entry.value);
      }
    }

    return ingredientNames
        .map((name) => _db[name])
        .whereType<FunctionalIngredient>()
        .toList();
  }

  static FunctionalIngredient? get(String name) => _db[name];
}
