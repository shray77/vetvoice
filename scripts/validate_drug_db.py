#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
validate_drug_db.py — гейт-валидатор числовых баз препаратов ветвойса.

Смысл (запрос владельца): «чтобы условно не вколоть в жопу лошадки
3 л эпинефрина» — абсурдные, но реальные записи в базе должны ловиться
ДО продакшена, а не в поле. Каждый класс проверки срабатывает на
известных ответах (канарейки --self-test), гейт краснеет на ERROR.

Проверяет (assets/data/):
  • drugs_calc.json      — главный калькулятор (dose_per_kg/dose_min/max,
                           concentration, animal_specific, fixed_dose)
  • verified_dosages.json — эталонные дозировки (animal_specific)
  • drugs_registry.json   — структурная целостность (2400+ записей)

Правила:
  ERROR — физиологически невозможное (доза вне пределов препарата,
          объём введения сверх видового капа, min>max, ноль у
          калькулируемого, запрещённый препарат виду)
  WARN  — подозрительное, но возможное (единица сбита, доза вне
          собственного диапазона, расхождение файлов >10x)

Выходы: 0 — зелёный; 1 — есть ERROR; 2 — сломан сам валидатор
        (провал канарейки). WARN не красит CI, но пишется в отчёт.

Запуск:
  python3 scripts/validate_drug_db.py                 # база репо
  python3 scripts/validate_drug_db.py --self-test     # только канарейки
  python3 scripts/validate_drug_db.py --data-dir PATH --reference REF.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ── Справочные веса взрослого типичного животного, кг ──────────────────────
# Не «максимальные», а рабочие: объёмные капы считаются от них.
REF_WEIGHT = {
    'Кошки': 4.0,
    'Собаки': 20.0,
    'Кролики': 3.0,
    'Пушные звери': 2.0,
    'Птица': 2.0,
    'МРС': 50.0,
    'Свиньи': 100.0,
    'КРС': 450.0,
    'Лошади': 500.0,
    # Пчёлы — доза «на пчелосемью», не на кг: объёмные капы неприменимы
}

# ── Кап объёма ОДНОГО введения (инъекционные пути), мл ─────────────────────
# Щедрые (ловим 10-1000х, а не споры о +-20%). ERROR выше капа x 5.
MAX_INJ_VOLUME_ML = {
    'Кошки': 20.0,
    'Собаки': 50.0,
    'Кролики': 10.0,
    'Пушные звери': 10.0,
    'Птица': 5.0,
    'МРС': 60.0,
    'Свиньи': 60.0,
    'КРС': 150.0,
    'Лошади': 150.0,
}

INJECTION_TOKENS = (
    'внутримышечн', 'подкожн', 'в/м', 'п/к', 'в/в', 'в/к', 'эпидураль',
    'инъекц', 'внутривен', 'внутривым', 'интратекаль', 'внутрикостн',
)

# ── Особо опасные препараты: числовые пределы, мг/кг (Plumb's, справочники) ─
# Вне пределов — ERROR. Подстрочный матч по INN (комбинированные тоже ловим).
CRITICAL_BOUNDS = {
    'эпинефрин': (0.001, 0.5),
    'адреналин': (0.001, 0.5),
    'атропин': (0.005, 2.0),          # верх: отравления ФОС 0.2-0.5
    'дигоксин': (0.002, 0.03),
    'лидокаин': (0.25, 10.0),
    'лигнокаин': (0.25, 10.0),
    'кетамин': (1.0, 20.0),
    'тилетамин': (1.0, 20.0),
    'ксилазин': (0.02, 4.0),
    'детомидин': (0.005, 0.12),
    'ромифидин': (0.005, 0.12),
    'медетомидин': (0.0005, 0.05),
    'дексмедетомидин': (0.0005, 0.05),
    'пропофол': (1.0, 10.0),
    'тиопентал': (4.0, 25.0),
    'ивермектин': (0.0002, 0.6),
    'моксидектин': (0.0002, 0.6),
    'дорамектин': (0.0002, 0.6),
    'метронидазол': (5.0, 30.0),      # >30 мг/кг/сут — нейротоксичность
    'карпрофен': (1.0, 5.0),
    'мелоксикам': (0.05, 0.6),
    'ацепромазин': (0.005, 0.3),
    'дигидроэрготамин': (0.005, 0.1),
    'винкристин': (0.0002, 0.025),
    'доксорубицин': (0.02, 1.5),
}

# Инсулин в мг/кг не существует в природе — только МЕ (IU).
INSULIN_MIN, INSULIN_MAX = 0.05, 5.0  # МЕ/кг
INSULIN_TOKENS = ('инсулин',)

# Инфузионные/электролитные — объём одного «введения» — это капельница,
# литры легальны (КРС 5-10 л жидкостей). Объёмный кап неприменим.
INFUSION_INN = (
    'кальция глюконат', 'кальция борглюконат', 'кальция хлорид',
    'глюкоза', 'декстроза',
    'натрия хлорид', 'рингер', 'реополиглюкин', 'физиологич',
    'электролит', 'дисоль', 'ацесоль', 'лактасоль', 'сорбилакт',
)


def is_infusion(inn):
    # Task 187: инфузионный компонент в ЛЮБОМ месте состава (Виме-Лайт IV —
    # «тиамин, ..., декстроза»: дексстроза в хвосте, но литры в/в легальны).
    i = str(inn or '').lower()
    return any(t in i for t in INFUSION_INN)

# ── Видовые запреты и видовые потолки (ERROR) ──────────────────────────────
# (токен INN, вид) -> (потолок мг/кг или None=запрещён целиком, комментарий)
SPECIES_RULES = {
    ('парацетамол', 'Кошки'): (0.0, 'парацетамол кошкам летален (метгемоглобинемия)'),
    ('ацетаминофен', 'Кошки'): (0.0, 'то же, что парацетамол'),
    ('перметрин', 'Кошки'): (0.0, 'перметрин кошкам летален'),
    ('энрофлоксацин', 'Кошки'): (5.0, 'выше 5 мг/кг — ретинальная токсичность'),
}

