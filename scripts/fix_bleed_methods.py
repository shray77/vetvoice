#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_bleed_methods.py — Task 187 раунд 2: bleed-методы на неинъекционных формах.

Контекст: после unit-изации (resolve_no_unit.py) объёмный гейт увидел записи,
которые прежде были невидимы (юнита не было — объём не считался): 158 volume
WARN. Разбор показал класс «bleed-метод»: у оральных/наружных препаратов
(Синулокс — таблетки!, ИРИС капли глазные, мазь тетрациклиновая...) в
animal_specific стоят чужие строки конверсии с инъекционными методами
(«внутримышечно / подкожно», dose 15 [10-20] — след амоксициллиновых
инъекционных продуктов). Идентичная сигнатура мусора у:

  M1 — невидимые записи: вид отсутствует в массиве animals (UI его не
       предлагает — isForAnimal фильтрует по animals) И метод инъекционный
       И форма препарата точно неинъекционная → снос записи;
  M2 — видимые записи: вид в animals, но метод инъекционный при точно
       неинъекционной форме → метод := drug-level метод (fallback «внутрь»).

«Точно неинъекционная» — позитивный тест: form_type в {tablet, powder,
external, oral, other, topical, spray, drops, capsule} (CALC) или форма
содержит явное неинъекционное слово (таблетки/капли/мазь/наружн/ушн/глазн/
ошейник/спрей/пудра/...). Неизвестная форма (None без формы) — НЕ трогаем:
отсутствие информации не повод чинить методы (цефтиофур-инъекции в VER
без form-поля должны остаться «Подкожно или внутримышечно»).

Слепой снос невидимых записей НЕ выполняем: Мариния (animals=['Собаки'],
Кошки — верная маропитантная доза) — лакуна animals-массива, не мусор;
решение о расширении animals — за владельцем.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

INJ_TOKENS = ('внутримышечн', 'подкожн', 'в/м', 'п/к', 'в/в', 'в/к',
              'инъекц', 'внутривен', 'эпидураль', 'внутрикостн')

NONINJ_FORM_TYPE = {'tablet', 'powder', 'external', 'oral', 'other',
                    'topical', 'spray', 'drops', 'capsule'}
NONINJ_FORM_WORDS = (
    'таблетк', 'капсул', 'мазь', 'гель', 'крем', 'капли', 'пудра', 'паста',
    'болюс', 'ошейник', 'шампунь', 'спрей', 'аурикулярн', 'глазн', 'ушн',
    'наружного применения', 'наружные', 'для приема внутрь', 'для приёма внутрь',
    'пероральн', 'кормов', 'премикс', 'питьев',
    # Task 187 раунд 3: оральные формы и спец-пути (были пропущены —
    # «Раствор/Порошок/Гранулы для орального применения» с в/м методами,
    # внутриматочные/внутривыменные растворы с «Инъекционно»)
    'порошок', 'орального применения', 'гранул', 'для выпаивания',
    'внутриматочн', 'интрацистернальн', 'внутривыменн', 'интрамаммарн',
)

# Fallback-метод по форме: спец-пути ввода не становятся «внутрь»
SPECIAL_ROUTE_WORDS = (
    ('внутриматочн', 'внутриматочно'),
    ('интрацистернальн', 'внутривыменное введение'),
    ('внутривыменн', 'внутривыменное введение'),
    ('интрамаммарн', 'внутривыменное введение'),
)
EXTERNAL_FORM_WORDS = ('наружного применения', 'наружные', 'мазь', 'спрей',
                        'шампунь', 'ошейник', 'гель', 'крем', 'пудра',
                        'аурикулярн', 'глазн', 'ушн', 'капли')


def has_inj_method(m):
    m = str(m or '').lower()
    return any(t in m for t in INJ_TOKENS)


def surely_not_injectable(d):
    """Позитивный тест «форма точно не инъекционная»."""
    ft = d.get('form_type')
    if ft == 'injection' or ft == 'vaccine' or ft == 'suspension':
        return False
    if ft in NONINJ_FORM_TYPE:
        return True
    form = str(d.get('form') or '').lower()
    if not form:
        return False
    if 'инъекц' in form or 'инфуз' in form:
        return False
    return any(w in form for w in NONINJ_FORM_WORDS)


def route_method_for_form(form_l):
    """Метод по неинъекционной форме: спец-пути -> своё, наружные -> наружно,
    остальное -> внутрь."""
    for word, method in SPECIAL_ROUTE_WORDS:
        if word in form_l:
            return method
    if any(w in form_l for w in EXTERNAL_FORM_WORDS):
        return 'наружно'
    return 'внутрь'


def main():
    dc_path = DATA / 'drugs_calc.json'
    vd_path = DATA / 'verified_dosages.json'
    dc = json.loads(dc_path.read_text(encoding='utf-8'))
    vd = json.loads(vd_path.read_text(encoding='utf-8'))
    vd_records = [v for k, v in vd.items() if not k.startswith('_')]

    ops = []

    # ── M1: невидимые bleed-записи ───────────────────────────────────────
    m1 = 0
    for label, records in (('CALC', dc['drugs_calc']), ('VER', vd_records)):
        for d in records:
            animals = d.get('animals')
            if not isinstance(animals, list) or not animals:
                continue  # animals-массив — источник правды UI; пусто = не лезем
            if not surely_not_injectable(d):
                continue
            asp = d.get('animal_specific')
            if not isinstance(asp, dict):
                continue
            st = set(animals)
            for sp in list(asp.keys()):
                rec = asp[sp]
                if not isinstance(rec, dict):
                    continue
                if sp in st:
                    continue
                if has_inj_method(rec.get('method')):
                    del asp[sp]
                    m1 += 1
                    ops.append(f'M1 {label} · {d.get("name") or "?"}: снос невидимого bleed [{sp}] '
                               f'(метод {str(rec.get("method"))!r} на форме {str(d.get("form"))!r})')

    # ── M2: видимые записи с инъекционным методом ────────────────────────
    m2 = 0
    for label, records in (('CALC', dc['drugs_calc']), ('VER', vd_records)):
        for d in records:
            animals = d.get('animals')
            if not isinstance(animals, list) or not animals:
                continue
            if not surely_not_injectable(d):
                continue
            asp = d.get('animal_specific')
            if not isinstance(asp, dict):
                continue
            st = set(animals)
            form_l = str(d.get('form') or '').lower()
            base_method = str(d.get('method') or '').strip()
            if has_inj_method(base_method):
                base_method = ''
            if not base_method:
                base_method = route_method_for_form(form_l)
            for sp, rec in asp.items():
                if not isinstance(rec, dict) or sp not in st:
                    continue
                old = rec.get('method')
                if has_inj_method(old):
                    rec['method'] = base_method
                    m2 += 1
                    ops.append(f'M2 {label} · {d.get("name")}[{sp}]: метод '
                               f'{str(old)!r} -> {base_method!r} (форма {str(d.get("form"))!r})')

    dc_path.write_text(json.dumps(dc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    vd_path.write_text(json.dumps(vd, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    for op in ops:
        print(' ✓', op)
    print(f'\nИТОГО: M1 (снос невидимых bleed)={m1}, M2 (метод-фикс)={m2}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
