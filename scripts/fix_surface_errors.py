#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_surface_errors.py — Task 187: фикс 14 ERROR, всплывших после
unit-изации no-unit-эшелона (resolve_no_unit.py).

Природа всех 14 — мусор xlsx-конверсии, класс «bleed» (урок Task 186:
bleed приходит блоками, лечится сносом блока):
  • невидимые виды: animal_specific-записи видов, которых НЕТ в массиве
    animals (UI их не показывает — калькулятор не достигает), но гейт
    видит; сносим запись;
  • видимая запись с мусорным методом («внутримышечно» на таблетках,
    «внутривенно» на ушных каплях) — метод выравнивается под форму;
  • Троксимелон[Кошки] — парацетамол-содержащий комбо, видовой запрет
    (как Бинакар Rus в Task 186): снос.

Каждая правка под assert-контролем: ожидали — не нашли = падаем, а не
молча портим.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

REMOVE = {
    'Троксимелон': ['Собаки', 'Кошки'],           # Кошки: парацетамол ban; Собаки: невидимый bleed
    'БАРС® капли ушные': ['Лошади'],              # ушные капли, лошадиной записи нет в animals
    'Отоферонол Премиум': ['Кошки', 'КРС', 'МРС', 'Лошади', 'Свиньи'],  # перметрин-капли для собак
    'Стоп-зуд® спрей': ['Лошади'],                # наружный спрей собак/кошек
    'Отибиовин': ['Кошки', 'КРС', 'Свиньи', 'Птица'],  # ушные капли (animals=['Собаки'])
    'ДИРОНЕТ® суспензия': ['КРС', 'МРС', 'Свиньи', 'Лошади'],  # суспензия для собак
    'Акаромектин': ['КРС', 'МРС', 'Свиньи', 'Лошади'],   # наружный 0.01% р-р, инъекц. дозы = bleed
    'Амоксиянтарь': ['Собаки', 'КРС', 'МРС', 'Лошади'],  # оральный порошок, в/м-строки невидимы
}

# препарат -> вид -> новый метод (мусорный метод на видимой записи)
FIX_METHOD = {
    'Амоксиянтарь': {'Свиньи': 'внутрь (с кормом)'},  # «Инъекционно» на ор. порошке
    'Антибак ПРО': {                                    # таблетки: в/м-методы — мусор
        'Собаки': 'внутрь',
        'Кошки': 'внутрь',
        'КРС': 'внутрь',
        'МРС': 'внутрь',
        'Свиньи': 'внутрь',
        'Лошади': 'внутрь',
    },
    'Отибиовин': {'Собаки': 'наружно'},  # «Инъекционно» на ушных каплях
}

# Отоферонол Премиум, CALC[Собаки]: «3 мг/кг внутривенно» на ушных каплях —
# мусор; зеркалим sane-запись VER (fixed/наружно).
OTOFERONOL_DOGS_CALC = {
    'dose_per_kg': 0.0, 'dose_min': 0.0, 'dose_max': 0.0,
    'dose_unit': 'fixed', 'method': 'наружно', 'notes': 'наружно',
}


def main():
    dc_path = DATA / 'drugs_calc.json'
    vd_path = DATA / 'verified_dosages.json'
    dc = json.loads(dc_path.read_text(encoding='utf-8'))
    vd = json.loads(vd_path.read_text(encoding='utf-8'))
    dc_drugs = {d['name']: d for d in dc['drugs_calc']}
    vd_drugs = {k: v for k, v in vd.items() if k != '_meta'}

    ops = []

    def get(drugs, name, must=True):
        d = drugs.get(name)
        if must and d is None:
            raise AssertionError(f'препарат не найден: {name}')
        return d

    # 1. Снос bleed-видов (проверяем: вида нет в animals — иначе стоп)
    for name, species_list in REMOVE.items():
        for label, drugs in (('CALC', dc_drugs), ('VER', vd_drugs)):
            d = get(drugs, name)
            animals = d.get('animals') or []
            asp = d.setdefault('animal_specific', {})
            for sp in species_list:
                if sp in animals:
                    raise AssertionError(
                        f'{label} {name}[{sp}]: вид в animals — снос запрещён, разбирай руками')
                if sp not in asp:
                    raise AssertionError(f'{label} {name}[{sp}]: записи нет — уже чинено?')
                del asp[sp]
                ops.append(f'{label} {name}: снос bleed [{sp}]')

    # 2. Метод-фиксы (проверяем: старый метод содержит инъекционный токен)
    INJ = ('внутримышечн', 'подкожн', 'в/м', 'п/к', 'в/в', 'инъекц', 'внутривен')
    for name, per_species in FIX_METHOD.items():
        for label, drugs in (('CALC', dc_drugs), ('VER', vd_drugs)):
            d = get(drugs, name)
            asp = d.setdefault('animal_specific', {})
            for sp, new_method in per_species.items():
                rec = asp.get(sp)
                if not isinstance(rec, dict):
                    raise AssertionError(f'{label} {name}[{sp}]: записи нет')
                old = str(rec.get('method') or '')
                if not any(t in old.lower() for t in INJ):
                    raise AssertionError(
                        f'{label} {name}[{sp}]: метод {old!r} не инъекционный — не трогаем')
                rec['method'] = new_method
                ops.append(f'{label} {name}[{sp}]: метод {old!r} -> {new_method!r}')

    # 3. Отибиовин Собаки: снос мусорного notes «Гентамагент» (в UI)
    for label, drugs in (('CALC', dc_drugs), ('VER', vd_drugs)):
        rec = get(drugs, 'Отибиовин')['animal_specific']['Собаки']
        if rec.get('notes') == 'Гентамагент':
            rec.pop('notes', None)
            ops.append(f'{label} Отибиовин[Собаки]: снос мусорного notes «Гентамагент»')

    # 4. Отоферонол Премиум CALC[Собаки] -> sane-запись (зеркало VER)
    rec = get(dc_drugs, 'Отоферонол Премиум')['animal_specific']['Собаки']
    ver_rec = get(vd_drugs, 'Отоферонол Премиум')['animal_specific']['Собаки']
    assert str(rec.get('method')).lower().startswith('внутривен'), \
        f'CALC Отоферонол[Собаки] метод неожидан: {rec.get("method")!r}'
    rec.clear()
    rec.update(OTOFERONOL_DOGS_CALC)
    ops.append('CALC Отоферонол Премиум[Собаки]: «3 мг/кг внутривенно» -> fixed/наружно (зеркало VER)')

    dc_path.write_text(json.dumps(dc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    vd_path.write_text(json.dumps(vd, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    for op in ops:
        print(' ✓', op)
    print(f'\nИТОГО операций: {len(ops)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