# ── Глобальные пределы по единице (все калькулируемые записи) ──────────────
# (pass, warn_above, error_above)
GLOBAL_UNIT_BOUNDS = {
    'мг/кг': (300.0, 2000.0),
    'мкг/кг': (5000.0, 20000.0),      # 5 мг/кг в мкг-выражении; выше — ед. сбита
    'МЕ/кг': (500000.0, 5000000.0),
    'мл/кг': (20.0, 100.0),
    'мг/кг корма': (2000.0, 10000.0),
    'мг/кг массы': (300.0, 2000.0),
}

# Легитимно высокие пероральные дозы (уголь 1-2 г/кг) — не флагаем ERROR.
HIGH_DOSE_WHITELIST = ('уголь активированный', 'уголь', 'полисорб', 'смекта')

UNIT_ALIASES = {
    '': None, 'fixed': 'fixed',
    'мг/кг': 'мг/кг', 'мг/кг.': 'мг/кг',
    'мкг/кг': 'мкг/кг',
    'ме/кг': 'МЕ/кг', 'ме/кг ': 'МЕ/кг',
    'мл/кг': 'мл/кг',
    'мг/кг корма': 'мг/кг корма', 'мг/кг корм': 'мг/кг корма',
    'мг/кг массы': 'мг/кг массы', 'мг/кг живой массы': 'мг/кг массы',
}

CONC_TO_MGML = {
    'мг/мл': 1.0, 'мг': 1.0, 'мг/г': 0.001,
    'г/мл': 1000.0, 'г': 1000.0,
    'мкг/мл': 0.001, 'мг/л': 0.001,
}
CONC_TO_MEML = {'ме/мл': 1.0, 'ме': 1.0, 'ме/г': 0.001, 'млн ме/мл': 1e6, 'млн ме': 1e6}

SEVERITY_ORDER = {'ERROR': 3, 'WARN': 2, 'INFO': 1, 'ACK': 0}


def load_known_issues(path):
    """known-issues.json — реестр проверенного долга данных (канон
    tokens.json): (file, drug, species, rule) -> reason. Совпадение
    понижает ERROR до ACK — гейт красят только НОВЫЕ абсурды."""
    p = Path(path)
    if not p.is_file():
        return {}
    try:
        data = json.loads(p.read_text(encoding='utf-8'))
    except Exception:  # noqa: BLE001
        return {}
    out = {}
    for issue in data.get('issues', []):
        key = (issue.get('file'), issue.get('drug'),
               issue.get('species'), issue.get('rule'))
        out[key] = issue.get('reason', '')
    return out


def apply_known_issues(rep, known):
    """Понижает ERROR-находки из реестра до ACK (с причиной в деталях)."""
    for f in rep.findings:
        if f.severity != 'ERROR':
            continue
        reason = known.get((f.file, f.drug, f.species, f.rule))
        if reason is not None:
            f.severity = 'ACK'
            f.detail = f'{f.detail} · ИЗВЕСТНО: {reason}'


@dataclass
class Finding:
    severity: str          # ERROR | WARN | INFO
    file: str
    drug: str
    species: str
    rule: str
    detail: str


@dataclass
class Report:
    findings: list = field(default_factory=list)

    def add(self, severity, file, drug, species, rule, detail):
        self.findings.append(
            Finding(severity, file, drug, species, rule, detail))

    def count(self, severity):
        return sum(1 for f in self.findings if f.severity == severity)

    def error_count(self):
        return self.count('ERROR')


# ── Нормализация ────────────────────────────────────────────────────────────

def norm_unit(u):
    if u is None:
        return None
    u = str(u).strip().lower()
    if u == 'ме/кг':
        return 'МЕ/кг'
    return UNIT_ALIASES.get(u, u if u else None)


def is_number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def dose_mgkg(value, unit):
    """Приводит дозу к мг/кг (для объёмного расчёта). МЕ не конвертим —
    возвращаем как есть с флагом is_iu."""
    if not is_number(value):
        return None, False
    u = norm_unit(unit)
    if u == 'мг/кг' or u == 'мг/кг массы':
        return float(value), False
    if u == 'мкг/кг':
        return float(value) / 1000.0, False
    if u == 'МЕ/кг':
        return float(value), True
    if u == 'мл/кг':
        return float(value), 'mlkg'
    return None, False


def conc_ml_units(conc, unit):
    """Концентрация -> (мг/мл | МЕ/мл | None). ВСЕГДА пара значений."""
    if not is_number(conc) or conc <= 0:
        return None, None
    u = str(unit or '').strip().lower()
    if u in CONC_TO_MGML:
        return float(conc) * CONC_TO_MGML[u], 'mg'
    if u in CONC_TO_MEML:
        return float(conc) * CONC_TO_MEML[u], 'me'
    return None, None


# Ингаляционные анестетики и иные препараты с %-дозировкой/«на пчелосемью» —
# парадигма мг/кг неприменима.
NON_PER_KG_INN = (
    'изофлуран', 'галотан', 'севофлуран', 'десфлуран', 'энфлуран',
)
VACCINE_INN = ('вакцин', 'штамм', 'анатоксин', 'бактериофаг')
EXTERNAL_TOKENS = ('наружно', 'накожн', 'спрей', 'внутривыменно', 'интрамаммарн')


def is_vaccineish(inn, name):
    s = f"{inn or ''} {name or ''}".lower()
    return any(t in s for t in VACCINE_INN)


