#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Task 230 (2026-11-24): лимит веса Пчёл 5.0 → 15.0 кг (+10 кг).

Полевой контекст: вес обрабатываемой единицы на пасеке уходит за 5 кг,
validateWeight резал ввод «Слишком большой вес для Пчёлы! Максимум: 5 кг».
Идемпотентен: поднимает max_weight до 15.0 только если он ниже; повторный
запуск — no-op без записи. Дозы пчелопрепаратов в базе считаются на
легонькую единицу (мг/улей, мг/полоску, на соты) и весу не кратны — вес в
этой ветке служит только валидацией ввода, расчёт доз не затрагивается.
weight_hint «Вес улья: 20-100 кг» заменён на честный «до 15 кг»: hint
виден в UI рядом с вводом (home_screen) и противоречил лимиту — юзер
вводил 40 кг по подсказке и получал отказ.

Запуск: python3 scripts/fix_bee_weight_limit_2026-11-24.py [--dry-run]
(правка применена напрямую в коммите Task 230; валидатор — ERROR=0).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'assets' / 'data' / 'drugs_calc.json'
TARGET = 15.0  # 5.0 + 10

DRY_RUN = '--dry-run' in sys.argv


def main() -> int:
    data = json.loads(DB.read_text(encoding='utf-8'))
    bees = [a for a in data.get('animals', [])
            if 'пчел' in (a.get('name') or '').lower().replace('ё', 'е')]
    if not bees:
        print('ERROR: животное Пчёлы не найдено в animals')
        return 1

    changed = False
    for a in bees:
        old = a.get('max_weight')
        if old is None or float(old) < TARGET:
            a['max_weight'] = TARGET
            print(f"Пчёлы: max_weight {old} → {TARGET}")
            changed = True
        else:
            print(f"Пчёлы: max_weight уже {old} — no-op")
        # UX Task 230: hint не должен противоречить лимиту ввода
        new_hint = f'До {TARGET:g} кг; доза пчелопрепаратов от веса не зависит'
        if a.get('weight_hint') == 'Вес улья: 20-100 кг':
            a['weight_hint'] = new_hint
            print(f"Пчёлы: weight_hint → «{new_hint}»")
            changed = True

    if DRY_RUN or not changed:
        print('DRY RUN — файл не записан' if DRY_RUN else 'no-op — файл не записан')
        return 0

    DB.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                  encoding='utf-8')
    print(f'Записано: {DB}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
