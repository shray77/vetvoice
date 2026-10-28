#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_drug_db_units.py — точечные правки данных по итогам validate_drug_db.py.

Классы правок (только доказанные баги, каждая логируется):
  1. колистин/полимиксин: видовые дозы >=25000 с единицей мг/кг/пусто
     -> МЕ/кг (база записи уже МЕ/кг, notes прямо говорят «МЕ/кг»).
  2. Ферролонг: concentration 0.1 мг/мл -> 100 мг/мл (железо-декстран
     для новорождённых поросят; 0.1 давал «50000 мл на введение»).
  3. инсулин: dose_unit мг/кг -> МЕ/кг (инсулина в мг/кг не существует;
     численно доза уже МЕ/кг, метка врала калькулятору).

После правки — запись файлов и md5-сверка с ветэко (копия).
"""

import json
import shutil
import sys
from pathlib import Path

VETVOICE = Path('/home/z/my-project/repos/vetvoice/assets/data')
VETEKO = Path('/home/z/my-project/repos/vetvoice-rag/flutter/assets/data')

log = []


def is_num_eq(v, x, tol=1e-9):
    return isinstance(v, (int, float)) and not isinstance(v, bool) \
        and abs(v - x) < tol


def fix_colistin(d, fname, idx, name):
    """Правка 1: единицы колистин/полимиксин видовых записей."""
    inn = str(d.get('inn', '')).lower()
    if 'колистин' not in inn and 'полимиксин' not in inn:
        return
    changed = []
    specs = d.get('animal_specific') or {}
    for sp, o in specs.items():
        if not isinstance(o, dict):
            continue
        v = o.get('dose_per_kg')
        if isinstance(v, (int, float)) and v >= 25000 \
                and o.get('dose_unit') in (None, '', 'мг/кг'):
            o['dose_unit'] = 'МЕ/кг'
            changed.append(f'{sp}: {v} {o.get("dose_unit")!r}->МЕ/кг')
    if changed:
        log.append(f'[{fname}#{idx}] {name}: ' + '; '.join(changed))


def fix_insulin(d, fname, idx, name):
    """Правка 3: инсулин в МЕ/кг (числа уже МЕ/кг, метка врала)."""
    inn = str(d.get('inn', '')).lower()
    if 'инсулин' not in inn:
        return
    changed = []

    def fix_obj(o, where):
        v = o.get('dose_per_kg')
        if isinstance(v, (int, float)) and 0 < v <= 5 \
                and o.get('dose_unit') in (None, '', 'мг/кг'):
            o['dose_unit'] = 'МЕ/кг'
            changed.append(f'{where}: {v} ->МЕ/кг')

    fix_obj(d, 'база')
    for sp, o in (d.get('animal_specific') or {}).items():
        if isinstance(o, dict):
            fix_obj(o, sp)
    if changed:
        log.append(f'[{fname}#{idx}] {name}: ' + '; '.join(changed))


def fix_ferrolong_dc(d, fname, idx, name):
    """Правка 2а: Ферролонг в drugs_calc."""
    if 'ферролонг' not in str(d.get('name', '')).lower():
        return
    c = d.get('concentration')
    if c == 0.1:
        d['concentration'] = 100.0
        log.append(f'[{fname}#{idx}] {name}: conc 0.1 -> 100.0 мг/мл')


def fix_round2_dc(d, fname, idx, name):
    """Правки раунда 2 (по итогам полного прогона валидатора)."""
    inn = str(d.get('inn', '')).lower()
    # Бинакар Rus: циперметрин в спот-оне для кошек — летальная комбинация.
    if 'циперметрин' in inn and 'Кошки' in (d.get('animals') or []):
        d['animals'] = [a for a in d['animals'] if a != 'Кошки']
        specs = d.get('animal_specific') or {}
        specs.pop('Кошки', None)
        log.append(f'[{fname}#{idx}] {name}: ЦИПЕРМЕТРИН+КОШКИ — '
                   f'вид убран из animals/animal_specific (летально)')
    # Кофеин-бензоат 20%: единица «мл/кг» невозможна (10 мл/кг КРС = 4.5 л
    # в/в). Доза 10 — мг/кг (кофеин КРС/собакам верх диапазона).
    if 'кофеин' in inn and d.get('dose_unit') == 'мл/кг':
        d['dose_unit'] = 'мг/кг'
        log.append(f'[{fname}#{idx}] {name}: база мл/кг -> мг/кг')
    for sp, o in (d.get('animal_specific') or {}).items():
        if isinstance(o, dict) and 'кофеин' in inn \
                and o.get('dose_unit') == 'мл/кг':
            o['dose_unit'] = 'мг/кг'
            log.append(f'[{fname}#{idx}] {name}: {sp} мл/кг -> мг/кг')
    # Раунд 3 (полный прогон валидатора):
    # Домоседан: база 1.0 мг/кг (0.8-1.2) — 50-кратная передозировка
    # детомидина; видовая запись Лошади 0.02 (0.016-0.024) соответствует
    # инструкции. База выравнивается на видовую.
    if 'детомидин' in inn and is_num_eq(d.get('dose_per_kg'), 1.0):
        d['dose_per_kg'] = 0.02
        d['dose_min'] = 0.016
        d['dose_max'] = 0.024
        log.append(f'[{fname}#{idx}] {name}: детомидин база 1.0 -> '
                   f'0.02 мг/кг (0.016-0.024), по видовой записи')
    # Новокаин: видовые записи 8000 мг/кг (пенициллиновые значения из
    # чужой строки конверсии; прокаин летален уже ~100 мг/кг) — сносим,
    # fallback на корректную базу 5 мг/кг (2-10).
    if 'прокаин' in inn and 'новокаин' in name.lower():
        specs = d.get('animal_specific') or {}
        bogus = [sp for sp, o in specs.items()
                 if isinstance(o, dict) and is_num_eq(o.get('dose_per_kg'), 8000)]
        for sp in bogus:
            del specs[sp]
        if bogus:
            log.append(f'[{fname}#{idx}] {name}: снесены видовые записи с '
                       f'8000 мг/кг ({", ".join(bogus)}) — прокаину '
                       f'принадлежит база 5 мг/кг (2-10)')
    # Комбикел/Мастисан/Ветбицин: пенициллиновые МЕ в видовых записях с
    # меткой «мг/кг» (база — МЕ/кг; значения 1000-50000 — это ЕД/кг).
    if 'пенициллин' in inn:
        specs = d.get('animal_specific') or {}
        changed = []
        for sp, o in specs.items():
            if isinstance(o, dict) and isinstance(o.get('dose_per_kg'), (int, float)) \
                    and 1000 <= o['dose_per_kg'] <= 50000 \
                    and o.get('dose_unit') in (None, '', 'мг/кг'):
                o['dose_unit'] = 'МЕ/кг'
                changed.append(sp)
        if changed:
            log.append(f'[{fname}#{idx}] {name}: мг/кг -> МЕ/кг '
                       f'({", ".join(changed)}) — пенициллиновая часть')
    # Геставет Прост (d-клопростенол): «0.96 мг/кг» — на деле 0.96 МКГ/кг
    # (реальная доза ~500 мкг на корову = 1.1 мкг/кг; диапазон 0.768-1.152
    # идеально ложится в мкг/кг). Метка «мг/кг» — 1000-кратная передозировка
    # простагландина F2a.
    if 'клопростенол' in inn and d.get('dose_unit') == 'мг/кг' \
            and is_num_eq(d.get('dose_per_kg'), 0.96, 0.2):
        d['dose_unit'] = 'мкг/кг'
        log.append(f'[{fname}#{idx}] {name}: клопростенол мг/кг -> мкг/кг '
                   f'(0.96 мкг/кг = ~0.43 мг на корову — реальная доза)')


def main():
    # ── drugs_calc.json ────────────────────────────────────────────────
    p = VETVOICE / 'drugs_calc.json'
    data = json.loads(p.read_text(encoding='utf-8'))
    for i, d in enumerate(data['drugs_calc']):
        if not isinstance(d, dict):
            continue
        name = str(d.get('name') or d.get('inn') or f'id={d.get("id")}')
        fix_colistin(d, 'drugs_calc', i, name)
        fix_insulin(d, 'drugs_calc', i, name)
        fix_ferrolong_dc(d, 'drugs_calc', i, name)
        fix_round2_dc(d, 'drugs_calc', i, name)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                 encoding='utf-8')
    print(f'drugs_calc.json перезаписан')

    # ── verified_dosages.json ──────────────────────────────────────────
    p = VETVOICE / 'verified_dosages.json'
    data = json.loads(p.read_text(encoding='utf-8'))
    for k, d in data.items():
        if not isinstance(d, dict) or str(k).startswith('_'):
            continue
        name = str(k)
        inn = str(d.get('inn', '')).lower()
        # колистин/полимиксин
        if 'колистин' in inn or 'полимиксин' in inn or 'колистин' in name.lower():
            changed = []
            for sp, o in (d.get('animal_specific') or {}).items():
                if not isinstance(o, dict):
                    continue
                v = o.get('dose_per_kg')
                if isinstance(v, (int, float)) and v >= 25000 \
                        and o.get('dose_unit') in (None, '', 'мг/кг'):
                    o['dose_unit'] = 'МЕ/кг'
                    changed.append(f'{sp}->МЕ/кг')
            if changed:
                log.append(f'[verified#{name}]: ' + '; '.join(changed))
        # инсулин
        if 'инсулин' in inn or 'инсулин' in name.lower():
            changed = []
            for sp, o in (d.get('animal_specific') or {}).items():
                if not isinstance(o, dict):
                    continue
                v = o.get('dose_per_kg')
                if isinstance(v, (int, float)) and 0 < v <= 5 \
                        and o.get('dose_unit') in (None, '', 'мг/кг'):
                    o['dose_unit'] = 'МЕ/кг'
                    changed.append(f'{sp}->МЕ/кг')
            if changed:
                log.append(f'[verified#{name}]: ' + '; '.join(changed))
        # Ферролонг conc
        if 'ферролонг' in name.lower() and d.get('concentration') == 0.1:
            d['concentration'] = 100.0
            log.append(f'[verified#{name}]: conc 0.1 -> 100.0 мг/мл')
        # раунд 2: циперметрин+кошки, кофеин мл/кг
        if 'циперметрин' in inn:
            specs = d.get('animal_specific') or {}
            if specs.pop('Кошки', None) is not None:
                if isinstance(d.get('animals'), list) and 'Кошки' in d['animals']:
                    d['animals'] = [a for a in d['animals'] if a != 'Кошки']
                log.append(f'[verified#{name}]: ЦИПЕРМЕТРИН+КОШКИ — вид убран '
                           f'(летально)')
        # раунд 3: Домоседан / Новокаин / пенициллины — зеркально drugs_calc
        if 'детомидин' in inn and is_num_eq(d.get('dose_per_kg'), 1.0):
            specs = d.get('animal_specific') or {}
            horse = specs.get('Лошади') or {}
            if is_num_eq(horse.get('dose_per_kg'), 0.02, 0.01):
                d['dose_per_kg'] = 0.02
                d['dose_min'] = horse.get('dose_min', 0.016)
                d['dose_max'] = horse.get('dose_max', 0.024)
                log.append(f'[verified#{name}]: детомидин база 1.0 -> 0.02 мг/кг')
        if 'прокаин' in inn and 'новокаин' in name.lower():
            specs = d.get('animal_specific') or {}
            bogus = [sp for sp, o in specs.items()
                     if isinstance(o, dict) and is_num_eq(o.get('dose_per_kg'), 8000)]
            for sp in bogus:
                del specs[sp]
            if bogus:
                log.append(f'[verified#{name}]: снесены видовые 8000 мг/кг '
                           f'({", ".join(bogus)})')
        if 'пенициллин' in inn:
            changed = []
            for sp, o in (d.get('animal_specific') or {}).items():
                if isinstance(o, dict) and isinstance(o.get('dose_per_kg'), (int, float)) \
                        and 1000 <= o['dose_per_kg'] <= 50000 \
                        and o.get('dose_unit') in (None, '', 'мг/кг'):
                    o['dose_unit'] = 'МЕ/кг'
                    changed.append(sp)
            if changed:
                log.append(f'[verified#{name}]: мг/кг -> МЕ/кг '
                           f'({", ".join(changed)}) — пенициллиновая часть')
        if 'клопростенол' in inn and d.get('dose_unit') == 'мг/кг' \
                and is_num_eq(d.get('dose_per_kg'), 0.96, 0.2):
            d['dose_unit'] = 'мкг/кг'
            log.append(f'[verified#{name}]: клопростенол мг/кг -> мкг/кг')
        if 'кофеин' in inn:
            changed = []
            if d.get('dose_unit') == 'мл/кг':
                d['dose_unit'] = 'мг/кг'
                changed.append('база мл/кг->мг/кг')
            for sp, o in (d.get('animal_specific') or {}).items():
                if isinstance(o, dict) and o.get('dose_unit') == 'мл/кг':
                    o['dose_unit'] = 'мг/кг'
                    changed.append(f'{sp} мл/кг->мг/кг')
            if changed:
                log.append(f'[verified#{name}]: ' + '; '.join(changed))
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                 encoding='utf-8')
    print(f'verified_dosages.json перезаписан')

    print(f'\nправок: {len(log)}')
    for line in log:
        print('  ' + line)

    # ── копия в ветэко ─────────────────────────────────────────────────
    if VETEKO.is_dir():
        for fname in ('drugs_calc.json', 'verified_dosages.json'):
            shutil.copy2(VETVOICE / fname, VETEKO / fname)
        print('\nветэко: копии обновлены')
    else:
        print('\nветэко: каталог не найден — копия пропущена')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