def is_inhalation(inn):
    return any(t in str(inn or '').lower() for t in NON_PER_KG_INN)


def is_external_method(method):
    m = str(method or '').lower()
    return any(t in m for t in EXTERNAL_TOKENS)


def route_is_injection(form_type, method):
    if form_type == 'injection':
        return True
    m = str(method or '').lower()
    return any(t in m for t in INJECTION_TOKENS)


# Сепараторы компонентов комбинированных INN (уроки МОНИЗЕНа/Антибак ПРО:
# «,», «+», «;» и предлог « и » — все четыре признак комбо).
COMBO_SEPS = (',', '+', ';', ' и ')


def is_combo_inn(inn):
    i = str(inn or '')
    return any(sep in i for sep in COMBO_SEPS)


def first_component_of(inn):
    """Первый компонент комбинированного INN (по нему дозируется комбо)."""
    s = str(inn or '').lower()
    for sep in COMBO_SEPS:
        s = s.split(sep)[0]
    return s.strip()


def match_critical(inn):
    """INN -> (название группы, (min,max)) для особо опасных.

    Урок Флормелокса: комбинированные препараты («флорфеникол, мелоксикам»)
    дозируются по ПЕРВОМУ компоненту — пределы критического токена
    из хвоста комбинации не проверяем (доза 20 мг/кг там — флорфеникол).
    """
    i = str(inn or '').lower()
    first_component = first_component_of(i)
    combo = is_combo_inn(i)
    for token, bounds in CRITICAL_BOUNDS.items():
        if token in i:
            if combo and token not in first_component:
                continue
            return token, bounds
    for token in INSULIN_TOKENS:
        if token in i:
            if combo and token not in first_component:
                continue
            return 'инсулин', (INSULIN_MIN, INSULIN_MAX)
    return None, None


def match_species_rule(inn, species):
    i = str(inn or '').lower()
    for (token, sp), rule in SPECIES_RULES.items():
        if sp == species and token in i:
            return token, rule
    return None, None


def name_latin_cyrillic_mix(name):
    """«Dакцина», «Cобака» — латинская буква в кириллическом слове."""
    s = str(name or '')
    for m in re.finditer(r'\b([A-Za-z])[а-яё]', s):
        return m.group(0)
    return None


# ── Ядро проверок одной записи (доза + вид) ────────────────────────────────

