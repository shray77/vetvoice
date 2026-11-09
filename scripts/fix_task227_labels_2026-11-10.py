#!/usr/bin/env python3
"""
Task 227 (2026-11-10): сверка видов с лейблами и госреестром + 3 error'а
противопоказаний из отчёта vetvoice-parsers (2026-11-08).

Решение владельца: «ну, давай все вместе» — закрыть долг Task 226 «виды вне
лейблов» по официальному дампу госреестра ЛС (fsvps.gov.ru, 2026-11-03) и
вербатим-лейблам, плюс 3 error'а contraindications из валидационного отчёта.

Правки (все с верифицированными источниками, вербатим в data-комментариях):
1. #986 Пуревакс RCP Rabies — pregnancy/lactation = true
   (ветклиники.рф: «Сукотных и лактирующих животных не вакцинируют»;
   госреестр, Пуревакс RCP: «Беременные и лактирующие животные не подлежат
   вакцинации») + pregnancy_contraindicated_animals=['Кошки'] (прецедент
   Неомастина, Task 225).
2. #2070 Форвет® — pregnancy/lactation = true (госреестр: «Не рекомендуется
   применять беременным самкам, в период лактации и у потомства животных»);
   young не тронут — противоречит показаниям «назначают телятам и поросятам».
3. #2041 Нороклав инъекционный (140 мг/мл) — animals с МРС/Свиней/Лошадей/
   Кошек сужены до ['КРС','Собаки'] (ветклиники.рф: «Назначают собакам и КРС»,
   eapteka: «крупному рогатому скоту и собакам»; 140/35 — форма для крупных).
4. #1033 Флорфеникол 40% — Кошки/Птица срезаны (госреестр: «свиньям и
   крупному рогатому скоту»).
5. #2036 Универм® — Собаки/Кошки срезаны (лейбл: «назначают крупному
   рогатому скоту, овцам, козам, верблюдам, зубрам, свиньям, лошадям, зебрам,
   мулам, ослам, пушным зверям, кроликам»; реестр: «включая птиц»). МРС/
   Свиньи/Лошади из лейбла НЕ добавлены — нет верифицированных повидовых доз
   (принцип «не выдумывать», Task 226).
6. #37 Тилмакс — Кошки срезаны (Видаль: «Применяют свиньям с лечебной
   целью...»); общая frequency по лейблу — «однократно».
7. Инъекционные флорфениколы — Птица срезана у 15 записей (госреестр по
   каждому: свиньи и КРС, у Ресфлора только КРС, у Флорона 30% только свиньи;
   vetlek Флорокс: «свиньям и крупному рогатому скоту»). Птице флорфеникол
   дают только оральные (питьевые) формы — 30% инъекционные птице не
   зарегистрированы. #1720 Ресфлор → ['КРС'], #2034 Флорон 30% → ['Свиньи'],
   #1883 Флоридокс → ['КРС','Свиньи','МРС'] («телятам, овцам и свиньям»,
   vetlek).

8. Частоты 5 интрамаммарных записей (долг Task 226 «частоты неполных
   лейблов») — по верифицированным лейблам:
   - #1602 Гамарет: «однократно; при тяжёлом течении повтор через 24-48 ч»
     (официальная инструкция на galen.vetrf.ru; elitepremix: «применяют
     однократно, но при тяжёлом течении мастита введение препарата
     повторяют через 24 или 48 часов»); course_days 3-5 → срезан.
   - #1541 Антимаст: «с интервалом 12 часов в течение 3-4 дней» (вербатим
     vetinfo/yarvet/Bionit: «в дозе 10 мл на одну четверть вымени с
     интервалом 12 часов в течение 3-4 дней»); course_days срезан.
   - #1969 Пелтамаст — оказался СУХОСТОЙНЫМ (galen.vetrf.ru: «для
     профилактики и лечения мастита у коров в сухостойный период»; teniza:
     «вводят... после завершения лактационного периода... во все четверти
     вымени, однократно в дозе 10 мл в каждую четверть»): frequency
     «однократно при запуске (сухостой)», fixed_dose дополнен, каренции по
     лейблу — мясо 28 дн, молоко не ранее 4 дней после отёла (было 14/3).
   - #2052 Мамикур: «трёхкратно с интервалом 12 часов» (zooexpress PDF:
     «вводят трехкратно с интервалом 12 часов, интрацистернально, коровам
     8,15 г... овцам и козам — 4,75 г»); course_days 5-7 → срезан.
   - #2253 Ампиклокс LC: «3 введения с интервалом 12 часов» (Норкин,
     диссертация: «курс лечения состоит из трёхкратного...» + собственный
     fixed_dose записи); course_days 5-7 → срезан.

Срезаемым видам сопутствуют их animal_specific-ветки — срезаются вместе.
Идемпотентность: повторный запуск — no-op. --check — dry-run с отчётом.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

CANON = Path(__file__).resolve().parent.parent / "assets" / "data" / "drugs_calc.json"

# (id, comment) → операции
# animals_remove: срезать из animals + animal_specific
# animals_set: полная замата animals (для сужения с перестройкой)
# frequency_set: новая общая частота
# contraindications_set: флаги
SPECIES_CUT = {
    51: {"remove": ["Птица"], "src": "госреестр: КРС и свиньи"},
    416: {"remove": ["Птица"], "src": "госреестр: свиньи и КРС"},
    433: {"remove": ["Птица"], "src": "госреестр: КРС и свиньи"},
    538: {"remove": ["Птица"], "src": "госреестр: свиньи и КРС"},
    563: {"remove": ["Птица"], "src": "госреестр: свиньи и КРС"},
    894: {"remove": ["Птица"], "src": "госреестр: свиньи и КРС"},
    925: {"remove": ["Птица"], "src": "госреестр: свиньи и КРС"},
    1033: {"remove": ["Кошки", "Птица"], "src": "госреестр: свиньям и КРС"},
    1118: {"remove": ["Птица"], "src": "госреестр: свиньям и КРС"},
    1720: {"remove": ["Свиньи", "Птица"], "src": "госреестр: только КРС"},
    1883: {"remove": ["Собаки", "Кошки", "Птица"], "add": ["МРС"],
           "src": "vetlek/госреестр: телятам, овцам и свиньям"},
    1915: {"remove": ["Птица"], "src": "vetlek: свиньям и КРС"},
    2034: {"remove": ["КРС", "Птица"], "src": "госреестр: только свиньи"},
    2123: {"remove": ["Птица"], "src": "ветклиники.рф: свиньям и КРС"},
    2281: {"remove": ["Птица"], "src": "госреестр/Видаль: КРС и свиньи"},
    2041: {"remove": ["Кошки", "МРС", "Свиньи", "Лошади"],
           "src": "ветклиники.рф/eapteka: собакам и КРС (форма 140/35)"},
    2036: {"remove": ["Собаки", "Кошки"],
           "src": "лейбл PDF: с/х животным, вкл. птиц, пушных и кроликов"},
    37: {"remove": ["Кошки"], "src": "Видаль: применяют свиньям"},
}

FREQUENCY_SET = {
    37: "однократно",
    1602: "однократно; при тяжёлом течении повтор через 24-48 ч",
    1541: "с интервалом 12 часов в течение 3-4 дней",
    1969: "однократно при запуске (сухостойный период)",
    2052: "трёхкратно с интервалом 12 часов",
    2253: "3 введения с интервалом 12 часов",
}

# course_days к нулю: курс либо уже в частоте, либо введение однократное
COURSE_CLEAR = {1602, 1541, 2052, 2253}

# точечные замены полей (fixed_dose / каренции Пелтамаста — сухостой)
FIELD_SET = {
    1969: {
        "fixed_dose": {"КРС": "10 мл в каждую четверть вымени однократно при запуске (после последней дойки, сухостойный период)"},
        "withdrawal_days": 28,
        "withdrawal_text": "КРС: мясо: 28 дн; молоко: не ранее 4 дней после отёла",
        "src": "galen.vetrf.ru/teniza: сухостойный период, однократно 10 мл в каждую четверть; каренции по лейблу",
    },
}

CONTRA_SET = {
    986: {"pregnancy": True, "lactation": True,
          "pregnancy_contraindicated_animals": ["Кошки"],
          "src": "«Сукотных и лактирующих животных не вакцинируют»"},
    2070: {"pregnancy": True, "lactation": True,
           "pregnancy_contraindicated_animals": ["КРС", "Свиньи", "Собаки", "Кошки"],
           "src": "госреестр: беременным самкам, в период лактации"},
}


def load() -> dict:
    return json.loads(CANON.read_text(encoding="utf-8"))


def drugs_of(db: dict) -> list:
    return db["drugs_calc"] if "drugs_calc" in db else db


def apply_fixes(db: dict) -> tuple[int, list[str]]:
    """Возвращает (число правок, лог). Идемпотентно: уже-применённое — пропуск."""
    changes = 0
    log: list[str] = []
    dmap = {d["id"]: d for d in drugs_of(db)}

    for did, spec in SPECIES_CUT.items():
        d = dmap.get(did)
        if d is None:
            log.append(f"#{did} НЕ НАЙДЕН — пропущен")
            continue
        animals = d.get("animals") or []
        asp = d.get("animal_specific") or {}
        touched = False
        for sp in spec["remove"]:
            if sp in animals:
                animals = [a for a in animals if a != sp]
                touched = True
            if sp in asp:
                del asp[sp]
                touched = True
        for sp in spec.get("add", []):
            if sp not in animals:
                animals.append(sp)
                touched = True
        if touched:
            d["animals"] = animals
            if asp:
                d["animal_specific"] = asp
            changes += 1
            log.append(f"#{did} {d['name']}: animals={animals} ({spec['src']})")
        else:
            log.append(f"#{did} {d['name']}: уже чисто (no-op)")

    for did, freq in FREQUENCY_SET.items():
        d = dmap.get(did)
        if d is None:
            continue
        if d.get("frequency") != freq:
            old = d.get("frequency")
            d["frequency"] = freq
            changes += 1
            log.append(f"#{did} {d['name']}: frequency «{old}» → «{freq}»")
        else:
            log.append(f"#{did} {d['name']}: frequency уже «{freq}» (no-op)")

    for did in COURSE_CLEAR:
        d = dmap.get(did)
        if d is None:
            continue
        if d.get("course_days"):
            old = d.get("course_days")
            d["course_days"] = None
            changes += 1
            log.append(f"#{did} {d['name']}: course_days «{old}» → None (курс в частоте)")
        else:
            log.append(f"#{did} {d['name']}: course_days уже пуст (no-op)")

    for did, fspec in FIELD_SET.items():
        d = dmap.get(did)
        if d is None:
            continue
        touched = False
        for k, v in fspec.items():
            if k == "src":
                continue
            if d.get(k) != v:
                d[k] = v
                touched = True
        if touched:
            changes += 1
            log.append(f"#{did} {d['name']}: поля {sorted(k for k in fspec if k != 'src')} ({fspec['src']})")
        else:
            log.append(f"#{did} {d['name']}: поля уже стоят (no-op)")

    for did, cspec in CONTRA_SET.items():
        d = dmap.get(did)
        if d is None:
            continue
        contra = d.setdefault("contraindications", {})
        touched = False
        for flag in ("pregnancy", "lactation"):
            if contra.get(flag) is not cspec[flag]:
                contra[flag] = cspec[flag]
                touched = True
        pca = cspec.get("pregnancy_contraindicated_animals")
        if pca is not None and d.get("pregnancy_contraindicated_animals") != pca:
            d["pregnancy_contraindicated_animals"] = pca
            touched = True
        if touched:
            changes += 1
            log.append(f"#{did} {d['name']}: pregnancy={contra.get('pregnancy')} "
                       f"lactation={contra.get('lactation')} ({cspec['src']})")
        else:
            log.append(f"#{did} {d['name']}: флаги уже стоят (no-op)")

    return changes, log


def dump(db: dict) -> bytes:
    return (json.dumps(db, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--check", action="store_true", help="dry-run: только отчёт")
    args = ap.parse_args()

    original = CANON.read_bytes()
    db = json.loads(original)
    changes, log = apply_fixes(db)

    for line in log:
        print(line)
    print(f"\nправок: {changes}")

    if args.check:
        print("--check: файл не тронут")
        return 0

    new_bytes = dump(db)
    if new_bytes == original:
        print("байт-в-байт с текущим файлом — запись не нужна")
        return 0

    CANON.write_bytes(new_bytes)
    print(f"записано: {CANON}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
