#!/usr/bin/env python3
"""Гейт WHO MIA (идея №4 vet-digital-ideas: stewardship-гейт антибиотиков).

Проверяет и генерирует слой «Медицински важные антимикробные» (WHO MIA 2024)
поверх базы ветвойс:

  1. Структура mia_classes.json: категории с рангами, классы с уникальными
     id, компоненты ссылаются на существующие классы.
  2. Сверка с официальным списком ВОЗ (фикстура ниже — дословная выжимка
     таблиц 1-4 WHO MIA List 2024): каждый класс обязан иметь официальную
     категорию; дрейф таблицы = красный.
  3. Резолюция всех препаратов базы: разбор INN на компоненты → классы MIA
     и/или явные out_of_scope.
  4. Покрытие: у КАЖДОГО препарата категории «Антибактериальные» есть хотя бы
     один класс MIA или явная out_of_scope-запись — иначе красный.
     Препараты других категорий решаются опционально (плашка появится, если
     компоненты нашлись: Стоморджил = спирамицин, Левомеколь = левомицетин).
  5. Гигиена карты: каждый ключ components/out_of_scope используется хоть
     одним препаратом базы (ловит опечатки и выдуманные компоненты).
  6. Дрейф mia_drugs.json: пересчёт и побайтовое сравнение (без метки времени
     в payload). --write — регенерация.

Запуск: python3 scripts/mia_gate.py [--write]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIA = ROOT / 'assets' / 'data' / 'mia_classes.json'
DRUGS = ROOT / 'assets' / 'data' / 'drugs_calc.json'
OUT = ROOT / 'assets' / 'data' / 'mia_drugs.json'

# --- Фикстура: официальные категории WHO MIA List 2024 (ISBN 978-92-4-008461-2)
# Таблица 3 (разрешены и людям, и животным), таблица 4 (не разрешены у людей),
# таблица 2 (только у людей — единственный нужный нам класс).
# Источник верифицирован 2026-10-31 по официальному PDF ВОЗ.
OFFICIAL_WHO_2024 = {
    # HPCIA — наивысший приоритет критически важных
    'Quinolones': 'hp',
    'Cephalosporins (3rd, 4th generation)': 'hp',
    'Polymyxins': 'hp',
    'Phosphonic acid derivatives': 'hp',
    # CIA — критически важные
    'Aminoglycosides': 'cia',
    'Ansamycins': 'cia',
    'Macrolides (14-, 15-, 16-membered ring)': 'cia',
    # HIA — высоковажные
    'Amphenicols': 'hia',
    'Cephalosporins (1st and 2nd generation) and cephamycins': 'hia',
    'Lincosamides': 'hia',
    'Nitroimidazoles': 'hia',
    'Tetracyclines': 'hia',
    'Penicillins (narrow spectrum)': 'hia',
    'Penicillins (amidinopenicillins and aminopenicillins)': 'hia',
    'Penicillins (aminopenicillins with β-lactamase inhibitors)': 'hia',
    'Penicillins (anti-staphylococcal)': 'hia',
    'Streptogramins': 'hia',
    'Sulfonamides, dihydrofolate reductase inhibitors and combinations': 'hia',
    'Fusidanes': 'hia',
    # IA — важные
    'Aminocyclitols': 'ia',
    'Cyclic polypeptides': 'ia',
    'Heterocyclic compounds': 'ia',
    'Nitrofuran derivatives': 'ia',
    'Pleuromutilins': 'ia',
    # Не разрешены у людей (таблица 4)
    'Aminocoumarins': 'nmi',
    'Arsenicals': 'nmi',
    'Bicyclomycins': 'nmi',
    'Halogenated 8-hydroxyquinolines': 'nmi',
    'Ionophores (including polyethers)': 'nmi',
    'Orthosomycins': 'nmi',
    'Phosphoglycolipids': 'nmi',
    'Quinoxalines': 'nmi',
    # Только у людей (таблица 2)
    '8-Hydroxy-5-nitroquinolines': 'humans_only',
}

VALID_CATEGORIES = {'humans_only', 'hp', 'cia', 'hia', 'ia', 'nmi'}


def parse_components(inn: str):
    """Разбор INN на нормализованные компоненты (полная и безскобочная форма)."""
    s = inn.lower().strip().replace('+', ',')
    tokens = re.split(r'[,\n]| и ', s)
    out = []
    for tok in tokens:
        t = tok.strip(' .;')
        t = re.sub(r'\s+', ' ', t)
        if not t:
            continue
        t_noparen = re.sub(r'\s*\([^)]*\)', '', t).strip()
        out.append((t, t_noparen))
    return out


def resolve_drug(inn: str, components: dict, out_of_scope: dict):
    """Возвращает (классы, out_of_scope-причины, unmapped-компоненты)."""
    classes, outs, unmapped = [], [], []
    seen = set()
    for full, noparen in parse_components(inn):
        for form in (full, noparen):
            if form in components:
                cid = components[form]
                if cid not in seen:
                    seen.add(cid)
                    classes.append(cid)
                break
        else:
            for form in (full, noparen):
                if form in out_of_scope:
                    if out_of_scope[form] not in outs:
                        outs.append(out_of_scope[form])
                    break
            else:
                unmapped.append(full)
    return classes, outs, unmapped


def main():
    write = '--write' in sys.argv
    errors, warnings = [], []

    mia = json.loads(MIA.read_text(encoding='utf-8'))
    drugs = json.loads(DRUGS.read_text(encoding='utf-8'))['drugs_calc']

    # --- 1. Структура ---
    cats = mia.get('categories', {})
    ranks = {}
    for cid, c in cats.items():
        if cid not in VALID_CATEGORIES | {'out'}:
            errors.append(f'категория {cid} вне допустимого набора')
        r = c.get('rank')
        if not isinstance(r, int):
            errors.append(f'категория {cid}: rank не int')
        if cid in ranks:
            errors.append(f'дубль ранга {r}')
        ranks[cid] = r
    for need in ('hp', 'cia', 'hia', 'ia', 'nmi'):
        if need not in cats:
            errors.append(f'нет категории {need}')

    classes = mia.get('classes', [])
    by_id = {}
    for c in classes:
        cid = c.get('id')
        if cid in by_id:
            errors.append(f'дубль класса {cid}')
        by_id[cid] = c
        cat = c.get('category')
        if cat not in VALID_CATEGORIES:
            errors.append(f'класс {cid}: категория {cat!r} не официальная')
        for f in ('name', 'name_en', 'stewardship'):
            if not c.get(f):
                errors.append(f'класс {cid}: пустое поле {f}')

    comp_map = mia.get('components', {})
    oos_map = mia.get('out_of_scope', {})
    for k, v in comp_map.items():
        if v not in by_id:
            errors.append(f'компонент {k!r} → несуществующий класс {v!r}')
    for k, v in oos_map.items():
        if not v:
            errors.append(f'out_of_scope {k!r}: пустая причина')

    # --- 2. Сверка с официальным списком ВОЗ 2024 ---
    ours = {c['name_en']: c['category'] for c in classes}
    for official_name, official_cat in OFFICIAL_WHO_2024.items():
        if official_name not in ours:
            errors.append(f'официальный класс ВОЗ отсутствует: {official_name}')
        elif ours[official_name] != official_cat:
            errors.append(
                f'дрейф категории {official_name}: '
                f'у нас {ours[official_name]}, официально {official_cat}')
    for name in ours:
        if name not in OFFICIAL_WHO_2024:
            errors.append(f'класс {name!r} отсутствует в официальном списке ВОЗ')

    # --- 3-4. Резолюция и покрытие ---
    resolved = {}
    used_components = set()
    used_oos = set()
    failures = []
    antibacterial = 0
    for d in drugs:
        inn = d.get('inn', '')
        classes_found, outs_found, unmapped = resolve_drug(inn, comp_map, oos_map)
        entry = {}
        if classes_found:
            entry['c'] = classes_found
        if outs_found:
            entry['o'] = outs_found
        if entry:
            resolved[str(d['id'])] = entry
        if d.get('category') == 'Антибактериальные':
            antibacterial += 1
            if not classes_found and not outs_found:
                failures.append((d['name'], inn, unmapped))
        # учёт использованных ключей
        for full, noparen in parse_components(inn):
            for form in (full, noparen):
                if form in comp_map:
                    used_components.add(form)
                    break
                if form in oos_map:
                    used_oos.add(form)
                    break

    if failures:
        print(f'ПОКРЫТИЕ: {len(failures)} антибактериальных без класса MIA:')
        for name, inn, unm in failures[:20]:
            print(f'  - {name} | inn={inn} | нераспознано: {unm}')
        errors.append(f'покрытие MIA: {len(failures)} препаратов без класса')

    # --- 5. Гигиена карты ---
    dead = sorted(set(comp_map) - used_components)
    if dead:
        print('Неиспользуемые ключи components (опечатки?):')
        for k in dead:
            print(f'  - {k!r}')
        errors.append(f'{len(dead)} неиспользуемых компонентов в карте')
    dead_oos = sorted(set(oos_map) - used_oos)
    if dead_oos:
        print('Неиспользуемые ключи out_of_scope:')
        for k in dead_oos:
            print(f'  - {k!r}')
        warnings.append(f'{len(dead_oos)} неиспользуемых out_of_scope')

    # --- 6. mia_drugs.json: генерация/сверка ---
    payload = {
        'version': mia.get('version'),
        'db_version': json.loads(DRUGS.read_text(encoding='utf-8')).get('version'),
        'source': 'WHO List of Medically Important Antimicrobials, 2024',
        'generated_by': 'scripts/mia_gate.py',
        'drugs': dict(sorted(resolved.items(), key=lambda kv: int(kv[0]))),
    }
    if write:
        OUT.write_text(
            json.dumps(payload, ensure_ascii=False, indent=1) + '\n',
            encoding='utf-8')
        print(f'записан {OUT.name}: {len(resolved)} препаратов с MIA-решением')

    if OUT.exists():
        current = json.loads(OUT.read_text(encoding='utf-8'))
        if current.get('drugs') != payload['drugs']:
            diff_add = set(payload['drugs']) - set(current.get('drugs', {}))
            diff_del = set(current.get('drugs', {})) - set(payload['drugs'])
            diff_mod = [k for k in set(payload['drugs']) & set(current.get('drugs', {}))
                        if payload['drugs'][k] != current['drugs'][k]]
            print(f'ДРЕЙФ mia_drugs.json: +{len(diff_add)} -{len(diff_del)} ~{len(diff_mod)}')
            for k in list(diff_add)[:5]:
                print(f'  + id={k}')
            for k in list(diff_del)[:5]:
                print(f'  - id={k}')
            for k in diff_mod[:5]:
                print(f'  ~ id={k}: {current["drugs"][k]} → {payload["drugs"][k]}')
            errors.append(
                'mia_drugs.json не соответствует базе — прогоните '
                '`python3 scripts/mia_gate.py --write` и закоммитьте')
        if current.get('db_version') != payload['db_version']:
            errors.append('mia_drugs.json собран из другой версии drugs_calc.json')
    else:
        errors.append('mia_drugs.json отсутствует — прогоните с --write')

    # --- Итог ---
    total = len(drugs)
    n_ab_resolved = sum(
        1 for d in drugs if d.get('category') == 'Антибактериальные'
        and str(d['id']) in resolved)
    print(f'MIA-слой: {len(resolved)}/{total} препаратов базы решено '
          f'(антибактериальные: {n_ab_resolved}/{antibacterial})')
    cat_counts = {}
    for e in resolved.values():
        for c in e.get('c', []):
            cat = by_id[c]['category']
            cat_counts[cat] = cat_counts.get(cat, 0) + 1
    for cat in ('humans_only', 'hp', 'cia', 'hia', 'ia', 'nmi'):
        print(f'  {cat}: {cat_counts.get(cat, 0)} препаратов')

    if errors:
        print(f'\nКРАСНЫЙ: {len(errors)} ошибок')
        for e in errors:
            print(f'  ! {e}')
        sys.exit(1)
    if warnings:
        for w in warnings:
            print(f'  ⚠ {w}')
    print('\nЗЕЛЁНЫЙ: структура, сверка с ВОЗ 2024, покрытие и генерация — ок')


if __name__ == '__main__':
    main()