def check_dose_record(rep, file_label, drug_name, inn, species,
                      dose, dose_unit, dose_min, dose_max, *,
                      calculator_applicable=True, form_type=None,
                      method=None, conc=None, conc_unit=None,
                      conc_me=None, dose_ml_per_kg=None):
    """Проверяет одну (вид, доза). Возвращает (severity_max, used_for_cross)."""
    worst = 'INFO'
    ctx_species = species or '—'

    def raise_to(sev):
        nonlocal worst
        if SEVERITY_ORDER[sev] > SEVERITY_ORDER[worst]:
            worst = sev

    unit = norm_unit(dose_unit)
    has_num = is_number(dose) and dose != 0
    has_range = (is_number(dose_min) and dose_min > 0
                 and is_number(dose_max) and dose_max > 0)

    # Парадигма мг/кг неприменима: пчелосемьи, фиксированные дозы,
    # вакцины, ингаляционные анестетики, наружные пути.
    per_kg_irrelevant = (
        species == 'Пчёлы'
        or unit == 'fixed'
        or is_vaccineish(inn, drug_name)
        or is_inhalation(inn)
        or is_external_method(method)
    )

    # 1. Ноль вынесен на уровень препарата (validate_drugs_calc):
    # видовой ноль не страшен (fallback на базу), проверяется «нет доз
    # вообще». В verified_dosages видовой пробел — WARN здесь.
    if file_label != 'drugs_calc.json' and calculator_applicable \
            and not has_num and not has_range and species \
            and not per_kg_irrelevant:
        rep.add('WARN', file_label, drug_name, ctx_species, 'zero-dose',
                'пробел справочника: дозы для вида нет')
        raise_to('WARN')

    # 2. min > max
    if (is_number(dose_min) and is_number(dose_max)
            and dose_min > 0 and dose_max > 0 and dose_min > dose_max):
        rep.add('ERROR', file_label, drug_name, ctx_species, 'min>max',
                f'dose_min={dose_min} > dose_max={dose_max}')
        raise_to('ERROR')

    # 3. Единица не указана при числовой дозе. Наружные/фиксированные/
    # вакцинные записи юнита не требуют (мг/кг там неприменим — Task 187).
    if has_num and unit is None and not per_kg_irrelevant:
        rep.add('WARN', file_label, drug_name, ctx_species, 'no-unit',
                f'доза {dose} без dose_unit — «{dose_unit!r}»')
        raise_to('WARN')

    # 3b. Инсулин: единицы и предел
    crit_name, crit_bounds = match_critical(inn)
    if crit_name == 'инсулин' and has_num:
        if unit == 'мг/кг':
            rep.add('WARN', file_label, drug_name, ctx_species, 'insulin-unit',
                    'инсулин в мг/кг — единица невозможна, должна быть МЕ/кг')
            raise_to('WARN')
        if not (crit_bounds[0] <= dose <= crit_bounds[1]):
            rep.add('ERROR', file_label, drug_name, ctx_species, 'critical-bound',
                    f'инсулин {dose} {unit} вне [{crit_bounds[0]}–{crit_bounds[1]}] МЕ/кг')
            raise_to('ERROR')

    # 4. Глобальные пределы по единице
    if has_num and unit in GLOBAL_UNIT_BOUNDS:
        pass_bound, err_bound = GLOBAL_UNIT_BOUNDS[unit]
        inn_l = str(inn or '').lower()
        whitelisted = any(t in inn_l for t in HIGH_DOSE_WHITELIST)
        if not whitelisted:
            if dose > err_bound:
                rep.add('ERROR', file_label, drug_name, ctx_species, 'unit-bound',
                        f'{dose} {dose_unit} — выше физио-потолка {err_bound}')
                raise_to('ERROR')
            elif dose > pass_bound:
                rep.add('WARN', file_label, drug_name, ctx_species, 'unit-bound',
                        f'{dose} {dose_unit} — выше обычного {pass_bound}, проверить единицы')
                raise_to('WARN')
        if has_num and dose < 0:
            rep.add('ERROR', file_label, drug_name, ctx_species, 'negative',
                    f'отрицательная доза {dose}')
            raise_to('ERROR')

    # 5. Особо опасные препараты — жёсткие пределы. У КОМБИНИРОВАННЫХ
    # (инн с запятой/плюсом/« и ») доза относится к одному компоненту —
    # атрибуция ненадёжна (урок МОНИЗЕНа: 5 мг/кг — празиквантел, не
    # ивермектин; урок Антибак ПРО: «энрофлоксацин И метронидазол» —
    # сепаратор « и » тоже признак комбо), поэтому комбинам — WARN,
    # монопрепаратам — ERROR.
    is_combo = is_combo_inn(inn)
    crit_sev = 'WARN' if is_combo else 'ERROR'
    if crit_name and crit_name != 'инсулин' and has_num and unit in (
            'мг/кг', 'мкг/кг', 'мг/кг массы'):
        lo, hi = crit_bounds
        v = float(dose)
        if unit == 'мкг/кг':
            lo, hi = lo * 1000, hi * 1000
        if not (lo <= v <= hi):
            rep.add(crit_sev, file_label, drug_name, ctx_species, 'critical-bound',
                    f'{crit_name}: {dose} {unit} вне [{lo:g}–{hi:g}] '
                    f'{"мкг" if unit == "мкг/кг" else "мг"}/кг'
                    + (' (комбинация — атрибуция дозы)' if is_combo else ''))
            raise_to(crit_sev)

    # 6. Видовые запреты/потолки — действуют и для комбинаций: циперметрин
    # в спот-оне для кошек опасен при любой атрибуции дозы. Но ПОТОЛОК
    # (cap > 0) у комбо — WARN: доза может относиться к другому компоненту
    # (урок Task 187: амоксициллин, энрофлоксацин — 15 мг/кг собакам это
    # амоксициллин, а не энрофлоксациновая передозировка кошке).
    _, rule = match_species_rule(inn, species)
    if rule and has_num and unit in ('мг/кг', 'мг/кг массы', 'мкг/кг'):
        cap, comment = rule
        v = float(dose)
        if unit == 'мкг/кг':
            cap = cap * 1000 if cap else 0.0
        if cap == 0.0:
            rep.add('ERROR', file_label, drug_name, ctx_species, 'species-ban',
                    f'{comment}: {dose} {unit}')
            raise_to('ERROR')
        elif v > cap:
            sev = 'WARN' if is_combo else 'ERROR'
            rep.add(sev, file_label, drug_name, ctx_species, 'species-cap',
                    f'{comment}: {dose} {unit} > {cap:g}'
                    + (' (комбинация — атрибуция дозы)' if is_combo else ''))
            raise_to(sev)

    # 7. dose_per_kg внутри собственного диапазона — у комбинированных
    # диапазон может относиться ко второму компоненту (урок ЛоксикVet:
    # мелоксикам 0.1 + габапентин 5-10) — комбам не проверяем.
    if has_num and has_range and is_number(dose_min) and is_number(dose_max) \
            and not is_combo:
        if not (dose_min <= dose <= dose_max):
            factor = max(dose / dose_max if dose_max else 0,
                         dose_min / dose if dose else 0)
            sev = 'ERROR' if factor >= 2 else 'WARN'
            rep.add(sev, file_label, drug_name, ctx_species, 'range-consistency',
                    f'dose_per_kg={dose} вне [{dose_min}–{dose_max}] (x{factor:.1f})')
            raise_to(sev)

    # 8. Объём введения — кейс «3 л эпинефрина лошадке».
    # Только для инъекционных путей (дренчи и таблетки — другие объёмы),
    # только для калькулируемых записей (иначе калькулятор их не касается)
    # и не для инфузионных (литры капельницы легальны).
    if species and species in REF_WEIGHT and species != 'Пчёлы' \
            and calculator_applicable and not is_infusion(inn) \
            and route_is_injection(form_type, method):
        weight = REF_WEIGHT[species]
        cap = MAX_INJ_VOLUME_ML.get(species)
        volume_ml = None
        mgkg, is_iu = (None, False)
        if has_num:
            mgkg, is_iu = dose_mgkg(dose, dose_unit)
        # мл/кг напрямую
        if unit == 'мл/кг' and has_num:
            volume_ml = float(dose) * weight
        elif dose_ml_per_kg and is_number(dose_ml_per_kg) and dose_ml_per_kg > 0:
            volume_ml = float(dose_ml_per_kg) * weight
        elif mgkg is not None and mgkg != 'mlkg' and not is_iu:
            conc_v, conc_kind = conc_ml_units(conc, conc_unit)
            if conc_v is None and is_number(conc_me) and conc_me > 0 and is_iu:
                conc_v, conc_kind = float(conc_me), 'me'
            if conc_v and conc_kind == 'mg':
                volume_ml = float(mgkg) * weight / conc_v
        if volume_ml is not None and cap:
            if volume_ml > cap * 5:
                rep.add('ERROR', file_label, drug_name, ctx_species, 'volume',
                        f'объём {volume_ml:.0f} мл за одно введение '
                        f'(кап вида {cap:g} мл, x{volume_ml / cap:.0f})')
                raise_to('ERROR')
            elif volume_ml > cap:
                rep.add('WARN', file_label, drug_name, ctx_species, 'volume',
                        f'объём {volume_ml:.0f} мл выше капа вида {cap:g} мл')
                raise_to('WARN')

    return worst


