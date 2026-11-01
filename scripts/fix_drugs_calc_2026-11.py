#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Task 223 (фикс волны 2026-11-01, аудит SW-19 §4.2 «Предложение (данные)»).

Точечные правки assets/data/drugs_calc.json по итогам научного аудита
дозирования (vet-swarm-audit/swarm-2026-11-01/19-vetvoice-science/).
Скрипт идемпотентен: повторный запуск ничего не меняет и печатает
«пропущено: уже применено». Числа взяты ТОЛЬКО из лейблов FDA/EMA и
Merck Vet Manual (источники — §6 audit-report.md); ничего не придумано.

Правки:
1. #1918 Флунекс (флуниксин меглумин), Свиньи: 8.3 → 2.2 мг/кг —
   FDA Flunazine-S (1 мг/фунт IM, 2 мл/100 lb). 8.3 было = conc/10
   («процент как доза», передозировка 3.8×: 5.0 мл вместо 1.3 мл
   на свинью 50 кг).
2. #1618 Флексопрофен (кетопрофен), КРС: 10 → 3 мг/кг — Merck Vet
   Manual (КРС 3 мг/кг/сут IV/IM). 10 было = conc/10 (передозировка
   3.3×: 50 мл вместо 15 мл на корову 500 кг). Видовая доза Свиней
   (10 мг/кг — в MVM не подтверждено) удалена вместе с видом: калькулятор
   честно ответит «нет данных для вида».
3. Колистин — записи из логов аудита (#43, #52, #88, #294, #570, #755,
   #1459, #1561; EMA CVMP 2015, colistin article-35 referral):
   - Птица: 50 000 → 75 000 МЕ/кг/день (было занижено на 1/3);
   - КРС (телята): частота «1 раз в сутки» → «2 раза в день»
     (50 000 МЕ/кг ×2/день; было вдвое занижено);
   - Свиньи 50 000 МЕ/кг ×2/день — уже соответствует EMA, не трогаем.
   #1459 (Птица уже 75 000) — пропускается автоматически.
4. #483 Гельминтал Мини Табс: «Собаки 30 мг/кг» → 5 мг/кг —
   празиквантел ≈5 мг/кг (Droncit/Drontal Plus); 30 — ивермектиновое
   число. Ивермектиновая «доза КРС 0.2 мг/кг» удалена вместе с видом.
5. #1279 Гельминтал Мини сироп: «Кошки 0.003 мг/кг» (число топического
   моксидектина в сиропе) удалена вместе с видом.
6. #520 Адвокат: «Собаки 0.003 мг/кг» (топический моксидектин,
   дозируется пипетками по весу) удалена вместе с видом.
7. conc-мусор: 152 строковых концентраций, которые CalcDrug._parseDouble
   (drug_models.dart:62-78) превращает в 0 или >1000 («#####»,
   «6 000 000 МЕ; 12 000 000 МЕ», «10 000 мг / 50 000 мг» — инвентаризация
   SW-19 logs/step0_garbage_counts.log) → concentration = null.
   Калькулятор честно покажет дозу без объёма; заодно ветка «МЕ/кг»
   нового calculateDose не поделит МЕ на фейковые «МЕ/мл». Строковые
   валидные conc («100 мг/мл», «40 МЕ/мл») не тронуты.

НЕ тронуто (решение за владельцем): конфликты RU/US-лейблов (тилозин
КРС 5 мг/кг, окситоцин КРС 30–50 МЕ, цефтиофур свиньи 2.0,
энрофлоксацин свиньи 5, фуросемид собак 2); Мариния conc 5 мг/мл
(нужен RU-лейбл); мультиконцентрационные Флексопрофен 2,5/5/10%,
Энросепт 5/10%, Толфемакс 4/8%; ЭНРОСОЛ conc=5000 и Амоксициллин 20% LA
conc=150 (класс «conc ≠ %×10», 20 записей); 21 LA-запись с конфликтом
frequency «2 раза в день» vs видовая «1 раз в 48 часов».

Запуск:  python3 scripts/fix_drugs_calc_2026-11.py [--dry-run]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'assets' / 'data' / 'drugs_calc.json'

DRY_RUN = '--dry-run' in sys.argv

# ── 1:1 реплика CalcDrug._parseDouble (drug_models.dart:62-78) ─────────────
def parse_double(value, default=0.0):
    if value is None:
        return default
    if isinstance(value, float):
        return value
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return float(value)
    if isinstance(value, str):
        s = re.sub(r'[\s\u00A0]', '', value)
        s = re.sub(r'[Мм][Ее]|мг|мл|г', '', s)
        s = s.replace(',', '.')
        s = re.sub(r'[^\d.]', '', s).strip()
        if not s:
            return default
        try:
            return float(s)
        except ValueError:
            return default
    return default


CHANGES: list[str] = []
SKIPS: list[str] = []


