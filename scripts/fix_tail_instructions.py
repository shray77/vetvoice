#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_tail_instructions.py — Task 187 раунд 3: хвост volume/no-conc/zero-dose
по данным официальных инструкций (веб-сверка 2026-10-29).

Источники: ultravet.ru/kzvt.ru (Элеовит), mistercoon/tsenovik (Гемобаланс),
a-bio.ru PDF Ферранимал-75М, agro-plus23/biohimfarm (гентамицин 4%),
academic.ru (Зинаприм inj 1 мл/10 кг), konovalsv/kzvt (Эроксимаст 5-10 мл
интрацистернально), dompitomci (Ампиклокс LC 1 шприц/12 ч), vidal/zoofarm
(Дюфалайт до 100 мл/50 кг в/в), zooapteka/kotofey (Катозал 10-25 мл КРС),
vetprod PDF (Зинаприм inj состав: сульфаметазин 200 + триметоприм 40 мг/мл).

Паттерны — как в Task 186: «на животное» = dose_unit fixed +
calculator_applicable=false (препарат уходит из калькулятора, переставая
рисовать мусорные объёмы; остаётся в реестре/справочнике).

Каждая правка под assert-контролем pre-состояния.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'


def load(p):
    return json.loads(p.read_text(encoding='utf-8'))


def dump(p, obj):
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n',
                 encoding='utf-8')


def set_fixed(drug, species, text):
    if drug.get('fixed_dose') is None:
        drug['fixed_dose'] = {}
    drug['fixed_dose'][species] = text


def nullify(rec, note=None):
    """Запись -> парадигма «на животное»: доза 0, юнит fixed."""
    rec['dose_per_kg'] = 0
    rec['dose_min'] = 0
    rec['dose_max'] = 0
    rec['dose_unit'] = 'fixed'
    if note:
        rec['notes'] = note