# ── Проверка целого файла drugs_calc.json ──────────────────────────────────

def check_zero_dose_drug(rep, file_label, name, inn, d, calc):
    """Уровень препарата: нет доз ни в базе, ни по видам — ERROR."""
    def _has_dose(obj):
        return (is_number(obj.get('dose_per_kg')) and obj.get('dose_per_kg') > 0) \
            or (is_number(obj.get('dose_min')) and obj.get('dose_min') > 0
                and is_number(obj.get('dose_max')) and obj.get('dose_max') > 0)

    specs = d.get('animal_specific') or {}
    any_dose = _has_dose(d) or any(
        isinstance(o, dict) and _has_dose(o) for o in specs.values())
    if calc and not any_dose and not is_vaccineish(inn, name) \
            and not is_inhalation(inn) and 'Пчёлы' not in specs \
            and norm_unit(d.get('dose_unit')) != 'fixed' \
            and not is_external_method(d.get('method')):
        rep.add('ERROR', file_label, name, '—', 'zero-dose',
                'у calculator_applicable нет доз ни в базе, ни по видам — '
                'калькулятор молча покажет 0')


def validate_drugs_calc(data, rep, file_label):
    drugs = data.get('drugs_calc')
    if not isinstance(drugs, list) or not drugs:
        rep.add('ERROR', file_label, '—', '—', 'schema',
                'drugs_calc пуст или не список')
        return 0
    checked = 0
    for d in drugs:
        if not isinstance(d, dict):
            rep.add('ERROR', file_label, '?', '—', 'schema', 'запись не объект')
            continue
        name = str(d.get('name') or d.get('inn') or f"id={d.get('id')}")
        inn = d.get('inn') or name
        calc = bool(d.get('calculator_applicable'))
        mix = name_latin_cyrillic_mix(name)
        if mix:
            rep.add('WARN', file_label, name, '—', 'typo',
                    f'латино-кириллическая смесь в имени: «{mix}…»')
        checked += 1
        check_zero_dose_drug(rep, file_label, name, inn, d, calc)
        # базовая запись
        check_dose_record(
            rep, file_label, name, inn, None,
            d.get('dose_per_kg'), d.get('dose_unit'),
            d.get('dose_min'), d.get('dose_max'),
            calculator_applicable=calc,
            form_type=d.get('form_type'), method=d.get('method'),
            conc=d.get('concentration'), conc_unit=d.get('concentration_unit'),
            conc_me=d.get('concentration_me'))
        # видовые записи
        for species, obj in (d.get('animal_specific') or {}).items():
            if not isinstance(obj, dict):
                continue
            check_dose_record(
                rep, file_label, name, inn, species,
                obj.get('dose_per_kg'), obj.get('dose_unit'),
                obj.get('dose_min'), obj.get('dose_max'),
                calculator_applicable=calc,
                form_type=d.get('form_type'),
                method=obj.get('method') or d.get('method'),
                conc=d.get('concentration'),
                conc_unit=d.get('concentration_unit'),
                conc_me=d.get('concentration_me'),
                dose_ml_per_kg=obj.get('dose_ml_per_kg'))
        # форма-путь: инъекция без концентрации — калькулятор деградирует
        if calc and route_is_injection(d.get('form_type'), d.get('method')):
            if not is_number(d.get('concentration')) or d.get('concentration') <= 0:
                if not (is_number(d.get('concentration_me'))
                        and d.get('concentration_me') > 0):
                    rep.add('WARN', file_label, name, '—', 'no-conc',
                            'инъекция без concentration — парсер состава '
                            'пытается спасти, но запись неполная')
    return checked


# ── Проверка verified_dosages.json ─────────────────────────────────────────

def validate_verified(data, rep, file_label):
    entries = {k: v for k, v in data.items() if not k.startswith('_')}
    if not entries:
        rep.add('ERROR', file_label, '—', '—', 'schema',
                'verified_dosages пуст')
        return 0
    checked = 0
    for name, d in entries.items():
        if not isinstance(d, dict):
            continue
        inn = d.get('inn') or name
        conc = d.get('concentration')
        conc_unit = d.get('concentration_unit')
        for species, obj in (d.get('animal_specific') or {}).items():
            if not isinstance(obj, dict):
                continue
            checked += 1
            check_dose_record(
                rep, file_label, str(name), inn, species,
                obj.get('dose_per_kg'), obj.get('dose_unit'),
                obj.get('dose_min'), obj.get('dose_max'),
                # Task 187: прежде был захардкожен True — записи с явным
                # calculator_applicable=false (наружные растворы вроде
                # Акаромектина) не должны ловить объёмный гейт калькулятора,
                # который их не показывает. Отсутствие поля = прежний True.
                calculator_applicable=bool(d.get('calculator_applicable', True)),
                method=obj.get('method'),
                conc=conc, conc_unit=conc_unit,
                dose_ml_per_kg=obj.get('dose_ml_per_kg'))
            # сверка мл/кг против мг/кг и концентрации
            dpk, mlk = obj.get('dose_per_kg'), obj.get('dose_ml_per_kg')
            if (is_number(dpk) and is_number(mlk) and dpk > 0 and mlk > 0
                    and is_number(conc) and conc > 0
                    and norm_unit(obj.get('dose_unit')) in ('мг/кг', None)):
                implied = dpk / float(conc)
                if mlk > 0 and abs(implied - mlk) / mlk > 0.3:
                    rep.add('WARN', file_label, str(name), species,
                            'mlkg-consistency',
                            f'dose_ml_per_kg={mlk} != {dpk}/conc({conc})'
                            f'={implied:.4g} (расхождение >30%)')
    return checked


