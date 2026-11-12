"""Builds the thela produce list (lib/produce.dart) and small photos (assets/produce/*.webp)
from the photo zips. Common items get a simple name (Aloo, Pyaz…) and show first; the rest are "More types"."""
import csv, os, pathlib, sys
from PIL import Image

SRC = pathlib.Path(sys.argv[1])        # folder with Vegetables/ Fruits/ manifest.csv
EXTRA = pathlib.Path(sys.argv[2])      # folder with the 5 missing vegetables
OUT_IMG = pathlib.Path("assets/produce")
OUT_DART = pathlib.Path("lib/produce.dart")

# key, Hinglish name, English, Hindi, veg|fruit, unit, photo file, extra search words
COMMON = [
  ("aloo", "Aloo", "Potato", "आलू", "veg", "kg", "Vegetables/russet-potato.webp", "potato batata"),
  ("pyaz", "Pyaz", "Onion", "प्याज़", "veg", "kg", "Vegetables/red-onion.webp", "onion pyaaz kanda"),
  ("tamatar", "Tamatar", "Tomato", "टमाटर", "veg", "kg", "Vegetables/roma-tomato.webp", "tomato"),
  ("adrak", "Adrak", "Ginger", "अदरक", "veg", "kg", "Vegetables/fresh-ginger.webp", "ginger"),
  ("lehsun", "Lehsun", "Garlic", "लहसुन", "veg", "kg", "Vegetables/garlic-bulbs.webp", "garlic lahsun"),
  ("hari_mirch", "Hari Mirch", "Green Chilli", "हरी मिर्च", "veg", "kg", "Vegetables/indian-green-chilli.webp", "green chilli mirchi"),
  ("nimbu", "Nimbu", "Lemon", "नींबू", "veg", "piece", "Fruits/kagzi-lime.webp", "lemon lime limbu"),
  ("dhaniya", "Dhaniya", "Coriander", "धनिया", "veg", "bunch", "Vegetables/coriander-leaves.webp", "coriander cilantro"),
  ("pudina", "Pudina", "Mint", "पुदीना", "veg", "bunch", "Vegetables/mint-leaves.webp", "mint"),
  ("palak", "Palak", "Spinach", "पालक", "veg", "bunch", "Vegetables/spinach-palak.webp", "spinach"),
  ("methi", "Methi", "Fenugreek Leaves", "मेथी", "veg", "bunch", "Vegetables/fenugreek-leaves-methi.webp", "fenugreek"),
  ("sarson", "Sarson Saag", "Mustard Greens", "सरसों का साग", "veg", "bunch", "Vegetables/mustard-greens-sarson.webp", "mustard saag"),
  ("bathua", "Bathua", "Bathua Leaves", "बथुआ", "veg", "bunch", "Vegetables/bathua-leaves.webp", ""),
  ("kari_patta", "Kari Patta", "Curry Leaves", "करी पत्ता", "veg", "bunch", "Vegetables/curry-leaves.webp", "curry leaves kadi patta"),
  ("hara_pyaz", "Hara Pyaz", "Spring Onion", "हरा प्याज़", "veg", "bunch", "Vegetables/spring-onion.webp", "spring onion"),
  ("phool_gobhi", "Phool Gobhi", "Cauliflower", "फूलगोभी", "veg", "piece", "Vegetables/white-cauliflower.webp", "cauliflower gobi"),
  ("patta_gobhi", "Patta Gobhi", "Cabbage", "पत्तागोभी", "veg", "piece", "Vegetables/green-cabbage.webp", "cabbage band gobhi"),
  ("bhindi", "Bhindi", "Lady Finger", "भिंडी", "veg", "kg", "Vegetables/green-okra.webp", "okra ladyfinger"),
  ("baingan", "Baingan", "Brinjal", "बैंगन", "veg", "kg", "Vegetables/long-purple-brinjal.webp", "brinjal eggplant"),
  ("gol_baingan", "Gol Baingan", "Round Brinjal", "गोल बैंगन", "veg", "kg", "Vegetables/small-round-purple-brinjal.webp", "bharta brinjal"),
  ("lauki", "Lauki", "Bottle Gourd", "लौकी", "veg", "piece", "Vegetables/bottle-gourd.webp", "bottle gourd ghiya dudhi"),
  ("tori", "Tori", "Ridge Gourd", "तोरी", "veg", "kg", "Vegetables/ridge-gourd.webp", "ridge gourd turai"),
  ("nenua", "Nenua", "Sponge Gourd", "नेनुआ", "veg", "kg", "Vegetables/sponge-gourd.webp", "sponge gourd gilki"),
  ("karela", "Karela", "Bitter Gourd", "करेला", "veg", "kg", "Vegetables/green-bitter-gourd.webp", "bitter gourd"),
  ("tinda", "Tinda", "Round Gourd", "टिंडा", "veg", "kg", "Vegetables/round-tinda.webp", ""),
  ("parwal", "Parwal", "Pointed Gourd", "परवल", "veg", "kg", "Vegetables/pointed-gourd-parwal.webp", "pointed gourd"),
  ("kaddu", "Kaddu", "Pumpkin", "कद्दू", "veg", "kg", "Vegetables/orange-pumpkin.webp", "pumpkin sitaphal"),
  ("shimla_mirch", "Shimla Mirch", "Capsicum", "शिमला मिर्च", "veg", "kg", "Vegetables/green-capsicum.webp", "capsicum bell pepper"),
  ("gajar", "Gajar", "Carrot", "गाजर", "veg", "kg", "Vegetables/indian-red-carrot.webp", "carrot"),
  ("mooli", "Mooli", "Radish", "मूली", "veg", "kg", "Vegetables/daikon-radish.webp", "radish"),
  ("chukandar", "Chukandar", "Beetroot", "चुकंदर", "veg", "kg", "Vegetables/red-beetroot.webp", "beetroot beet"),
  ("shalgam", "Shalgam", "Turnip", "शलगम", "veg", "kg", "Vegetables/purple-top-white-turnip.webp", "turnip"),
  ("shakarkandi", "Shakarkandi", "Sweet Potato", "शकरकंदी", "veg", "kg", "Vegetables/orange-sweet-potato.webp", "sweet potato"),
  ("arbi", "Arbi", "Colocasia", "अरबी", "veg", "kg", "Vegetables/taro-arbi.webp", "taro colocasia"),
  ("matar", "Matar", "Green Peas", "मटर", "veg", "kg", "Vegetables/green-peas-in-pods.webp", "peas"),
  ("beans", "Beans", "French Beans", "बीन्स", "veg", "kg", "Vegetables/french-green-beans.webp", "french beans"),
  ("gwar_fali", "Gwar Fali", "Cluster Beans", "ग्वार फली", "veg", "kg", "Vegetables/cluster-beans.webp", "cluster beans guar"),
  ("sem", "Sem Fali", "Flat Beans", "सेम फली", "veg", "kg", "EXTRA/sem_fali_flat_beans.webp", "flat beans sem"),
  ("lobia_fali", "Lobia Fali", "Long Beans", "लोबिया फली", "veg", "kg", "Vegetables/yardlong-beans.webp", "long beans barbati"),
  ("kundru", "Kundru", "Ivy Gourd", "कुंदरू", "veg", "kg", "Vegetables/ivy-gourd.webp", "ivy gourd tindora"),
  ("sahjan", "Sahjan", "Drumstick", "सहजन", "veg", "kg", "Vegetables/moringa-drumstick-pods.webp", "drumstick moringa"),
  ("kheera", "Kheera", "Cucumber", "खीरा", "veg", "kg", "EXTRA/desi_kheera_indian_cucumber.webp", "cucumber kakdi"),
  ("kaccha_kela", "Kaccha Kela", "Raw Banana", "कच्चा केला", "veg", "piece", "EXTRA/kaccha_kela_raw_banana.webp", "raw banana plantain"),
  ("kathal", "Kathal", "Raw Jackfruit", "कटहल", "veg", "kg", "EXTRA/kaccha_kathal_raw_jackfruit.webp", "jackfruit"),
  ("mushroom", "Mushroom", "Mushroom (packet)", "मशरूम", "veg", "piece", "EXTRA/mushroom_white_button.webp", "khumbi"),
  ("bhutta", "Bhutta", "Sweet Corn", "भुट्टा", "veg", "piece", "Vegetables/sweetcorn.webp", "corn makka"),
  ("kela", "Kela", "Banana", "केला", "fruit", "dozen", "Fruits/cavendish-banana.webp", "banana"),
  ("elaichi_kela", "Elaichi Kela", "Small Banana", "इलायची केला", "fruit", "dozen", "Fruits/elaichi-banana.webp", "banana yelakki"),
  ("seb", "Seb", "Apple", "सेब", "fruit", "kg", "Fruits/kashmiri-red-delicious-apple.webp", "apple"),
  ("santra", "Santra", "Orange", "संतरा", "fruit", "kg", "Fruits/nagpur-mandarin.webp", "orange kinnow"),
  ("mosambi", "Mosambi", "Sweet Lime", "मौसमी", "fruit", "kg", "Fruits/mosambi-sweet-lime.webp", "sweet lime mausami"),
  ("angoor", "Angoor", "Green Grapes", "अंगूर", "fruit", "kg", "Fruits/thompson-green-seedless-grapes.webp", "grapes"),
  ("kale_angoor", "Kale Angoor", "Black Grapes", "काले अंगूर", "fruit", "kg", "Fruits/black-seedless-grapes.webp", "black grapes"),
  ("anaar", "Anaar", "Pomegranate", "अनार", "fruit", "kg", "Fruits/bhagwa-pomegranate.webp", "pomegranate"),
  ("papita", "Papita", "Papaya", "पपीता", "fruit", "kg", "Fruits/solo-papaya.webp", "papaya"),
  ("tarbooz", "Tarbooz", "Watermelon", "तरबूज़", "fruit", "kg", "Fruits/striped-watermelon.webp", "watermelon tarbuj"),
  ("kharbooza", "Kharbooza", "Muskmelon", "ख़रबूज़ा", "fruit", "kg", "Fruits/cantaloupe-muskmelon.webp", "muskmelon kharbuja"),
  ("amrood", "Amrood", "Guava", "अमरूद", "fruit", "kg", "Fruits/allahabad-safeda-white-guava.webp", "guava peru"),
  ("aam", "Aam", "Mango", "आम", "fruit", "kg", "Fruits/langra-mango.webp", "mango langra"),
  ("alphonso", "Alphonso Aam", "Alphonso Mango", "हापुस आम", "fruit", "dozen", "Fruits/alphonso-mango.webp", "hapus mango"),
  ("kaccha_aam", "Kaccha Aam", "Raw Mango", "कच्चा आम", "fruit", "kg", "Fruits/raw-green-mango.webp", "raw mango keri"),
  ("chikoo", "Chikoo", "Sapota", "चीकू", "fruit", "kg", "Fruits/sapota-chikoo.webp", "sapota chiku"),
  ("lichi", "Lichi", "Lychee", "लीची", "fruit", "kg", "Fruits/shahi-lychee.webp", "lychee litchi"),
  ("ananas", "Ananas", "Pineapple", "अनानास", "fruit", "piece", "Fruits/queen-pineapple.webp", "pineapple"),
  ("nashpati", "Nashpati", "Pear", "नाशपाती", "fruit", "kg", "Fruits/bartlett-pear.webp", "pear"),
  ("aloo_bukhara", "Aloo Bukhara", "Plum", "आलूबुख़ारा", "fruit", "kg", "Fruits/black-plum.webp", "plum"),
  ("jamun", "Jamun", "Jamun", "जामुन", "fruit", "kg", "Fruits/jamun.webp", "java plum"),
  ("ber", "Ber", "Jujube", "बेर", "fruit", "kg", "Fruits/indian-ber-jujube.webp", "jujube"),
  ("sitaphal", "Sitaphal", "Custard Apple", "सीताफल", "fruit", "kg", "Fruits/sitaphal-custard-apple.webp", "custard apple sharifa"),
  ("nariyal_pani", "Nariyal Pani", "Tender Coconut", "नारियल पानी", "fruit", "piece", "Fruits/tender-green-coconut.webp", "coconut water daab"),
  ("nariyal", "Nariyal", "Coconut", "नारियल", "fruit", "piece", "Fruits/mature-brown-coconut.webp", "coconut"),
  ("amla", "Amla", "Amla", "आंवला", "fruit", "kg", "Fruits/amla.webp", "gooseberry aonla"),
  ("strawberry", "Strawberry", "Strawberry (box)", "स्ट्रॉबेरी", "fruit", "piece", "Fruits/strawberry.webp", ""),
  ("kiwi", "Kiwi", "Kiwi", "कीवी", "fruit", "piece", "Fruits/green-kiwi.webp", ""),
  ("dragon_fruit", "Dragon Fruit", "Dragon Fruit", "ड्रैगन फ्रूट", "fruit", "piece", "Fruits/red-flesh-dragon-fruit.webp", ""),
  ("kathal_pakka", "Pakka Kathal", "Ripe Jackfruit", "पका कटहल", "fruit", "kg", "Fruits/ripe-jackfruit.webp", "jackfruit"),
]

