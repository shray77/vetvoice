#!/usr/bin/env python3
"""Task 191: медицинская сверка волны — окситоцин, марбофлоксацин,
animals-лакуны, нулевые дозы dosage_database, тилозин/амоксициллин
(провенанс). Источники — инструкции (см. отчёт Task 191).

Запуск: python3 scripts/fix_medical_audit.py  (из корня репо vetvoice)
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

OKSITOCIN_FIXED = {
    'Собаки': '5-10 МЕ (0,5-1 мл) на животное в/м',
    'Кошки': '3-5 МЕ (0,3-0,5 мл) на животное в/м',
    'КРС': '30-50 МЕ (3-5 мл) на животное в/м (в/м 30±10, п/к 45±15 МЕ/гол)',
    'Свиньи': '20-40 МЕ (2-4 мл) на животное в/м (свиноматки: в/м 20, п/к 30 МЕ/гол)',
    'Лошади': '20-40 МЕ (2-4 мл) на животное в/м',
}
# Источник: медвет.рф «Окситоцин» (МЕ/гол: коровы/кобылы в/м 30±10,
# п/к 45±15; свиноматки в/м 20, п/к 30; МРС 12,5±2), классика мелких
# животных (собаки 5-10 МЕ, кошки 3-5 МЕ). Дозы существующие в базе
# (30/20/5/3/20 МЕ) совпали со столбцом в/м — юниты врали, числа нет.

MARBO_NOTE = ('инструкция: 2 мг/кг 1 р/сут 3-5 дн (Марфлоксин 10% КРКА, '
              'Марбоцил 10%, Марбофлоксацин 100; 10 мг/кг — только EU '
              'однократный режим, к RU-препаратам не относится)')


def load(p: Path):
    return json.loads(p.read_text(encoding='utf-8'))


def save(p: Path, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                 encoding='utf-8')


def fix_oxytocin(dc) -> list:
    ops = []
    for d in dc['drugs_calc']:
        if d.get('name') != 'Окситоцин':
            continue
        d['dose_per_kg'] = 0
        d['dose_min'] = 0
        d['dose_max'] = 0
        d['dose_unit'] = 'fixed'
        d['calculator_applicable'] = False
        d['fixed_dose'] = dict(OKSITOCIN_FIXED)
        for sp, rec in (d.get('animal_specific') or {}).items():
            rec['dose_per_kg'] = 0
            rec['dose_min'] = 0
            rec['dose_max'] = 0
            rec['dose_unit'] = 'fixed'
        ops.append(f"Окситоцин id={d['id']}: парадигма «МЕ на животное» "
                   f"({len(OKSITOCIN_FIXED)} видов)")
    return ops


def fix_marbofloxacin(dc, vd) -> list:
    ops = []

    def fix_pool(pool, name_of):
        for item in pool:
            inn = str(item.get('inn') or '').lower()
            if 'марбофлоксацин' not in inn:
                continue
            for sep in (',', '+', ';'):
                if sep in inn:
                    continue
            sp = item.get('animal_specific') or {}
            rec = sp.get('Свиньи')
            if isinstance(rec, dict) and rec.get('dose_per_kg') == 10.0:
                rec['dose_per_kg'] = 2.0
                rec['dose_min'] = 1.0
                rec['dose_max'] = 4.0
                rec['dose_unit'] = rec.get('dose_unit') or 'мг/кг'
                rec['notes'] = MARBO_NOTE
                ops.append(f"марбофлоксацин {name_of(item)}: свиньи "
                           f"10 [8-12] -> 2 [1-4] мг/кг")
        return

    fix_pool(dc['drugs_calc'], lambda d: f"drugs_calc:{d.get('name')}")
    fix_pool((v for k, v in vd.items() if not k.startswith('_')),
             lambda d: f"verified:{d.get('inn') or d.get('name')}")
    # у verified имя препарата — ключ словаря; повторный проход по ключам
    for k, item in list(vd.items()):
        if k.startswith('_'):
            continue
        inn = str(item.get('inn') or '').lower()
        if 'марбофлоксацин' not in inn or any(s in inn for s in (',', '+', ';')):
            continue
        sp = item.get('animal_specific') or {}
        rec = sp.get('Свиньи')
        if isinstance(rec, dict) and rec.get('dose_per_kg') == 10.0:
            rec['dose_per_kg'] = 2.0
            rec['dose_min'] = 1.0
            rec['dose_max'] = 4.0
            rec['notes'] = MARBO_NOTE
            ops.append(f'марбофлоксацин verified:{k}: свиньи 10 [8-12] -> 2 [1-4]')
    return ops


def fix_animals_lacunas(dc) -> list:
    ops = []
    for d in dc['drugs_calc']:
        sp = d.get('animal_specific') or {}
        an = d.get('animals')
        if not isinstance(an, list):
            an = []
        miss = [k for k in sp if k not in an]
        if miss:
            an.extend(miss)
            d['animals'] = an
            ops.append(f"{d.get('name')}: animals +{miss}")
    return ops


NOTE_RANGE = re.compile(
    r'(\d+(?:[.,]\d+)?)\s*(?:[-–—]\s*(\d+(?:[.,]\d+)?)\s*)?мг/кг')


def fix_zero_dose_notes(db) -> list:
    ops = []
    for inn, sp in db['dosages'].items():
        for sp_name, rec in sp.items():
            if not isinstance(rec, dict):
                continue
            if rec.get('dose_mg_kg'):
                continue
            notes = str(rec.get('notes') or '')
            if 'мг/кг' not in notes:
                continue
            m = NOTE_RANGE.search(notes)
            if not m:
                continue
            lo = float(m.group(1).replace(',', '.'))
            hi = float(m.group(2).replace(',', '.')) if m.group(2) else lo
            if lo <= 0 or hi < lo or hi > 100:
                continue  # мусорные/запредельные — не трогаем
            rec['dose_mg_kg'] = round((lo + hi) / 2, 2)
            ops.append(f'dosage_database {inn}/{sp_name}: notes -> '
                       f'{rec["dose_mg_kg"]} мг/кг ({lo}-{hi})')
    return ops


def fix_provenance(vd) -> list:
    ops = []
    t = vd.get('Тилозин 20%')
    if t and isinstance(t.get('animal_specific', {}).get('КРС'), dict):
        t['animal_specific']['КРС']['notes'] = (
            'Vidal Тилозин 50/200: КРС 5-10 мг/кг в/м 1 р/сут 5-7 дн; '
            'часть продуктов: 1 мл/50 кг (=4 мг/кг). Диапазоны обеих '
            'парадигм instruction-backed')
        ops.append('verified Тилозин 20% КРС: провенанс Vidal')
    a = vd.get('Амоксициллин 15%')
    if a and isinstance(a.get('animal_specific', {}).get('КРС'), dict):
        a['animal_specific']['КРС']['notes'] = (
            'КРКА Амоксициллин 15%: КРС/овцы 7-11 мг/кг в/м-п/к 1 р/24ч '
            '3-5 дн; LA-формы 10-15 мг/кг однократно (Инвеса/Bioveta) — '
            'различие режимов, не ошибка')
        ops.append('verified Амоксициллин 15% КРС: провенанс КРКА')
    return ops


def fix_mini_drugs(dj) -> list:
    ops = []
    for d in dj['drugs']:
        if d.get('name') == 'Окситоцин':
            d['dose'] = 2.5
            d['unit'] = 'ml/животное'
            d['description'] = (
                'Стимулятор родовой деятельности, стимулятор лактации. '
                'Дозы МЕ на животное: КРС 30-50 МЕ (3-5 мл), свиньи 20-30 МЕ '
                '(2-3 мл), МРС 10-15 МЕ (1-1,5 мл) в/м при 10 ЕД/мл')
            ops.append('drugs.json Окситоцин: 0.05 мл -> 2.5 мл/животное + дозы в описании')
    return ops


def main():
    dc_p, vd_p = DATA / 'drugs_calc.json', DATA / 'verified_dosages.json'
    db_p, dj_p = DATA / 'dosage_database.json', DATA / 'drugs.json'
    dc, vd, db, dj = load(dc_p), load(vd_p), load(db_p), load(dj_p)

    ops = []
    ops += fix_oxytocin(dc)
    ops += fix_marbofloxacin(dc, vd)
    ops += fix_animals_lacunas(dc)
    ops += fix_zero_dose_notes(db)
    ops += fix_provenance(vd)
    ops += fix_mini_drugs(dj)

    save(dc_p, dc)
    save(vd_p, vd)
    save(db_p, db)
    save(dj_p, dj)

    print(f'Операций: {len(ops)}')
    for o in ops[:80]:
        print(' -', o)
    if len(ops) > 80:
        print(f' ... и ещё {len(ops) - 80}')


if __name__ == '__main__':
    main()