# ── Кросс-сверка файлов (drugs_calc vs verified) ───────────────────────────

def cross_check(calc_data, verified_data, rep, file_label):
    def collect(data, list_mode):
        out = {}
        if list_mode:
            for d in data.get('drugs_calc', []):
                inn = str(d.get('inn') or '').strip().lower()
                if not inn:
                    continue
                for species, obj in (d.get('animal_specific') or {}).items():
                    if isinstance(obj, dict) and is_number(obj.get('dose_per_kg')) \
                            and obj.get('dose_per_kg') > 0:
                        out[(inn, species)] = float(obj['dose_per_kg'])
        else:
            for name, d in data.items():
                if not isinstance(d, dict) or str(name).startswith('_'):
                    continue
                inn = str(d.get('inn') or '').strip().lower()
                if not inn:
                    continue
                for species, obj in (d.get('animal_specific') or {}).items():
                    if isinstance(obj, dict) and is_number(obj.get('dose_per_kg')) \
                            and obj.get('dose_per_kg') > 0:
                        out[(inn, species)] = float(obj['dose_per_kg'])
        return out

    a = collect(calc_data, True)
    b = collect(verified_data, False)
    compared = 0
    for key in a.keys() & b.keys():
        va, vb = a[key], b[key]
        hi, lo = max(va, vb), min(va, vb)
        if hi > lo * 10:
            rep.add('WARN', file_label, key[0], key[1], 'cross-file',
                    f'drugs_calc={va:g} против verified={vb:g} (x{hi / lo:.0f})')
        compared += 1
    return compared


# ── Сверка с кураторским справочником (ветэко correct_dosages_reference) ──

def reference_check(calc_data, verified_data, ref_path, rep):
    try:
        ref = json.loads(Path(ref_path).read_text(encoding='utf-8'))
    except Exception as e:  # noqa: BLE001
        rep.add('WARN', str(ref_path), '—', '—', 'reference',
                f'справочник не читается: {e}')
        return 0
    doses = ref.get('dosages', {})
    matched = 0

    def check_pool(data, list_mode, file_label):
        nonlocal matched
        if list_mode:
            items = [(str(d.get('inn') or ''), d) for d in data.get('drugs_calc', [])]
        else:
            items = [(str(d.get('inn') or ''), d) for k, d in data.items()
                     if isinstance(d, dict) and not str(k).startswith('_')]
        for inn, d in items:
            inn_l = inn.strip().lower()
            # Комбинированным препаратам кросс-сверка неприменима: доза
            # относится к одному из компонентов, атрибуции нет (урок
            # «флорфеникол+мелоксикам 20 мг/кг против справочника
            # мелоксикама» — 20 там флорфеникол).
            if any(sep in inn_l for sep in (',', '+', ';')):
                continue
            ref_entry = None
            for rname, rd in doses.items():
                if rname in inn_l or inn_l.startswith(rname):
                    ref_entry = (rname, rd)
                    break
            if not ref_entry:
                continue
            rname, rd = ref_entry
            for species, obj in (d.get('animal_specific') or {}).items():
                if not isinstance(obj, dict):
                    continue
                dpk = obj.get('dose_per_kg')
                if not is_number(dpk) or dpk <= 0:
                    continue
                rs = rd.get(species)
                if not rs:
                    continue
                rmin, rmax = rs.get('dose_min'), rs.get('dose_max')
                rdpk = rs.get('dose_per_kg')
                if is_number(rdpk) and not is_number(rmin):
                    rmin = rdpk
                if is_number(rdpk) and not is_number(rmax):
                    rmax = rdpk
                if not (is_number(rmin) and is_number(rmax) and rmin > 0):
                    continue
                matched += 1
                unit = norm_unit(obj.get('dose_unit')) or 'мг/кг'
                if unit not in ('мг/кг', 'мг/кг массы'):
                    continue
                lo, hi = float(rmin), float(rmax)
                if not (lo / 4 <= dpk <= hi * 4):
                    rep.add('ERROR', file_label, f'{inn[:40]}', species,
                            'reference',
                            f'{dpk:g} мг/кг против справочника {rname} '
                            f'[{lo:g}–{hi:g}] (вне x4)')
                elif not (lo / 2 <= dpk <= hi * 2):
                    rep.add('WARN', file_label, f'{inn[:40]}', species,
                            'reference',
                            f'{dpk:g} мг/кг против справочника {rname} '
                            f'[{lo:g}–{hi:g}] (вне x2)')

    check_pool(calc_data, True, 'drugs_calc.json')
    check_pool(verified_data, False, 'verified_dosages.json')
    return matched


# ── Канарейки: известные ответы (валидатор сам гейтится) ───────────────────