def change(drug_id: int, name: str, where: str, old, new) -> None:
    CHANGES.append(f'#{drug_id} {name}: {where}: {old!r} → {new!r}')


def skip(drug_id: int, name: str, why: str) -> None:
    SKIPS.append(f'#{drug_id} {name}: {why}')


def set_field(drug_id, name, obj: dict, key: str, new) -> bool:
    old = obj.get(key)
    if old == new:
        return False
    obj[key] = new
    change(drug_id, name, key, old, new)
    return True


# ── Колистин: EMA CVMP 2015 ────────────────────────────────────────────────
COLISTIN_IDS = [43, 52, 88, 294, 570, 755, 1459, 1561]
BIRD_DOSE = 75000          # МЕ/кг/день (EMA Annexes: птица 75 000)
CATTLE_FREQ = '2 раза в день'   # телята: 50 000 МЕ/кг ×2/день
BIRD_NOTE = ('75 000 МЕ/кг/день через питьевую воду '
             '(EMA CVMP 2015, колистин, article-35 referral)')
CATTLE_NOTE = 'Телята: 50 000 МЕ/кг ×2/день (EMA CVMP 2015, колистин)'


def fix_colistin(by_id: dict) -> None:
    for did in COLISTIN_IDS:
        d = by_id.get(did)
        if d is None:
            skip(did, '—', 'запись не найдена')
            continue
        name = d.get('name', '?')
        if d.get('inn') != 'колистин':
            skip(did, name, f'inn={d.get("inn")!r} — не чистый колистин')
            continue
        spec = d.setdefault('animal_specific', {})

        bird = spec.get('Птица')
        if isinstance(bird, dict):
            dose = bird.get('dose_per_kg')
            if dose == BIRD_DOSE:
                skip(did, name, 'Птица уже 75 000 МЕ/кг — не тронуто')
            elif dose == 50000:
                set_field(did, name, bird, 'dose_per_kg', BIRD_DOSE)
                set_field(did, name, bird, 'dose_min', float(BIRD_DOSE))
                set_field(did, name, bird, 'dose_max', float(BIRD_DOSE))
                set_field(did, name, bird, 'frequency', '1 раз в день')
                set_field(did, name, bird, 'notes', BIRD_NOTE)
            else:
                skip(did, name, f'Птица dose={dose!r} — неожиданное '
                                'значение, правка только для 50 000')

        cattle = spec.get('КРС')
        if isinstance(cattle, dict):
            freq = cattle.get('frequency')
            if freq == CATTLE_FREQ:
                skip(did, name, 'КРС уже ×2/день — не тронуто')
            elif freq == '1 раз в сутки':
                set_field(did, name, cattle, 'frequency', CATTLE_FREQ)
                set_field(did, name, cattle, 'notes', CATTLE_NOTE)
            else:
                skip(did, name, f'КРС frequency={freq!r} — неожиданное '
                                'значение, правка только для «1 раз в сутки»')


# ── Точечные правки доз ────────────────────────────────────────────────────
def fix_flunex(by_id: dict) -> None:
    """#1918 Флунекс, Свиньи: 8.3 → 2.2 мг/кг (FDA Flunazine-S)."""
    d = by_id[1918]
    name = d['name']
    if d.get('dose_per_kg') == 2.2:
        skip(1918, name, 'уже применено')
        return
    set_field(1918, name, d, 'dose_per_kg', 2.2)
    set_field(1918, name, d, 'dose_min', 2.2)
    set_field(1918, name, d, 'dose_max', 2.2)
    pig = d['animal_specific']['Свиньи']
    set_field(1918, name, pig, 'dose_per_kg', 2.2)
    set_field(1918, name, pig, 'dose_min', 2.2)
    set_field(1918, name, pig, 'dose_max', 2.2)
    set_field(1918, name, pig, 'notes',
              'Свиньи: 2.2 мг/кг (FDA Flunazine-S: 1 мг/фунт IM)')


def fix_flexoprofen(by_id: dict) -> None:
    """#1618 Флексопрофен, КРС: 10 → 3 мг/кг (MVM); Свиньи — убрать."""
    d = by_id[1618]
    name = d['name']
    if d.get('dose_per_kg') == 3 and 'Свиньи' not in d.get('animals', []):
        skip(1618, name, 'уже применено')
        return
    set_field(1618, name, d, 'dose_per_kg', 3)
    set_field(1618, name, d, 'dose_min', 3)
    set_field(1618, name, d, 'dose_max', 3)
    cattle = d['animal_specific']['КРС']
    set_field(1618, name, cattle, 'dose_per_kg', 3)
    set_field(1618, name, cattle, 'dose_min', 3)
    set_field(1618, name, cattle, 'dose_max', 3)
    set_field(1618, name, cattle, 'notes',
              'КРС: 3 мг/кг/сут IV/IM (Merck Vet Manual)')
    # Свиньи: доза не подтверждена — вид убираем целиком
    if 'Свиньи' in d.get('animals', []):
        d['animals'].remove('Свиньи')
        change(1618, name, 'animals', 'Свиньи', 'удалён (доза не подтверждена)')
    if 'Свиньи' in d.get('animal_specific', {}):
        del d['animal_specific']['Свиньи']
        change(1618, name, 'animal_specific.Свиньи',
               '10 мг/кг (=conc/10)', 'удалена (доза не подтверждена MVM)')


