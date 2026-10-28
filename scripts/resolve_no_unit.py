#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
resolve_no_unit.py — Task 187: масс-фикс no-unit WARN-эшелона (4147 записей).

Контекст: WARN-эшелон валидатора (Task 185/186): ERROR=0, WARN=4346, из них
4147 — «доза N без dose_unit». Разведка показала:
  • приложение (AnimalSpecificDose.fromJson) ДЕФОЛТИТ unit -> 'мг/кг',
    т.е. semantics уже mg/kg — юнит надо просто сделать явным;
  • drug-level dose_unit есть и валиден у 651/651 (CALC) и 647/653 (VER)
    no-unit препаратов — наследование = та же семантика, что и база;
  • 6 VER-препаратов без drug-level юнита (цефтиофур/энрофлоксацин/...) —
    закрываются кросс-файлом (одноимённая CALC-запись);
  • bleed-филлеры конверсии: записи «наружно (купка/спрей)»/«наружно (спрей)»
    с dose=10 (5–15) — на шампунях/ошейниках/спот-онах для собак и кошек
    стоит вид «КРС»: мусор xlsx-строки (урок Task 186 — bleed приходит
    блоками). Сносим запись целиком.

Правила:
  R0  снос bleed-филлера: method 'наружно (купка/спрей)'/'наружно (спрей)'
      И dose_per_kg==10 И (dose_min в {5,None} И dose_max в {15,None})
  R1  наследование drug-level dose_unit (валидные per-kg юниты)
  R2  кросс-файл: drug-level юнит одноимённого препарата из другого файла
  R3  остаток — печатается (решается вручную, не угадыванием)

Сериализация: json.dumps(indent=2, ensure_ascii=False) + '\n' — round-trip
байт-в-байт с текущими файлами (проверено).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

VALID_UNITS = {'мг/кг', 'мкг/кг', 'МЕ/кг', 'мл/кг', 'мг/кг массы', 'мг/кг корма'}


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n',
                    encoding='utf-8')


def is_nou(rec):
    """Числовая доза без юнита."""
    return (isinstance(rec, dict)
            and rec.get('dose_unit') in (None, '')
            and isinstance(rec.get('dose_per_kg'), (int, float))
            and not isinstance(rec.get('dose_per_kg'), bool)
            and rec.get('dose_per_kg') != 0)


def is_filler(rec):
    """Bleed-филлер наружных форм: доза 10 (5–15), метод купки/спрея."""
    if not isinstance(rec, dict):
        return False
    m = str(rec.get('method') or '')
    if m not in ('наружно (купка/спрей)', 'наружно (спрей)'):
        return False
    d = rec.get('dose_per_kg')
    if d not in (10, 10.0):
        return False
    dmin, dmax = rec.get('dose_min'), rec.get('dose_max')
    return dmin in (5, 5.0, None) and dmax in (15, 15.0, None)


def main():
    dc = load(DATA / 'drugs_calc.json')
    vd = load(DATA / 'verified_dosages.json')
    dc_drugs = {d['name']: d for d in dc['drugs_calc']}
    vd_drugs = {k: v for k, v in vd.items() if k != '_meta'}

    log = []
    r0 = r1 = r2 = 0
    r0_list = []

    # Task 187 раунд 2: обрабатываем СПИСОК (дубликаты имён — 21 препарат
    # имеют 2-3 одноимённые записи; словарь глотал все кроме последней,
    # 19 no-unit оставались в невидимых дублях).

    # ── R0: снос bleed-филлеров ──────────────────────────────────────────
    for label, drugs in (('drugs_calc.json', [d for d in dc['drugs_calc']]),
                         ('verified_dosages.json', list(vd_drugs.values()))):
        for d in drugs:
            asp = d.get('animal_specific')
            if not isinstance(asp, dict):
                continue
            for sp in list(asp.keys()):
                if is_filler(asp[sp]):
                    r0_list.append(f'{label} · {d.get("name")} · {sp}')
                    del asp[sp]
                    r0 += 1
    log.append(f'R0 bleed-филлеры снесено: {r0}')

    # ── R1: наследование drug-level юнита ───────────────────────────────
    for label, drugs in (('drugs_calc.json', [d for d in dc['drugs_calc']]),
                         ('verified_dosages.json', list(vd_drugs.values()))):
        for d in drugs:
            u = d.get('dose_unit')
            if u not in VALID_UNITS:
                continue
            for sp, rec in (d.get('animal_specific') or {}).items():
                if isinstance(rec, dict) and is_nou(rec):
                    rec['dose_unit'] = u
                    r1 += 1
    log.append(f'R1 унаследовано от drug-level: {r1}')

    # ── R2: кросс-файл ───────────────────────────────────────────────────
    for drugs_list, other in (([d for d in dc['drugs_calc']], vd_drugs),
                              (list(vd_drugs.values()), dc_drugs)):
        for d in drugs_list:
            u = (other.get(d.get('name')) or {}).get('dose_unit')
            if u not in VALID_UNITS:
                continue
            for sp, rec in (d.get('animal_specific') or {}).items():
                if isinstance(rec, dict) and is_nou(rec):
                    rec['dose_unit'] = u
                    r2 += 1
    # ── R2b: INN-консенсус из CALC (для verified-антибиотиков без пары) ───
    inn_unit = {}
    for d in dc['drugs_calc']:
        u = d.get('dose_unit')
        if u in VALID_UNITS and d.get('inn'):
            inn_unit.setdefault(d['inn'], set()).add(u)
    for d in list(vd_drugs.values()):
        inn = d.get('inn')
        us = inn_unit.get(inn, set()) if inn else set()
        if len(us) != 1:
            continue
        u = next(iter(us))
        for sp, rec in (d.get('animal_specific') or {}).items():
            if isinstance(rec, dict) and is_nou(rec):
                rec['dose_unit'] = u
                r2 += 1
    log.append(f'R2+R2b добрано кросс-файлом/INN: {r2}')

    # ── R3: остаток ──────────────────────────────────────────────────────
    left = []
    for label, drugs_list in (('drugs_calc.json', dc['drugs_calc']),
                              ('verified_dosages.json', list(vd_drugs.values()))):
        for d in drugs_list:
            for sp, rec in (d.get('animal_specific') or {}).items():
                if isinstance(rec, dict) and is_nou(rec):
                    left.append(f'{label} · {d.get("name")} · {sp} · dose={rec.get("dose_per_kg")} '
                                f'method={rec.get("method")!r}')
    log.append(f'R3 остаток no-unit: {len(left)}')
    for line in left:
        log.append(f'  R3: {line}')

    dump(DATA / 'drugs_calc.json', dc)
    dump(DATA / 'verified_dosages.json', vd)

    print('\n'.join(log))
    print(f'\nИТОГО: R0={r0} R1={r1} R2={r2} остаток={len(left)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