CANARY_RECORDS = [
    # (описание, kwargs, ожидаемая худшая тяжесть)
    ('эпинефрин 6 мг/кг 1 мг/мл лошади — кейс «3 л в жопу лошадке»',
     dict(drug='Эпинефрин-канарейка', inn='эпинефрин', species='Лошади',
          dose=6, dose_unit='мг/кг', conc=1.0, conc_unit='мг/мл',
          form_type='injection', method='внутримышечно'),
     'ERROR'),
    ('парацетамол кошке 10 мг/кг — летально',
     dict(drug='Парацетамол-канарейка', inn='парацетамол', species='Кошки',
          dose=10, dose_unit='мг/кг', conc=100.0, conc_unit='мг/мл',
          form_type='oral', method='внутрь'),
     'ERROR'),
    ('колистин 50000 мг/кг — единицы сбиты',
     dict(drug='Колистин-канарейка', inn='колистин', species='Свиньи',
          dose=50000, dose_unit='мг/кг', conc=100.0, conc_unit='мг/мл',
          form_type='oral', method='внутрь с водой'),
     'ERROR'),
    ('энрофлоксацин кошке 10 мг/кг — сетчатка',
     dict(drug='Энро-канарейка', inn='энрофлоксацин', species='Кошки',
          dose=10, dose_unit='мг/кг', conc=50.0, conc_unit='мг/мл',
          form_type='injection', method='подкожно'),
     'ERROR'),
    ('мин больше макса',
     dict(drug='Диапазон-канарейка', inn='амоксициллин', species='Собаки',
          dose=15, dose_unit='мг/кг', dose_min=5, dose_max=2,
          conc=150.0, conc_unit='мг/мл', form_type='injection'),
     'ERROR'),
    ('ноль у калькулируемого (уровень препарата)',
     dict(drug='Ноль-канарейка', inn='цефазолин', species='—',
          dose=0, dose_unit='мг/кг', conc=100.0, conc_unit='мг/мл',
          form_type='injection', calculator_applicable=True,
          zero_drug=True),
     'ERROR'),
    ('инсулин в мг/кг — единица невозможна',
     dict(drug='Инсулин-канарейка', inn='инсулин гларгин', species='Кошки',
          dose=0.3, dose_unit='мг/кг', conc=100, conc_unit='МЕ',
          form_type='injection', method='подкожно'),
     'WARN'),
    ('амоксициллин 15 мг/кг КРС — норма, не флагаем',
     dict(drug='Амокси-канарейка', inn='амоксициллин', species='КРС',
          dose=15, dose_unit='мг/кг', dose_min=10, dose_max=20,
          conc=150.0, conc_unit='мг/мл', form_type='injection',
          method='подкожно'),
     None),
    ('ивермектин собаке 0.006 мг/кг — норма',
     dict(drug='Ивермектин-канарейка', inn='ивермектин', species='Собаки',
          dose=0.006, dose_unit='мг/кг', conc=10.0, conc_unit='мг/мл',
          form_type='injection', method='подкожно'),
     None),
]


def run_self_test():
    failures = []
    for desc, kwargs, expected in CANARY_RECORDS:
        rep = Report()
        # канарейки имитируют записи drugs_calc (калькуляторный путь)
        if kwargs.get('zero_drug'):
            check_zero_dose_drug(rep, 'drugs_calc.json', kwargs['drug'],
                                 kwargs['inn'],
                                 {'dose_per_kg': kwargs.get('dose'),
                                  'dose_unit': kwargs.get('dose_unit'),
                                  'animal_specific': {},
                                  'method': kwargs.get('method')},
                                 True)
        else:
            check_dose_record(rep, 'drugs_calc.json', kwargs['drug'],
                          kwargs['inn'], kwargs['species'],
                          kwargs.get('dose'), kwargs.get('dose_unit'),
                          kwargs.get('dose_min'), kwargs.get('dose_max'),
                          calculator_applicable=kwargs.get(
                              'calculator_applicable', True),
                          form_type=kwargs.get('form_type'),
                          method=kwargs.get('method'),
                          conc=kwargs.get('conc'),
                          conc_unit=kwargs.get('conc_unit'),
                          dose_ml_per_kg=kwargs.get('dose_ml_per_kg'))
        got = None if not rep.findings else max(
            (f.severity for f in rep.findings),
            key=lambda s: SEVERITY_ORDER[s])
        expected_order = (SEVERITY_ORDER[expected]
                          if expected else SEVERITY_ORDER['INFO'])
        got_order = SEVERITY_ORDER[got] if got else SEVERITY_ORDER['INFO']
        ok = (got == expected) if expected else got is None
        # WARN-канарейка: допускаем и выше (ERROR), но не INFO
        if expected == 'WARN' and got in ('WARN', 'ERROR'):
            ok = True
        if not ok:
            failures.append(
                f'  ✗ {desc}\n    ожидалось: {expected}, получено: {got}'
                f' ({[f.rule for f in rep.findings]})')
        else:
            print(f'  ✓ {desc} → {got or "чисто"}')
    return failures


# ── Отчёт ───────────────────────────────────────────────────────────────────

def print_report(rep, checked_counts):
    print()
    print('=' * 78)
    for sev in ('ERROR', 'WARN', 'INFO', 'ACK'):
        n = rep.count(sev)
        if n:
            label = sev if sev != 'ACK' else 'ACK (known-issues)'
            print(f'{label}: {n}')
    print(f'проверено записей: {checked_counts}')
    print('=' * 78)
    order = {'ERROR': 0, 'WARN': 1, 'INFO': 2, 'ACK': 3}
    for f in sorted(rep.findings, key=lambda f: (order[f.severity], f.file)):
        print(f'[{f.severity:5}] {f.file} · {f.drug[:44]:44} · {f.species:12}'
              f' · {f.rule}: {f.detail}')
    print()
    print(f'ИТОГ: ERROR={rep.count("ERROR")} WARN={rep.count("WARN")} '
          f'INFO={rep.count("INFO")} ACK={rep.count("ACK")}')


def write_md_report(rep, path, checked_counts):
    lines = [
        '# Отчёт валидатора баз препаратов',
        '',
        f'Проверено записей: {checked_counts}. '
        f'ERROR={rep.count("ERROR")}, WARN={rep.count("WARN")}, '
        f'INFO={rep.count("INFO")}, ACK={rep.count("ACK")}.',
        '',
        '| Тяжесть | Файл | Препарат | Вид | Правило | Детали |',
        '|---|---|---|---|---|---|',
    ]
    order = {'ERROR': 0, 'WARN': 1, 'INFO': 2, 'ACK': 3}
    for f in sorted(rep.findings, key=lambda f: (order[f.severity], f.file)):
        d = f.detail.replace('|', '/')
        lines.append(f'| {f.severity} | {f.file} | {f.drug[:40]} | '
                     f'{f.species} | {f.rule} | {d} |')
    Path(path).write_text('\n'.join(lines) + '\n', encoding='utf-8')


