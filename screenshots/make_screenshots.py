#!/usr/bin/env python3
"""
App Store screenshot generator for eat.
Canvas: 1242x2688 (iPhone 11 Pro Max 6.5")
Header: 740px dark purple + app UI below
"""
from PIL import Image, ImageDraw, ImageFont
import os

CANVAS_W, CANVAS_H = 1242, 2688
HEADER_H = 740
APP_H = CANVAS_H - HEADER_H  # 1948

HEADER_BG = (26, 5, 48)
APP_BG = (26, 21, 32)
CARD_BG = (35, 29, 48)
PRIMARY = (139, 92, 246)      # purple
PRIMARY_DIM = (100, 60, 200)
WHITE = (255, 255, 255)
GRAY = (156, 163, 175)
LIGHT_GRAY = (107, 114, 128)
ACCENT = (124, 58, 237)

FONT_BOLD_W6 = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_REG_W3 = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

def font(path, size):
    return ImageFont.truetype(path, size)

def make_canvas():
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), HEADER_BG)
    return img, ImageDraw.Draw(img)

def draw_header(draw, title_lines, subtitle):
    """Draw dark header with bold title and subtitle."""
    fnt_title = font(FONT_BOLD_W6, 88)
    fnt_sub = font(FONT_REG_W3, 42)

    # Draw title lines (bold white)
    y = 80
    for line in title_lines:
        draw.text((70, y), line, font=fnt_title, fill=WHITE)
        bbox = draw.textbbox((0, 0), line, font=fnt_title)
        y += bbox[3] - bbox[1] + 18

    # Draw subtitle
    y += 10
    draw.text((70, y), subtitle, font=fnt_sub, fill=(180, 160, 210))

def paste_raw(img, raw_path):
    """Scale raw screenshot to canvas width and paste starting at HEADER_H."""
    raw = Image.open(raw_path).convert("RGB")
    scale = CANVAS_W / raw.width
    new_h = int(raw.height * scale)
    raw = raw.resize((CANVAS_W, new_h), Image.LANCZOS)
    img.paste(raw.crop((0, 0, CANVAS_W, APP_H)), (0, HEADER_H))

def draw_status_bar(draw, time_str="21:01"):
    """Draw a minimal dark status bar."""
    fnt = font(FONT_REG_W3, 36)
    y = HEADER_H + 28
    draw.text((60, y), time_str, font=fnt, fill=WHITE)
    # battery/wifi indicators on right
    draw.rectangle([1140, y+4, 1190, y+28], outline=WHITE, width=2)
    draw.rectangle([1143, y+8, 1183, y+24], fill=WHITE)
    draw.rectangle([1190, y+12, 1196, y+20], fill=WHITE)
    draw.ellipse([1100, y+8, 1120, y+28], outline=GRAY, width=2)
    draw.ellipse([1105, y+13, 1115, y+23], fill=GRAY)

def rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)