PIECE_WORDS = ("coconut", "pineapple", "melon", "cabbage", "cauliflower", "corn", "lettuce", "squash", "artichoke", "avocado",
               "papaya", "pomelo", "kohlrabi", "romanesco", "broccoli", "fennel", "jackfruit", "dragon", "blossom", "bok choy")
BUNCH_WORDS = ("leaves", "basil", "parsley", "chives", "dill", "kale", "chard", "lemongrass", "arugula", "celery", "leek")


def small(src, dst):
    im = Image.open(src).convert("RGB").resize((256, 256), Image.LANCZOS)
    im.save(dst, "WEBP", quality=72, method=6)


def main():
    OUT_IMG.mkdir(parents=True, exist_ok=True)
    for f in OUT_IMG.glob("*.webp"):
        f.unlink()
    used = set()
    items = []
    for key, name, en, hi, cat, unit, photo, words in COMMON:
        src = EXTRA / photo[6:] if photo.startswith("EXTRA/") else SRC / photo
        small(src, OUT_IMG / f"{key}.webp")
        used.add(photo)
        items.append((key, name, en, hi, cat, unit, True, words))
    for row in csv.DictReader(open(SRC / "manifest.csv")):
        if row["path"] in used:
            continue
        key = row["filename"][:-5].replace("-", "_")
        title = row["product"].title().replace("Okra", "Okra").strip()
        cat = "fruit" if row["category"] == "Fruits" else "veg"
        low = row["product"].lower()
        unit = "bunch" if any(w in low for w in BUNCH_WORDS) else "piece" if any(w in low for w in PIECE_WORDS) else "kg"
        small(SRC / row["path"], OUT_IMG / f"{key}.webp")
        items.append((key, title, title, "", cat, unit, False, ""))
    esc = lambda s: s.replace("\\", "\\\\").replace("'", "\\'")
    lines = ["// Generated by tool/produce_build.py from the produce photo zips. Do not edit by hand.", "",
             "class Produce {",
             "  final String key, name, en, hi, cat, unit, words;",
             "  final bool common;",
             "  const Produce(this.key, this.name, this.en, this.hi, this.cat, this.unit, this.common, this.words);",
             "  String get image => 'assets/produce/$key.webp';",
             "}", "", "const kProduce = <Produce>["]
    for key, name, en, hi, cat, unit, common, words in items:
        lines.append(f"  Produce('{key}', '{esc(name)}', '{esc(en)}', '{esc(hi)}', '{cat}', '{unit}', {str(common).lower()}, '{esc(words)}'),")
    lines += ["];", "", "Produce? produceByKey(String k) {", "  for (final p in kProduce) {", "    if (p.key == k) return p;", "  }", "  return null;", "}", ""]
    OUT_DART.write_text("\n".join(lines))
    total = sum(f.stat().st_size for f in OUT_IMG.glob("*.webp"))
    print(len(items), "items,", sum(1 for i in items if i[6]), "common,", round(total / 1048576, 2), "MB of photos")


main()
