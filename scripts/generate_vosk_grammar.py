#!/usr/bin/env python3
"""
Генератор JSGF-грамматики для Vosk.

Создаёт файл vet_voice_grammar.json с топ-N вет. препаратов и команд,
которые Vosk будет распознавать с высокой точностью.

JSGF (Java Speech Grammar Format) — формат грамматики для STT.
Vosk поддерживает JSON-формат грамматики через Recognizer.setGrammar().

Формат: простой JSON-массив слов/фраз.
Vosk ограничивает размер грамматики ~1000 слов для small-модели.

Использование:
    python3 generate_vosk_grammar.py
    # → assets/data/vosk_grammar.json

После генерации — VoskWakeWordService.kt загружает грамматику
и передаёт в Recognizer при создании.
"""

import json
import re
from pathlib import Path


def normalize_word(word: str) -> str:
    """Нормализовать слово для грамматики Vosk."""
    word = word.lower().strip()
    # Удаляем специальные символы, оставляем кириллицу/латиницу/цифры/дефис
    word = re.sub(r"[^\w\s-]", "", word, flags=re.UNICODE)
    word = re.sub(r"\s+", " ", word).strip()
    return word


def is_good_word(word: str) -> bool:
    """Подходит ли слово для грамматики?"""
    if not word or len(word) < 3:
        return False
    # Пропускаем слишком длинные фразы (Vosk плохо с длинными)
    if len(word.split()) > 3:
        return False
    # Пропускаем мусор
    if word.startswith("#") or word.startswith("вакцина "):
        return False
    # Должны быть буквы
    if not re.search(r"[а-яёa-z]", word, re.IGNORECASE):
        return False
    return True


