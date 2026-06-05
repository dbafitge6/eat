#!/usr/bin/env python3
"""
文科省「日本食品標準成分表（八訂）増補2023年」Excel → foods_mext.json 変換スクリプト
使い方: python convert_mext.py <Excelファイルパス>
"""
import sys, json, re, pandas as pd
from pathlib import Path

def to_float(val):
    if pd.isna(val): return 0.0
    s = str(val).strip().replace('−', '0').replace('Tr', '0.1').replace('(', '').replace(')', '')
    try: return float(s)
    except: return 0.0

def make_id(name):
    import unicodedata, re
    s = unicodedata.normalize('NFKC', name)
    s = re.sub(r'[^\w]', '_', s)
    return s.strip('_')[:40].lower()

EXCLUDE_CATEGORIES = ['調理加工食品類']
KEEP_CATEGORIES = ['穀類','いも及びでん粉類','砂糖及び甘味類','豆類','種実類','野菜類',
                   '果実類','きのこ類','藻類','魚介類','肉類','卵類','乳類','油脂類',
                   '調味料及び香辛料類','し好飲料類','その他']

def convert(excel_path):
    print(f"読み込み中: {excel_path}")
    # 文科省Excelは複数シートあり、最初の食品データシートを使用
    xl = pd.ExcelFile(excel_path)
    print(f"シート: {xl.sheet_names}")
    df = pd.read_excel(excel_path, sheet_name=xl.sheet_names[0], header=None)
    # ヘッダー行を探す（食品番号が含まれる行）
    header_row = None
    for i, row in df.iterrows():
        if '食品番号' in str(row.values) or '食品名' in str(row.values):
            header_row = i
            break
    if header_row is None:
        header_row = 4
    df = pd.read_excel(excel_path, sheet_name=xl.sheet_names[0], header=header_row)
    print(f"カラム: {list(df.columns[:10])}")
    print(f"行数: {len(df)}")

    foods = []
    for _, row in df.iterrows():
        try:
            name = str(row.get('食品名', row.iloc[2] if len(row) > 2 else '')).strip()
            if not name or name == 'nan' or len(name) < 1: continue
            category = str(row.get('食品群', '')).strip()
            if any(ex in category for ex in EXCLUDE_CATEGORIES): continue

            food = {
                "id": make_id(name),
                "name": name,
                "name_reading": "",
                "name_en": "",
                "category": category,
                "data_source": "mext_2023",
                "is_reference_value": False,
                "per_100g": {
                    "calories": to_float(row.get('エネルギー', 0)),
                    "protein_g": to_float(row.get('たんぱく質', 0)),
                    "fat_g": to_float(row.get('脂質', 0)),
                    "carbs_g": to_float(row.get('炭水化物', 0)),
                    "fiber_g": to_float(row.get('食物繊維総量', 0)),
                    "vitamins": {
                        "vitamin_a_ug": to_float(row.get('ビタミンA', 0)),
                        "vitamin_d_ug": to_float(row.get('ビタミンD', 0)),
                        "vitamin_e_mg": to_float(row.get('ビタミンE', 0)),
                        "vitamin_k_ug": to_float(row.get('ビタミンK', 0)),
                        "vitamin_b1_mg": to_float(row.get('ビタミンB1', 0)),
                        "vitamin_b2_mg": to_float(row.get('ビタミンB2', 0)),
                        "vitamin_b6_mg": to_float(row.get('ビタミンB6', 0)),
                        "vitamin_b12_ug": to_float(row.get('ビタミンB12', 0)),
                        "vitamin_c_mg": to_float(row.get('ビタミンC', 0)),
                        "niacin_mg": to_float(row.get('ナイアシン', 0)),
                        "folate_ug": to_float(row.get('葉酸', 0)),
                        "pantothenic_acid_mg": to_float(row.get('パントテン酸', 0)),
                        "biotin_ug": to_float(row.get('ビオチン', 0))
                    },
                    "minerals": {
                        "calcium_mg": to_float(row.get('カルシウム', 0)),
                        "magnesium_mg": to_float(row.get('マグネシウム', 0)),
                        "potassium_mg": to_float(row.get('カリウム', 0)),
                        "sodium_mg": to_float(row.get('ナトリウム', 0)),
                        "phosphorus_mg": to_float(row.get('リン', 0)),
                        "iron_mg": to_float(row.get('鉄', 0)),
                        "zinc_mg": to_float(row.get('亜鉛', 0)),
                        "copper_mg": to_float(row.get('銅', 0)),
                        "manganese_mg": to_float(row.get('マンガン', 0)),
                        "iodine_ug": to_float(row.get('ヨウ素', 0)),
                        "selenium_ug": to_float(row.get('セレン', 0)),
                        "chromium_ug": to_float(row.get('クロム', 0)),
                        "molybdenum_ug": to_float(row.get('モリブデン', 0))
                    }
                },
                "functional_ingredients": [],
                "body_parts_effects": {},
                "combination_tips": [],
                "craving_signal": {"has_signal": False, "message": None},
                "cooking_tips": [],
                "tags": []
            }
            foods.append(food)
        except Exception as e:
            continue

    out = {"foods": foods, "total": len(foods), "source": "mext_2023"}
    out_path = Path(__file__).parent.parent / 'assets' / 'databases' / 'foods_mext.json'
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"✅ 完了: {len(foods)}食材 → {out_path}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("使い方: python convert_mext.py <Excelファイルパス>")
        sys.exit(1)
    convert(sys.argv[1])