# ─── Screen 5: Food Search ────────────────────────────────────────────────────
def make_food_search():
    img, draw = make_canvas()
    draw_header(draw,
                ["かんたん食品検索"],
                "豊富なデータベースから瞬時に登録")

    draw.rectangle([0, HEADER_H, CANVAS_W, CANVAS_H], fill=APP_BG)
    draw_status_bar(draw)

    fnt_med   = font(FONT_REG_W3, 38)
    fnt_small = font(FONT_REG_W3, 30)
    fnt_kcal  = font(FONT_BOLD_W6, 42)
    fnt_unit  = font(FONT_REG_W3, 28)
    fnt_pfc   = font(FONT_REG_W3, 27)
    fnt_title_bar = font(FONT_BOLD_W6, 46)

    # Title bar
    title_y = HEADER_H + 88
    draw.text((CANVAS_W//2, title_y), "食品を追加", font=fnt_title_bar, fill=WHITE, anchor="mm")

    # Search box
    sx0, sy0, sx1, sy1 = 40, HEADER_H + 152, CANVAS_W - 40, HEADER_H + 220
    rounded_rect(draw, [sx0, sy0, sx1, sy1], 20, fill=CARD_BG)
    draw.text((sx0 + 58, (sy0+sy1)//2), "食品名を検索...", font=fnt_med, fill=LIGHT_GRAY, anchor="lm")
    cx, cy, r = sx0 + 32, (sy0+sy1)//2, 15
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=LIGHT_GRAY, width=3)
    draw.line([cx+11, cy+11, cx+22, cy+22], fill=LIGHT_GRAY, width=3)

    # Section label
    draw.text((56, HEADER_H + 244), "よく使う食品", font=fnt_unit, fill=GRAY)

    # Food list items
    foods = [
        ("鶏むね肉（皮なし）", "100g", 108, 22.3, 1.5, 0.0),
        ("白米（炊き）",       "150g", 252,  3.8, 0.5, 55.7),
        ("絹ごし豆腐",         "100g",  56,  4.9, 3.0,  2.0),
        ("ブロッコリー",       "100g",  33,  4.3, 0.5,  5.2),
        ("サーモン（刺身）",    "80g", 168, 18.4,10.2,  0.1),
        ("ゆで卵",              "1個",  78,  6.5, 5.2,  0.4),
        ("バナナ",              "1本", 86,   1.1, 0.2, 22.5),
        ("納豆",               "1パック",100, 8.3, 5.4,  6.1),
    ]

    item_h = 158
    start_y = HEADER_H + 278
    for i, (name, amount, kcal, p, f, c) in enumerate(foods):
        iy0 = start_y + i * item_h
        iy1 = iy0 + item_h - 8
        if iy1 > CANVAS_H - 20:
            break

        rounded_rect(draw, [40, iy0, CANVAS_W - 40, iy1], 18, fill=CARD_BG)

        # Name
        draw.text((76, iy0 + 22), name, font=fnt_med, fill=WHITE)
        # Amount
        draw.text((76, iy0 + 70), amount, font=fnt_small, fill=GRAY)

        # Calorie (right side)
        draw.text((CANVAS_W - 64, iy0 + 30), f"{kcal}", font=fnt_kcal, fill=PRIMARY, anchor="rm")
        draw.text((CANVAS_W - 64, iy0 + 76), "kcal", font=fnt_unit, fill=GRAY, anchor="rm")

        # PFC horizontal (bottom of card)
        pfc_x = 76
        pfc_row_y = iy0 + 110
        for label, val, col in [("P", p, (96,165,250)), ("F", f, (251,146,60)), ("C", c, (167,139,250))]:
            dot_cx = pfc_x + 5
            draw.ellipse([dot_cx-5, pfc_row_y+3, dot_cx+5, pfc_row_y+13], fill=col)
            pfc_text = f"{label} {val:.1f}g"
            draw.text((pfc_x + 16, pfc_row_y), pfc_text, font=fnt_pfc, fill=GRAY)
            bbox = draw.textbbox((0, 0), pfc_text, font=fnt_pfc)
            pfc_x += (bbox[2] - bbox[0]) + 36

    return img

# ─── Screen 6: AI Meal Plan (Premium) ─────────────────────────────────────────
def make_meal_plan():
    img, draw = make_canvas()
    draw_header(draw,
                ["AIが献立を", "自動で提案"],
                "あなたのダイエットに最適な毎日の献立")

    draw.rectangle([0, HEADER_H, CANVAS_W, CANVAS_H], fill=APP_BG)
    draw_status_bar(draw)

    fnt_large = font(FONT_BOLD_W6, 44)
    fnt_med   = font(FONT_REG_W3, 36)
    fnt_small = font(FONT_REG_W3, 28)
    fnt_title_bar = font(FONT_BOLD_W6, 46)
    fnt_kcal  = font(FONT_BOLD_W6, 36)
    fnt_tiny  = font(FONT_REG_W3, 26)

    # Title bar
    title_y = HEADER_H + 88
    draw.text((CANVAS_W//2, title_y), "今日の献立", font=fnt_title_bar, fill=WHITE, anchor="mm")

    # Premium badge
    badge_w, badge_h = 200, 44
    bx = CANVAS_W // 2 + 160
    by = title_y - 22
    rounded_rect(draw, [bx, by, bx + badge_w, by + badge_h], 22,
                 fill=(109, 40, 217))
    draw.text((bx + badge_w // 2, by + badge_h // 2), "✦ PREMIUM", font=fnt_tiny, fill=WHITE, anchor="mm")

    # Subtitle
    draw.text((CANVAS_W//2, HEADER_H + 140), "カロリー制限プラン　目標: 990 kcal/日",
              font=fnt_small, fill=GRAY, anchor="mm")

    # Meal cards
    meals = [
        ("朝食", "🌅", 320, [
            ("オートミール（40g）", "148 kcal"),
            ("ゆで卵 × 2",          "156 kcal"),
            ("グリーンサラダ",       " 16 kcal"),
        ]),
        ("昼食", "☀️", 340, [
            ("鶏むね肉のグリル（120g）", "130 kcal"),
            ("玄米（150g）",             "248 kcal", ),
            ("蒸し野菜ミックス",          " 38 kcal"),
        ]),
        ("夕食", "🌙", 330, [
            ("鮭の塩焼き（100g）",    "133 kcal"),
            ("豆腐の味噌汁",           " 72 kcal"),
            ("ほうれん草おひたし",     " 18 kcal"),
            ("玄米（100g）",           "165 kcal"),
        ]),
    ]

    card_start_y = HEADER_H + 178
    card_gap = 16

    for meal_name, emoji, total_kcal, items in meals:
        # Calculate card height
        card_h = 80 + len(items) * 52 + 30
        cx0, cx1 = 32, CANVAS_W - 32
        cy0 = card_start_y
        cy1 = cy0 + card_h

        if cy1 > CANVAS_H - 30:
            break

        rounded_rect(draw, [cx0, cy0, cx1, cy1], 20, fill=CARD_BG)

        # Meal title row
        draw.text((cx0 + 28, cy0 + 24), f"{meal_name}", font=fnt_large, fill=WHITE)
        # Total kcal on right
        draw.text((cx1 - 24, cy0 + 24), f"{total_kcal} kcal", font=fnt_kcal, fill=PRIMARY, anchor="ra")

        # Divider
        draw.line([cx0 + 20, cy0 + 76, cx1 - 20, cy0 + 76], fill=(50, 42, 64), width=1)

        # Items
        iy = cy0 + 90
        for item_name, item_kcal in items:
            draw.text((cx0 + 28, iy), "・" + item_name, font=fnt_small, fill=(200, 190, 220))
            draw.text((cx1 - 24, iy), item_kcal, font=fnt_small, fill=GRAY, anchor="ra")
            iy += 52

        card_start_y = cy1 + card_gap

    # Bottom regenerate button
    btn_y = max(card_start_y + 10, CANVAS_H - 140)
    if btn_y < CANVAS_H - 80:
        rounded_rect(draw, [60, btn_y, CANVAS_W - 60, btn_y + 80], 40, fill=ACCENT)
        fnt_btn = font(FONT_BOLD_W6, 40)
        draw.text((CANVAS_W // 2, btn_y + 40), "✦  献立を再生成", font=fnt_btn, fill=WHITE, anchor="mm")

    return img


# ─── Build all 6 screenshots ──────────────────────────────────────────────────
RAW = "/Users/kobayashikazuya/eat/screenshots/raw"
OUT = "/Users/kobayashikazuya/eat/screenshots/final"
os.makedirs(OUT, exist_ok=True)

screens = [
    ("store_01_today.png",    ["今日の食事を", "かんたん記録"],  "カロリー・PFCを自動で計算",      f"{RAW}/clean_tab0_today.png"),
    ("store_02_week.png",     ["週間グラフで", "進捗を確認"],   "目標達成率をひと目で把握",         f"{RAW}/clean_tab1_week.png"),
    ("store_03_calendar.png", ["カレンダーで", "食事を振り返る"],"毎日の記録を一覧管理",            f"{RAW}/clean_tab2_calendar.png"),
    ("store_04_weight.png",   ["体重推移を", "グラフで管理"],    "BMI・基礎代謝も自動計算",          f"{RAW}/clean_tab3_weight.png"),
]

for filename, title_lines, subtitle, raw_path in screens:
    print(f"Building {filename}...")
    img, draw = make_canvas()
    draw_header(draw, title_lines, subtitle)
    paste_raw(img, raw_path)
    img.save(f"{OUT}/{filename}")
    print(f"  Saved {filename}")

print("Building store_05_search.png...")
make_food_search().save(f"{OUT}/store_05_search.png")
print("  Saved store_05_search.png")

print("Building store_06_meal_plan.png...")
make_meal_plan().save(f"{OUT}/store_06_meal_plan.png")
print("  Saved store_06_meal_plan.png")

print("\nDone! All 6 iPhone screenshots generated.")

# ═══════════════════════════════════════════════════════════════════════════════
# iPad Pro 13" screenshots  (2064 × 2752)
# Layout: header (top 920px) + app UI scaled to full width + cropped to height
# ═══════════════════════════════════════════════════════════════════════════════
IPAD_W, IPAD_H = 2064, 2752
IPAD_HEADER_H = 920
IPAD_APP_H = IPAD_H - IPAD_HEADER_H   # 1832

def ipad_canvas():
    img = Image.new("RGB", (IPAD_W, IPAD_H), HEADER_BG)
    return img, ImageDraw.Draw(img)

def ipad_header(draw, title_lines, subtitle):
    fnt_title = font(FONT_BOLD_W6, 128)
    fnt_sub   = font(FONT_REG_W3,   58)
    y = 100
    for line in title_lines:
        draw.text((96, y), line, font=fnt_title, fill=WHITE)
        bbox = draw.textbbox((0, 0), line, font=fnt_title)
        y += bbox[3] - bbox[1] + 24
    y += 14
    draw.text((96, y), subtitle, font=fnt_sub, fill=(180, 160, 210))

def ipad_paste_raw(img, raw_path):
    """Scale raw screenshot to iPad width, paste and crop to available height."""
    raw = Image.open(raw_path).convert("RGB")
    scale = IPAD_W / raw.width
    new_h = int(raw.height * scale)
    raw = raw.resize((IPAD_W, new_h), Image.LANCZOS)
    crop = raw.crop((0, 0, IPAD_W, IPAD_APP_H))
    img.paste(crop, (0, IPAD_HEADER_H))

def ipad_status_bar(draw, time_str="21:01"):
    fnt = font(FONT_REG_W3, 50)
    y = IPAD_HEADER_H + 38
    draw.text((80, y), time_str, font=fnt, fill=WHITE)
    # battery
    draw.rectangle([1940, y+6, 2000, y+38], outline=WHITE, width=3)
    draw.rectangle([1944, y+10, 1993, y+34], fill=WHITE)
    draw.rectangle([2000, y+16, 2010, y+28], fill=WHITE)

def make_ipad_food_search():
    img, draw = ipad_canvas()
    ipad_header(draw, ["かんたん食品検索"], "豊富なデータベースから瞬時に登録")
    draw.rectangle([0, IPAD_HEADER_H, IPAD_W, IPAD_H], fill=APP_BG)
    ipad_status_bar(draw)

    fnt_med   = font(FONT_REG_W3, 54)
    fnt_small = font(FONT_REG_W3, 42)
    fnt_kcal  = font(FONT_BOLD_W6, 58)
    fnt_unit  = font(FONT_REG_W3, 38)
    fnt_pfc   = font(FONT_REG_W3, 36)
    fnt_title_bar = font(FONT_BOLD_W6, 64)
    fnt_sect  = font(FONT_REG_W3, 38)

    draw.text((IPAD_W//2, IPAD_HEADER_H + 120), "食品を追加",
              font=fnt_title_bar, fill=WHITE, anchor="mm")

    # Search box
    sx0, sy0 = 56, IPAD_HEADER_H + 210
    sx1, sy1 = IPAD_W - 56, IPAD_HEADER_H + 306
    rounded_rect(draw, [sx0, sy0, sx1, sy1], 28, fill=CARD_BG)
    draw.text((sx0 + 80, (sy0+sy1)//2), "食品名を検索...", font=fnt_med, fill=LIGHT_GRAY, anchor="lm")
    cx, cy, r = sx0 + 44, (sy0+sy1)//2, 20
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=LIGHT_GRAY, width=4)
    draw.line([cx+14, cy+14, cx+30, cy+30], fill=LIGHT_GRAY, width=4)

    draw.text((72, IPAD_HEADER_H + 334), "よく使う食品", font=fnt_sect, fill=GRAY)

    foods = [
        ("鶏むね肉（皮なし）", "100g", 108, 22.3, 1.5, 0.0),
        ("白米（炊き）",       "150g", 252,  3.8, 0.5, 55.7),
        ("絹ごし豆腐",         "100g",  56,  4.9, 3.0,  2.0),
        ("ブロッコリー",       "100g",  33,  4.3, 0.5,  5.2),
        ("サーモン（刺身）",    "80g", 168, 18.4,10.2,  0.1),
        ("ゆで卵",              "1個",  78,  6.5, 5.2,  0.4),
    ]

    item_h = 216
    start_y = IPAD_HEADER_H + 374
    for i, (name, amount, kcal, p, f, c) in enumerate(foods):
        iy0 = start_y + i * item_h
        iy1 = iy0 + item_h - 10
        if iy1 > IPAD_H - 20:
            break
        rounded_rect(draw, [56, iy0, IPAD_W - 56, iy1], 24, fill=CARD_BG)
        draw.text((100, iy0 + 28), name, font=fnt_med, fill=WHITE)
        draw.text((100, iy0 + 94), amount, font=fnt_small, fill=GRAY)
        draw.text((IPAD_W - 84, iy0 + 38), f"{kcal}", font=fnt_kcal, fill=PRIMARY, anchor="rm")
        draw.text((IPAD_W - 84, iy0 + 102), "kcal", font=fnt_unit, fill=GRAY, anchor="rm")
        pfc_x = 100
        pfc_row_y = iy0 + 148
        for label, val, col in [("P", p, (96,165,250)), ("F", f, (251,146,60)), ("C", c, (167,139,250))]:
            draw.ellipse([pfc_x, pfc_row_y+4, pfc_x+14, pfc_row_y+18], fill=col)
            txt = f"{label} {val:.1f}g"
            draw.text((pfc_x + 22, pfc_row_y), txt, font=fnt_pfc, fill=GRAY)
            bbox = draw.textbbox((0, 0), txt, font=fnt_pfc)
            pfc_x += (bbox[2] - bbox[0]) + 50
    return img

def make_ipad_meal_plan():
    img, draw = ipad_canvas()
    ipad_header(draw, ["AIが献立を", "自動で提案"], "あなたのダイエットに最適な毎日の献立")
    draw.rectangle([0, IPAD_HEADER_H, IPAD_W, IPAD_H], fill=APP_BG)
    ipad_status_bar(draw)

    fnt_large = font(FONT_BOLD_W6, 60)
    fnt_med   = font(FONT_REG_W3, 48)
    fnt_small = font(FONT_REG_W3, 38)
    fnt_kcal  = font(FONT_BOLD_W6, 52)
    fnt_tiny  = font(FONT_REG_W3, 34)
    fnt_title_bar = font(FONT_BOLD_W6, 64)
    fnt_btn   = font(FONT_BOLD_W6, 54)

    draw.text((IPAD_W//2, IPAD_HEADER_H + 115), "今日の献立",
              font=fnt_title_bar, fill=WHITE, anchor="mm")

    bw, bh = 270, 58
    bx = IPAD_W//2 + 220
    by = IPAD_HEADER_H + 86
    rounded_rect(draw, [bx, by, bx+bw, by+bh], 29, fill=(109, 40, 217))
    draw.text((bx+bw//2, by+bh//2), "✦ PREMIUM", font=fnt_tiny, fill=WHITE, anchor="mm")

    draw.text((IPAD_W//2, IPAD_HEADER_H + 182),
              "カロリー制限プラン　目標: 990 kcal/日",
              font=fnt_small, fill=GRAY, anchor="mm")

    meals = [
        ("朝食", 320, [("オートミール（40g）","148 kcal"),("ゆで卵 × 2","156 kcal"),("グリーンサラダ"," 16 kcal")]),
        ("昼食", 340, [("鶏むね肉のグリル（120g）","130 kcal"),("玄米（150g）","248 kcal"),("蒸し野菜ミックス"," 38 kcal")]),  # noqa: E501
        ("夕食", 330, [("鮭の塩焼き（100g）","133 kcal"),("豆腐の味噌汁"," 72 kcal"),("ほうれん草おひたし"," 18 kcal"),("玄米（100g）","165 kcal")]),  # noqa: E501
    ]

    card_y = IPAD_HEADER_H + 220
    gap = 20
    for meal_name, total_kcal, items in meals:
        card_h = 96 + len(items) * 72 + 36
        cx0, cx1 = 44, IPAD_W - 44
        cy0, cy1 = card_y, card_y + card_h
        if cy1 > IPAD_H - 30:
            break
        rounded_rect(draw, [cx0, cy0, cx1, cy1], 28, fill=CARD_BG)
        draw.text((cx0 + 36, cy0 + 28), meal_name, font=fnt_large, fill=WHITE)
        draw.text((cx1 - 32, cy0 + 28), f"{total_kcal} kcal", font=fnt_kcal, fill=PRIMARY, anchor="ra")
        draw.line([cx0+24, cy0+100, cx1-24, cy0+100], fill=(50,42,64), width=2)
        iy = cy0 + 116
        for iname, ikcal in items:
            draw.text((cx0+36, iy), "・" + iname, font=fnt_small, fill=(200,190,220))
            draw.text((cx1-32, iy), ikcal, font=fnt_small, fill=GRAY, anchor="ra")
            iy += 72
        card_y = cy1 + gap

    btn_y = max(card_y + 14, IPAD_H - 174)
    if btn_y < IPAD_H - 90:
        rounded_rect(draw, [80, btn_y, IPAD_W-80, btn_y+100], 50, fill=ACCENT)
        draw.text((IPAD_W//2, btn_y+50), "✦  献立を再生成", font=fnt_btn, fill=WHITE, anchor="mm")
    return img

# Build 4 iPad screenshots
ipad_screens = [
    ("ipad_01_today.png",    ["今日の食事を", "かんたん記録"],   "カロリー・PFCを自動で計算",  f"{RAW}/clean_tab0_today.png"),
    ("ipad_02_calendar.png", ["カレンダーで", "食事を振り返る"], "毎日の記録を一覧管理",      f"{RAW}/clean_tab2_calendar.png"),
]

for filename, title_lines, subtitle, raw_path in ipad_screens:
    print(f"Building {filename}...")
    img, draw = ipad_canvas()
    ipad_header(draw, title_lines, subtitle)
    ipad_paste_raw(img, raw_path)
    img.save(f"{OUT}/{filename}")
    print(f"  Saved {filename}")

print("Building ipad_03_search.png...")
make_ipad_food_search().save(f"{OUT}/ipad_03_search.png")
print("  Saved ipad_03_search.png")

print("Building ipad_04_meal_plan.png...")
make_ipad_meal_plan().save(f"{OUT}/ipad_04_meal_plan.png")
print("  Saved ipad_04_meal_plan.png")

print("\nDone! All 10 screenshots (6 iPhone + 4 iPad) generated.")