def main():
    dc_p, vd_p = DATA / 'drugs_calc.json', DATA / 'verified_dosages.json'
    dc, vd = load(dc_p), load(vd_p)
    ops = []

    def calc_recs(name):
        return [d for d in dc['drugs_calc'] if d.get('name') == name]

    def ver_rec(name):
        return vd.get(name)

    def one_calc(name):
        recs = calc_recs(name)
        assert len(recs) == 1, f'{name}: ожидалась 1 CALC-запись, найдено {len(recs)}'
        return recs[0]

    # ── 1. Элеовит: на животное, в/м (ultravet/kzvt) ─────────────────────
    for label, d in (('CALC', one_calc('Элеовит')), ('VER', ver_rec('Элеовит'))):
        if not d:
            continue
        asp = d['animal_specific']
        nullify(asp['КРС'], 'в/м; взрослое поголовье 5-6 мл, молодняк 2-3 мл')
        nullify(asp['Свиньи'], 'в/м; взрослые 2 мл, отъёмыши 1.5, сосуны 1, новорождённые 0.5 мл')
        for sp in ('Птица', 'Собаки'):
            if sp in asp:
                nullify(asp[sp], 'дозирование на животное по инструкции')
        d['calculator_applicable'] = False
        set_fixed(d, 'КРС', '5-6 мл в/м (молодняк 2-3 мл), 1 раз в 7-15 дней')
        set_fixed(d, 'Свиньи', '0.5-2 мл в/м по возрасту')
        ops.append(f'{label} Элеовит: парадигма «на животное» по инструкции (calc_applicable=false)')

    # ── 2. Гемобаланс: на животное по массе (mistercoon/tsenovik) ────────
    for label, d in (('CALC', one_calc('Гемобаланс')), ('VER', ver_rec('Гемобаланс'))):
        if not d:
            continue
        asp = d['animal_specific']
        for sp in ('Собаки', 'Кошки'):
            if sp in asp:
                nullify(asp[sp], 'в/м, в/в или п/к 2-3 р/нед; <5 кг — 0.25 мл, 5-15 кг — 0.5 мл, >15 кг — 1 мл')
        d['calculator_applicable'] = False
        set_fixed(d, 'Собаки', '0.25-1 мл по массе (<5 кг: 0.25; 5-15: 0.5; >15: 1), 2-3 р/нед')
        set_fixed(d, 'Кошки', '0.25-0.5 мл по массе (<5 кг: 0.25; 5-15: 0.5), 2-3 р/нед')
        ops.append(f'{label} Гемобаланс: парадигма «на животное» по массе')

    # ── 3. Ферранимал-75: поросятам 0.7-2 мл (a-bio PDF) ─────────────────
    for label, d in (('CALC', one_calc('Ферранимал-75')), ('VER', ver_rec('Ферранимал-75'))):
        if not d:
            continue
        nullify(d['animal_specific']['Свиньи'],
                'поросятам 0.7-2 мл в/м однократно на 2-4 день жизни (50-150 мг железа)')
        d['calculator_applicable'] = False
        set_fixed(d, 'Свиньи', '0.7-2 мл поросёнку в/м однократно (50-150 мг железа)')
        ops.append(f'{label} Ферранимал-75: поросятам 0.7-2 мл на животное')

    # ── 4. Кетотрит: кетопрофен КРС/Свиньи 3 мг/кг (было 10 — передоз) ───
    for label, d in (('CALC', one_calc('Кетотрит 2,5%, 10%')), ('VER', ver_rec('Кетотрит 2,5%, 10%'))):
        if not d:
            continue
        asp = d['animal_specific']
        for sp in ('КРС', 'Свиньи'):
            rec = asp[sp]
            assert rec.get('dose_per_kg') in (10, 10.0), f'Кетотрит {label}[{sp}]: {rec.get("dose_per_kg")}'
            rec['dose_per_kg'] = 3
            rec['dose_min'] = 2
            rec['dose_max'] = 4
            rec.pop('notes', None)
        asp.get('Лошади', {}).pop('notes', None)
        ops.append(f'{label} Кетотрит: КРС/Свиньи 10 -> 3 мг/кг (вет-стандарт кетопрофена)')

    # ── 5. Гентам®: моно-гентамицин 40 мг/мл, дозы 4% р-ра ───────────────
    for label, d in (('CALC', one_calc('Гентам®')), ('VER', ver_rec('Гентам®'))):
        if not d:
            continue
        assert 'гентамицин' in str(d.get('inn')), f'Гентам {label}: INN {d.get("inn")!r}'
        d['inn'] = 'гентамицин'
        asp = d['animal_specific']
        for sp, (dose, lo, hi) in {
            'КРС': (2.8, 2.5, 3.0), 'МРС': (2.8, 2.5, 3.0),
            'Свиньи': (4.0, 3.5, 4.5),
            'Собаки': (2.4, 2.0, 3.0), 'Кошки': (2.4, 2.0, 3.0), 'Лошади': (2.4, 2.0, 3.0),
        }.items():
            if sp not in asp:
                continue
            rec = asp[sp]
            assert rec.get('dose_per_kg') in (15, 15.0), f'Гентам {label}[{sp}]: {rec.get("dose_per_kg")}'
            rec['dose_per_kg'] = dose
            rec['dose_min'] = lo
            rec['dose_max'] = hi
            rec['frequency'] = '2 раза в сутки (интервал 10-12 ч)'
        ops.append(f'{label} Гентам®: INN -> гентамицин, дозы 2.4-4 мг/кг 2 р/сут (было 15 — передоз x4-6)')

    # ── 6. Зинаприм inj: 1 мл/10 кг в/м (academic.ru/vetprod) ────────────
    zin_calc = [d for d in calc_recs('Зинаприм') if d.get('form_type') == 'injection']
    zin_ver = ver_rec('Зинаприм')
    for d in zin_calc:
        rec = d['animal_specific']['КРС']
        assert rec.get('dose_per_kg') in (15, 15.0), f'Зинаприм inj КРС: {rec.get("dose_per_kg")}'
        rec['dose_per_kg'] = 0.1
        rec['dose_min'] = 0.1
        rec['dose_max'] = 0.1
        rec['dose_unit'] = 'мл/кг'
        rec['method'] = 'внутримышечно'
        rec['frequency'] = '1 раз в сутки, 3-5 дней (начало — дважды с интервалом 12 ч)'
        rec['notes'] = '1 мл на 10 кг массы'
        ops.append('CALC Зинаприм (инъекц.): 15 мг/кг -> 1 мл/10 кг (0.1 мл/кг) по инструкции')
    if zin_ver is not None and 'инъекц' in str(zin_ver.get('form') or '').lower():
        rec = zin_ver['animal_specific']['КРС']
        if rec.get('dose_per_kg') in (15, 15.0):
            rec.update({'dose_per_kg': 0.1, 'dose_min': 0.1, 'dose_max': 0.1,
                        'dose_unit': 'мл/кг', 'method': 'внутримышечно',
                        'frequency': '1 раз в сутки, 3-5 дней',
                        'notes': '1 мл на 10 кг массы'})
            ops.append('VER Зинаприм (инъекц.): 15 мг/кг -> 0.1 мл/кг по инструкции')
        if zin_ver.get('concentration') in (40, 40.0):
            zin_ver['concentration'] = 200
            zin_ver['concentration_unit'] = 'мг/мл'
            ops.append('VER Зинаприм: conc 40 -> 200 мг/мл (сульфаметазин, согласовано CALC)')

    # ── 7. Маститные шприцы: интрацистернально, калькулятор неприменим ────
    MASTIT = {
        'Эроксимаст': 'по 5 мл в поражённую долю 1 раз в сутки 3-4 дня (гнойный мастит: первая доза 10 мл)',
        'Ампиклокс LC': 'по 1 шприцу в поражённую долю каждые 12 часов, курс 3 введения',
        'Боваклокс DC': 'по 1 шприцу в поражённую долю по инструкции (интрадуктально)',
        'Мастинол-форте': 'по инструкции препарата (внутривыменно)',
    }
    for name, text in MASTIT.items():
        for d in calc_recs(name):
            d['calculator_applicable'] = False
            set_fixed(d, 'КРС', text)
            rec = d.get('animal_specific', {}).get('КРС')
            if isinstance(rec, dict) and rec.get('dose_unit') != 'fixed':
                nullify(rec, 'интрацистернально (в сосковый канал)')
            ops.append(f'CALC {name}: интрацистернальная парадигма, calc_applicable=false')
        v = ver_rec(name)
        if v is not None:
            rec = v.get('animal_specific', {}).get('КРС')
            if isinstance(rec, dict) and rec.get('dose_unit') != 'fixed':
                nullify(rec, 'интрацистернально (в сосковый канал)')
                ops.append(f'VER {name}: запись КРС -> fixed/интрацистернально')

    # ── 8. Дюфалайт: инфузат до 100 мл/50 кг в/в (vidal/zoofarm) ──────────
    for label, d in (('CALC', one_calc('Дюфалайт')), ('VER', ver_rec('Дюфалайт'))):
        if not d:
            continue
        d['calculator_applicable'] = False
        set_fixed(d, 'КРС', 'до 100 мл на 50 кг массы в/в медленно (телятам до 30 мл на 5 кг)')
        set_fixed(d, 'Свиньи', 'до 100 мл на 50 кг массы в/в медленно')
        set_fixed(d, 'Собаки', 'до 50 мл на 5 кг массы в/в медленно')
        set_fixed(d, 'Птица', 'по инструкции')
        asp = d.get('animal_specific') or {}
        for sp, rec in asp.items():
            if isinstance(rec, dict):
                nullify(rec, 'инфузия в/в медленно: КРС/свиньи/лошади до 100 мл на 50 кг; телята/поросята до 30 мл на 5 кг')
        ops.append(f'{label} Дюфалайт: инфузионная парадигма «до 100 мл/50 кг в/в»')

    # ── 9. Катозал®: бутафосфан 100 мг/мл, на животное (zooapteka) ────────
    kat = next((d for d in calc_recs('Катозал®')), None)
    if kat is not None:
        kat['concentration'] = 100
        kat['concentration_unit'] = 'мг/мл'
        kat['calculator_applicable'] = False
        for sp, text in {
            'КРС': '10-25 мл в/м, п/к или в/в 1 р/сут 4-5 дней',
            'Лошади': '10-25 мл в/м, п/к или в/в 1 р/сут 4-5 дней',
            'Собаки': '2.5-5 мл в/м, п/к или в/в 1 р/сут 4-5 дней',
            'Кошки': '0.5-2.5 мл в/м, п/к или в/в 1 р/сут 4-5 дней',
            'Птица': 'цыплятам 1-1.5 мл на 1 л питьевой воды',
        }.items():
            set_fixed(kat, sp, text)
            rec = kat.get('animal_specific', {}).get(sp)
            if isinstance(rec, dict):
                nullify(rec, 'бутафосфан 100 мг/мл; дозирование на животное')
        ops.append('CALC Катозал®: бутафосфан 100 мг/мл + дозы на животное по инструкции')

    # ── 10. МЕ-концентраты: строка -> число (VER уже числом) ──────────────
    for name, num, unit in (
        ('Спировет', 600000, 'МЕ/мл'),
        ('Гепарин натрия-ЭНДОФАРМ', 5000, 'МЕ/мл'),
        ('Витамин А масляный раствор', 100000, 'МЕ/мл'),
    ):
        d = next((x for x in calc_recs(name)), None)
        if d is None:
            continue
        old = d.get('concentration')
        if isinstance(old, str):
            assert str(num) in old.replace(' ', ''), f'{name}: conc {old!r} не парсится в {num}'
            d['concentration'] = num
            d['concentration_unit'] = unit
            d['concentration_me'] = num
            ops.append(f'CALC {name}: conc {old!r} -> {num} {unit} (+concentration_me)')

    # ── 11. Комплексные витаминные: conc-текст неразложим, калькулятор
    #        рисует мусор -> парадигма «по инструкции» (паттерн Task 186) ──
    VITAMIN_COMPLEX = [
        'Ветолаза®', 'Фоллимаг®', 'Тетраспазвит', 'Триспазвит', 'Мультивек',
        'АД3Евит', 'AD3Евит раствор для перорального примене', 'Эльвита-Удивит',
        'Карофертин', 'Электро-Декс', 'Нуклеопептид', 'Армацид',
        'Витамин А ацетат 1000',
    ]
    for name in VITAMIN_COMPLEX:
        for d in calc_recs(name):
            old = d.get('concentration')
            if not isinstance(old, str):
                continue  # уже число/пусто — не трогаем
            d['calculator_applicable'] = False
            for sp in (d.get('animals') or []):
                set_fixed(d, sp, 'дозирование на животное по инструкции (комплексный состав)')
            asp = d.get('animal_specific') or {}
            for sp, rec in asp.items():
                if isinstance(rec, dict) and rec.get('dose_unit') != 'fixed':
                    nullify(rec, 'на животное по инструкции')
            ops.append(f'CALC {name}: conc-текст {old[:30]!r}… — комплексный состав, '
                       f'calc_applicable=false + «по инструкции»')

    # ── 12. zero-dose VER: «по схеме»/«через воду»/«1 раз в месяц» → fixed ──
    zd_fixed = 0
    for name, d in vd.items():
        if name.startswith('_'):
            continue
        asp = d.get('animal_specific') or {}
        for sp, rec in asp.items():
            if not isinstance(rec, dict):
                continue
            has_dose = (isinstance(rec.get('dose_per_kg'), (int, float))
                        and rec.get('dose_per_kg')) or \
                       (isinstance(rec.get('dose_min'), (int, float)) and rec.get('dose_min'))
            if has_dose:
                continue
            freq = str(rec.get('frequency') or '')
            if freq == 'по схеме':
                rec['dose_unit'] = 'fixed'
                rec.setdefault('notes', 'дозирование согласно инструкции')
                zd_fixed += 1
            elif freq == 'через воду':
                rec['dose_unit'] = 'fixed'
                rec.setdefault('notes', 'с питьевой водой по инструкции')
                zd_fixed += 1
            elif freq == '1 раз в месяц':
                rec['dose_unit'] = 'fixed'
                rec.setdefault('notes', 'пипетка/доза по весу животного')
                zd_fixed += 1
    ops.append(f'VER zero-dose: {zd_fixed} записей с «по схеме»/«через воду»/«1 р/мес» -> fixed-парадигма')

    dump(dc_p, dc)
    dump(vd_p, vd)
    for op in ops:
        print(' ✓', op)
    print(f'\nИТОГО операций: {len(ops)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