def fix_helmintal_tabs(by_id: dict) -> None:
    """#483 Гельминтал Мини Табс: Собаки 30 → 5 мг/кг; КРС 0.2 — убрать."""
    d = by_id[483]
    name = d['name']
    dog = d['animal_specific'].get('Собаки')
    if isinstance(dog, dict) and dog.get('dose_per_kg') == 5:
        skip(483, name, 'уже применено')
        return
    set_field(483, name, dog, 'dose_per_kg', 5)
    set_field(483, name, dog, 'notes',
              'Празиквантел: 5–10 мг/кг, стандарт ≈5 мг/кг (Droncit/Drontal Plus)')
    if 'КРС' in d.get('animals', []):
        d['animals'].remove('КРС')
        change(483, name, 'animals', 'КРС', 'удалён (доза 0.2 — ивермектиновая)')
    if 'КРС' in d.get('animal_specific', {}):
        del d['animal_specific']['КРС']
        change(483, name, 'animal_specific.КРС', '0.2 мг/кг',
               'удалена (ивермектиновое число в празиквантел-записи)')


def fix_helmintal_syrup(by_id: dict) -> None:
    """#1279 Гельминтал Мини сироп: «Кошки 0.003 мг/кг» — убрать."""
    d = by_id[1279]
    name = d['name']
    if 'Кошки' not in d.get('animals', []) and \
            'Кошки' not in d.get('animal_specific', {}):
        skip(1279, name, 'уже применено')
        return
    if 'Кошки' in d.get('animals', []):
        d['animals'].remove('Кошки')
        change(1279, name, 'animals', 'Кошки', 'удалён')
    if 'Кошки' in d.get('animal_specific', {}):
        del d['animal_specific']['Кошки']
        change(1279, name, 'animal_specific.Кошки', '0.003 мг/кг',
               'удалена (число топического моксидектина в сиропе)')


def fix_advocate(by_id: dict) -> None:
    """#520 Адвокат: «Собаки 0.003 мг/кг» — убрать (топический моксидектин)."""
    d = by_id[520]
    name = d['name']
    if 'Собаки' not in d.get('animals', []) and \
            'Собаки' not in d.get('animal_specific', {}):
        skip(520, name, 'уже применено')
        return
    if 'Собаки' in d.get('animals', []):
        d['animals'].remove('Собаки')
        change(520, name, 'animals', 'Собаки', 'удалён')
    if 'Собаки' in d.get('animal_specific', {}):
        del d['animal_specific']['Собаки']
        change(520, name, 'animal_specific.Собаки', '0.003 мг/кг',
               'удалена (топический моксидектин дозируется пипетками по весу)')


# ── conc-мусор ─────────────────────────────────────────────────────────────
def fix_garbage_conc(drugs: list) -> int:
    """Строковая concentration, которую _parseDouble превращает в 0 или
    >1000 (критерий инвентаризации SW-19 step0_garbage_counts.log),
    обнуляется: калькулятор честно покажет дозу без объёма."""
    n = 0
    for d in drugs:
        conc = d.get('concentration')
        if not isinstance(conc, str):
            continue
        v = parse_double(conc)
        if v == 0 or v > 1000:
            d['concentration'] = None
            n += 1
            if n <= 12:  # в лог — первые 12, полный список в гейте аудита
                CHANGES.append(f"#{d['id']} {d['name']}: concentration: "
                                f"{conc!r} → null (parse={v:g})")
    if n > 12:
        CHANGES.append(f'… и ещё {n - 12} мусорных concentration → null '
                       '(полный список: logs/step0_garbage_counts.log аудита)')
    return n


def main() -> int:
    data = json.loads(DB.read_text(encoding='utf-8'))
    drugs = data['drugs_calc']
    by_id = {d['id']: d for d in drugs}

    fix_colistin(by_id)
    fix_flunex(by_id)
    fix_flexoprofen(by_id)
    fix_helmintal_tabs(by_id)
    fix_helmintal_syrup(by_id)
    fix_advocate(by_id)
    garbage_n = fix_garbage_conc(drugs)

    print(f'Изменено полей: {len(CHANGES)}  (мусорных concentration: {garbage_n})')
    for line in CHANGES:
        print('  ИЗМ', line)
    for line in SKIPS:
        print('  ПРОПУСК', line)

    if DRY_RUN:
        print('\n--dry-run: файл не записан')
        return 0

    DB.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    print(f'\nЗаписано: {DB}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