# ── main ────────────────────────────────────────────────────────────────────

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--data-dir', default=None,
                    help='каталог assets/data (по умолчанию — репо скрипта)')
    ap.add_argument('--self-test', action='store_true',
                    help='только канарейки (известные ответы)')
    ap.add_argument('--reference', default=None,
                    help='correct_dosages_reference.json для кросс-сверки')
    ap.add_argument('--report', default=None,
                    help='путь для markdown-отчёта')
    ap.add_argument('--known-issues', default=None,
                    help='known-issues.json (по умолчанию — рядом со скриптом;'
                         ' понижает ERROR до ACK — проверенный долг данных)')
    ap.add_argument('--emit-known-issues', default=None,
                    help='ЗАПИСАТЬ текущие ERROR-находки как реестр долга '
                         '(для ручной аннотации причин) и выйти')
    args = ap.parse_args(argv)

    print('validate_drug_db.py — гейт числовых баз препаратов')

    print('\n— канарейки (валидатор гейтит сам себя) —')
    failures = run_self_test()
    if failures:
        print('\nКАНАРЕЙКИ ПРОВАЛЕНЫ — валидатор сломан:')
        print('\n'.join(failures))
        return 2

    if args.self_test:
        print('\nКанарейки зелёные. --self-test завершён.')
        return 0

    base = Path(args.data_dir) if args.data_dir else \
        Path(__file__).resolve().parent.parent / 'assets' / 'data'
    if not base.is_dir():
        print(f'нет каталога данных: {base}')
        return 2

    rep = Report()
    checked = 0
    calc_data = {}

    # drugs_calc.json
    p = base / 'drugs_calc.json'
    try:
        calc_data = json.loads(p.read_text(encoding='utf-8'))
        n = validate_drugs_calc(calc_data, rep, 'drugs_calc.json')
        print(f'\ndrugs_calc.json: {n} записей проверено')
        checked += n
    except Exception as e:  # noqa: BLE001
        rep.add('ERROR', 'drugs_calc.json', '—', '—', 'parse',
                f'файл не читается: {e}')

    # verified_dosages.json
    p = base / 'verified_dosages.json'
    try:
        verified_data = json.loads(p.read_text(encoding='utf-8'))
        n = validate_verified(verified_data, rep, 'verified_dosages.json')
        print(f'verified_dosages.json: {n} видовых записей проверено')
        checked += n
    except Exception as e:  # noqa: BLE001
        rep.add('ERROR', 'verified_dosages.json', '—', '—', 'parse',
                f'файл не читается: {e}')
        verified_data = {}

    # drugs_registry.json — только структурная целостность
    p = base / 'drugs_registry.json'
    try:
        reg = json.loads(p.read_text(encoding='utf-8'))
        drugs = reg.get('drugs')
        if not isinstance(drugs, list) or len(drugs) < 100:
            rep.add('ERROR', 'drugs_registry.json', '—', '—', 'schema',
                    f'drugs-список подозрительно мал: {len(drugs) if isinstance(drugs, list) else "?!"}')
        else:
            print(f'drugs_registry.json: {len(drugs)} записей, структура ок')
            for d in drugs[:]:
                mix = name_latin_cyrillic_mix(d.get('trade_name'))
                if mix:
                    rep.add('WARN', 'drugs_registry.json',
                            str(d.get('trade_name')), '—', 'typo',
                            f'латино-кириллическая смесь: «{mix}…»')
    except Exception as e:  # noqa: BLE001
        rep.add('ERROR', 'drugs_registry.json', '—', '—', 'parse',
                f'файл не читается: {e}')

    # кросс-сверка файлов
    if calc_data and verified_data:
        cmp_n = cross_check(calc_data, verified_data, rep, 'cross')
        print(f'кросс-сверка drugs_calc × verified: {cmp_n} пар INN×вид')

    # кросс-сверка со справочником
    if args.reference:
        m = reference_check(calc_data, verified_data, args.reference, rep)
        print(f'сверка со справочником: {m} совпадений INN×вид')

    # ── реестр проверенного долга ──
    if args.emit_known_issues:
        issues = [{
            'file': f.file, 'drug': f.drug, 'species': f.species,
            'rule': f.rule,
            'reason': 'TODO: причина и план (conc/доза из конверсии xlsx — '
                      'чинить по инструкции производителя)',
        } for f in rep.findings if f.severity == 'ERROR']
        Path(args.emit_known_issues).write_text(
            json.dumps({
                'version': 1,
                'generated': '2026-10-29',
                'description': (
                    'Реестр проверенного долга данных: находки, пониженные '
                    'из ERROR в ACK. Каждая запись требует причины и плана; '
                    'по мере чинки данных записи УДАЛЯЮТСЯ отсюда — и если '
                    'баг вернулся или появился новый абсурд, гейт краснеет.'),
                'issues': issues,
            }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'\nреестр долга записан: {args.emit_known_issues} '
              f'({len(issues)} записей) — аннотировать причины и запускать '
              f'с --known-issues')
        return 1

    ki_path = args.known_issues or \
        Path(__file__).resolve().parent / 'known-issues.json'
    known = load_known_issues(ki_path)
    if known:
        apply_known_issues(rep, known)
        print(f'\nknown-issues: {len(known)} записей реестра применено '
              f'(ACK={rep.count("ACK")})')

    print_report(rep, checked)
    if args.report:
        write_md_report(rep, args.report, checked)
        print(f'отчёт: {args.report}')

    return 1 if rep.error_count() else 0


if __name__ == '__main__':
    sys.exit(main())