def generate_grammar(drugs_calc_path: str, output_path: str, max_words: int = 800):
    """Сгенерировать грамматику из drugs_calc.json.

    Args:
        drugs_calc_path: путь к drugs_calc.json
        output_path: куда сохранить грамматику
        max_words: максимум слов в грамматике (Vosk small-модель лимит ~1000)
    """
    with open(drugs_calc_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    words = set()

    # 1. Торговые наименования (топ-приоритет)
    for drug in data.get("drugs_calc", []):
        name = normalize_word(drug.get("name", ""))
        # Убираем ® и лишние символы
        name = name.replace("®", "").replace("™", "").strip()
        if is_good_word(name):
            words.add(name)

    # 2. МНН (международные непатентованные наименования)
    for drug in data.get("drugs_calc", []):
        inn = drug.get("inn", "")
        # МНН может быть составным — берём все компоненты
        if "," in inn:
            parts = inn.split(",")
            for part in parts[:3]:  # первые 3 компонента
                w = normalize_word(part)
                if is_good_word(w):
                    words.add(w)
        else:
            w = normalize_word(inn)
            if is_good_word(w):
                words.add(w)

    # 2.5. Критические мед-термины — добавляем вручную, чтобы гарантированно были
    critical_terms = [
        "маропитант", "флорфеникол", "энрофлоксацин", "маропитанта",
        "мелоксикам", "дексаметазон", "преднизолон", "диклофенак",
        "кетопрофен", "карпрофен", "габапентин", "трамадол",
        "метоклопрамид", "ондансетрон", "ранитидин", "омепразол",
        "метронидазол", "сульфаметоксазол", "триметоприм",
        "доксициклин", "тилозин", "тилмикозин", "флорфеникола",
        "цефтиофур", "цефапирин", "цефалексин", "цефазолин",
        "гентамицин", "амикацин", "неомицин", "стрептомицин",
        "пенициллин", "бензилпенициллин", "амоксициллина",
        "кларитромицин", "эритромицин", "азитромицин",
        "ивермектин", "моксидектин", "дорамектин", "селамектин",
        "фипронил", "имидаклоприд", "дельтаметрин", "перметрин",
        "празиквантел", "фенбендазол", "альбендазол", "мебендазол",
        "пирантел", "левамизол", "морантел",
        "фурозолидон", "метронидазол", "диметридазол",
        "толтразурил", "диклазурил", "амполиум", "монензин",
        "салиномицин", "наразин", "мадурамицин",
        "атропин", "адреналин", "дофамин", "добутамин",
        "эналаприл", "беназеприл", "рамиприл", "фуросемид",
        "спиронолактон", "верапамил", "дилтиазем",
        "пропранолол", "атенолол", "карведилол",
        "инсулин", "глюкагон", "преднизолон",
        "левотироксин", "метимазол", "карбимазол",
        "цианокобаламин", "тиамин", "рибофлавин", "пиридоксин",
        "фолиевая кислота", "аскорбиновая кислота",
        "токоферол", "ретинол", "холекальциферол",
        "гепарин", "варфарин", "эноксапарин",
        "ализин", "аглепристон", "клопростенол",
        "хорионический гонадотропин",
        "питуитрин", "окситоцин",
        "противорвотное", "обезболивающее", "жаропонижающее",
        "противовоспалительное", "антигистаминное",
        "иммуномодулятор", "гепатопротектор",
        "диуретик", "спазмолитик", "сорбент",
    ]
    for term in critical_terms:
        w = normalize_word(term)
        if w and len(w) >= 3:
            words.add(w)

    # 3. Команды для голосового управления
    commands = [
        "ветвойс", "вет помощь", "ветеринар",
        "собака", "кошка", "корова", "лошадь", "свинья",
        "птица", "кролик", "овца", "коза",
        "поиск", "найти", "показать",
        "доза", "расчёт", "рассчитай",
        "избранное", "история", "настройки",
        "противорвотное", "обезболивающее", "антибиотик",
        "противоглистное", "противопаразитарное",
        "вакцина", "прививка", "укол",
        "внутримышечно", "подкожно", "перорально", "внутрь",
        "внутривенно", "наружно",
        "один", "два", "три", "четыре", "пять",
        "шесть", "семь", "восемь", "девять", "десять",
        "пятнадцать", "двадцать", "тридцать", "сорок", "пятьдесят",
        "сот", "грамм", "килограмм", "миллиграмм",
        "раз в день", "два раза", "три раза",
        "каждые двенадцать часов", "каждые двадцать четыре часа",
        "повтори", "озвучь", "сброс",
        "назад", "выход", "отмена",
    ]
    for cmd in commands:
        w = normalize_word(cmd)
        if w:
            words.add(w)

    # 4. Животные (нормализованные)
    animals = ["собаки", "кошки", "крс", "мрс", "свиньи", "лошади",
               "птица", "кролики", "пушные звери", "пчёлы"]
    for a in animals:
        words.add(a)

    # Сортируем и ограничиваем — critical_terms имеют приоритет
    # Сначала добавляем critical_terms, потом остальное
    critical_set = set()
    for term in critical_terms:
        w = normalize_word(term)
        if w and len(w) >= 3:
            critical_set.add(w)

    # Остальные слова (без critical)
    other_words = words - critical_set
    sorted_other = sorted(other_words)

    # critical + other, ограничиваем
    all_words = sorted(critical_set) + sorted_other
    if len(all_words) > max_words:
        all_words = all_words[:max_words]

    grammar = all_words

    # Vosk принимает JSON-массив строк
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(grammar, f, ensure_ascii=False, indent=2)

    print(f"✅ Грамматика: {len(grammar)} слов → {output_path}")
    print(f"   Примеры: {grammar[:10]}")
    return len(grammar)


if __name__ == "__main__":
    import sys

    drugs_calc = sys.argv[1] if len(sys.argv) > 1 else "assets/data/drugs_calc.json"
    output = sys.argv[2] if len(sys.argv) > 2 else "assets/data/vosk_grammar.json"
    max_w = int(sys.argv[3]) if len(sys.argv) > 3 else 800

    generate_grammar(drugs_calc, output, max_w)
