#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Task 224 (2026-11-02, решение владельца «концентрации под RU, вариант А»).

Правки assets/data/drugs_calc.json канонического источника (vetvoice).
Скрипт идемпотентен: повторный запуск ничего не меняет. Все числа — по
RU-фармстандарту для водных растворов: 1% = 10 мг/мл (плотность ~1 г/мл),
что совпадает с формой записи концентраций в RU-инструкциях (5% раствор
для инъекций = 50 мг/мл). Основа: аудит SW-19 §4.1 (мультиконцентрационные
препараты и «conc ≠ %×10», 20 инъекционных записей) + свежий проход базы
scripts/task223_multiconc_explain.py (32 записи с несколькими % в названии).

Правила:
A. Мультиконц-варианты (в названии ≥2 разных %, form_type ∈ injection /
   solution / oral_solution / oral): добавить concentration_variants =
   [{label: '5%', concentration: 50.0}, …] — отсортированы по возрастанию.
   Поле concentration остаётся прежним, если оно входит в варианты
   (дефолт = «флакон по умолчанию»), иначе — младшая фасовка.
B. Одна % в названии, conc числовая и ≠ %×10 (допуск 15%, те же
   form_type): concentration → %×10 (Амоксициллин 20% LA: 150 → 200).
C. Топикалы (topical/external/other) со строковой/граммовой conc-ерундой
   («10 г», «10000 мг / …») → concentration = null: мази калькулятором
   не считаются, мусорное число лишь имитирует точность.
D. LA-гигиена частоты (аудит «21 LA-запись», живой проход — 62): если
   У ВСЕХ видов записи animal_specific.frequency непустая и одинаковая,
   повидовая = «1 раз в N часов» (N ≥ 36) или «однократно», а общая
   frequency = «N раз в день» — заменить общую на повидовую. UI и так
   показывает повидовую (data_load_service.dart:543), но общее поле
   больше не противоречит собственной видовой записи.

Запуск:  python3 scripts/fix_drugs_calc_2026-11-02.py [--dry-run]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'assets' / 'data' / 'drugs_calc.json'

DRY_RUN = '--dry-run' in sys.argv

PCT_RE = re.compile(r'(\d+(?:[.,]\d+)?)\s*%')
LIQUID_FORMS = {'injection', 'solution', 'oral_solution', 'oral'}
TOPICAL_FORMS = {'topical', 'external', 'other'}
FREQ_PER_DAY_RE = re.compile(r'(\d+)\s*раз[а]?\s*в\s*(?:день|сутки)', re.I)
FREQ_HOURS_RE = re.compile(r'(\d+)\s*час', re.I)

CHANGES: list[str] = []
SKIPS: list[str] = []


def change(drug_id, name, where, old, new) -> None:
    CHANGES.append(f'#{drug_id} {name}: {where}: {old!r} → {new!r}')


def skip(drug_id, name, why: str) -> None:
    SKIPS.append(f'#{drug_id} {name}: {why}')


def pcts_from_name(name: str) -> list[float]:
    vals = []
    for m in PCT_RE.findall(name or ''):
        try:
            vals.append(float(m.replace(',', '.')))
        except ValueError:
            pass
    return sorted(set(vals))


def conc_variants(pcts: list[float]) -> list[dict]:
    out = []
    for p in pcts:
        label = f'{p}'.rstrip('0').rstrip('.').replace('.', ',')
        out.append({'label': f'{label}%', 'concentration': round(p * 10, 4)})
    return out


def norm_freq(s) -> str:
    return re.sub(r'\s+', ' ', str(s or '')).strip().lower()


def main() -> int:
    data = json.loads(DB.read_text(encoding='utf-8'))
    drugs = data['drugs_calc']

    for x in drugs:
        did = x.get('id')
        name = x.get('name', '')
        ftype = x.get('form_type', '')
        conc = x.get('concentration')
        conc_num = conc if isinstance(conc, (int, float)) else None

        # ── A. Мультиконц-варианты ───────────────────────────────────
        pcts = pcts_from_name(name)
        if len(pcts) >= 2 and ftype in LIQUID_FORMS:
            variants = conc_variants(pcts)
            vconc = [v['concentration'] for v in variants]
            if x.get('concentration_variants') != variants:
                old_variants = x.get('concentration_variants')
                x['concentration_variants'] = variants
                change(did, name, 'concentration_variants',
                       old_variants, variants)
            if conc_num is None or conc_num not in vconc:
                new_default = vconc[0]
                change(did, name, 'concentration', conc, new_default)
                x['concentration'] = new_default

        # ── B. Одна % ≠ %×10 ─────────────────────────────────────────
        elif len(pcts) == 1 and ftype in LIQUID_FORMS and conc_num:
            expect = round(pcts[0] * 10, 4)
            if abs(conc_num - expect) / expect > 0.15:
                change(did, name, 'concentration', conc, expect)
                x['concentration'] = expect
            elif conc_num == expect:
                pass

        # ── C. Топикалы-мусор ────────────────────────────────────────
        if ftype in TOPICAL_FORMS and isinstance(conc, str):
            cleaned = re.sub(r'[\s\u00A0]', '', conc)
            if not re.fullmatch(r'\d+(?:[.,]\d+)?', cleaned):
                change(did, name, 'concentration', conc, None)
                x['concentration'] = None

        # ── D. LA-гигиена общей frequency ────────────────────────────
        freq = x.get('frequency') or ''
        if FREQ_PER_DAY_RE.search(freq):
            as_ = x.get('animal_specific')
            animals_list = x.get('animals') or []
            if isinstance(as_, dict) and as_ and \
                    set(animals_list) <= set(as_.keys()):
                sp_freqs = set()
                for val in as_.values():
                    if isinstance(val, dict):
                        sp_freqs.add(norm_freq(val.get('frequency')))
                    else:
                        sp_freqs.add('')
                if '' not in sp_freqs and len(sp_freqs) == 1:
                    sp_freq = next(iter(sp_freqs))
                    hm = FREQ_HOURS_RE.search(sp_freq)
                    is_la = (hm and int(hm.group(1)) >= 36) or 'однократно' in sp_freq
                    if is_la and norm_freq(freq) != sp_freq:
                        # человеческая форма повидовой записи:
                        pretty = next(
                            v.get('frequency') for v in as_.values()
                            if isinstance(v, dict))
                        change(did, name, 'frequency', freq, pretty)
                        x['frequency'] = pretty

    print('\n'.join(CHANGES))
    if SKIPS:
        print('\n'.join(SKIPS))
    print(f'\nитого правок: {len(CHANGES)}')

    if DRY_RUN:
        print('DRY RUN — файл не записан')
        return 0

    DB.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                  encoding='utf-8')
    print(f'Записано: {DB}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
