#!/usr/bin/env python3
"""
Task 229 (2026-11-10): микро-волна «видов-призраков» frequency.

Решение владельца: «давай все кроме 4» (компонент 1 меню Task 228) —
мораторий «пока не трогаем» снят точечно для трёх находок скана
audit_freq_species_ghosts.py (Task 228): общая frequency упоминает вид,
которого нет в animals.

Правки (честные сводки собственных веток, без выдумывания):
1. #2034 Флорон® 30% — «КРС — однократно (п/к) или дважды с интервалом
   48 ч (в/м); свиньям — дважды с интервалом 48 ч» → «двукратно с
   интервалом 48 часов». Хвост срезки Task 227 (КРС убран из animals по
   госреестру: только свиньи); своя ветка Свиней уже несёт эту формулировку.
2. #936 ТИЛМОСТИМ 25% — «свиньям — однократно; телятам и птице —
   ежедневно, 3-5 дней» → «свиньям — однократно; птице — ежедневно».
   Артефакт раскатки TILM_COMMON (Task 225) на запись без вида/ветки
   КРС. «Ежедневно», а не «1 раз в день» (как в ветке Птицы): такова
   семейная конвенция сводок (TILM_COMMON, Тилмипул), и общая строка с
   «N раз в день» задевала бы species-blind freq-la-гейт валидатора
   (regexp «N раз в день/сутки» против повидовой «однократно», клаузулы
   по видам не разбираются).
3. #1497 Джоветил — аналогично #936.

course_days («3-5 дней») не тронуты: курс птицы живёт в них, длина курса
не менялась (прецедент Тилмакс #37: frequency «однократно» + course_days
«3-5 дней»).

Сопровождение: fix_freq_la_2026-11-02.py дефусирован в этой же волне —
#2034 убран из FLOR_INJ, #936/#1497 из TILM: слепой повторный прогон
скрипта Task 225 вернул бы призраков (ожидания устарели).

Идемпотентен: повторный запуск — no-op. --check — dry-run с отчётом.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

CANON = Path(__file__).resolve().parent.parent / "assets" / "data" / "drugs_calc.json"

FREQ_SET = {
    2034: ("Флорон® 30%",
           "КРС — однократно (п/к) или дважды с интервалом 48 ч (в/м); свиньям — дважды с интервалом 48 ч",
           "двукратно с интервалом 48 часов",
           "хвост срезки КРС (Task 227, госреестр: только свиньи); сводка своей ветки"),
    936: ("ТИЛМОСТИМ 25%",
          "свиньям — однократно; телятам и птице — ежедневно, 3-5 дней",
          "свиньям — однократно; птице — ежедневно",
          "артефакт TILM_COMMON (Task 225): телята без вида/ветки КРС; «ежедневно» — конвенция сводок, не задевает freq-la-гейт"),
    1497: ("Джоветил",
           "свиньям — однократно; телятам и птице — ежедневно, 3-5 дней",
           "свиньям — однократно; птице — ежедневно",
           "артефакт TILM_COMMON (Task 225): телята без вида/ветки КРС; «ежедневно» — конвенция сводок, не задевает freq-la-гейт"),
}


def apply_fixes(db: dict) -> tuple[int, list[str]]:
    changes = 0
    log: list[str] = []
    drugs = db["drugs_calc"] if "drugs_calc" in db else db
    dmap = {d["id"]: d for d in drugs}

    for did, (name, old, new, why) in FREQ_SET.items():
        d = dmap.get(did)
        if d is None:
            log.append(f"#{did} {name} НЕ НАЙДЕН — пропущен")
            continue
        current = d.get("frequency")
        if current == new:
            log.append(f"#{did} {name}: frequency уже «{new}» (no-op)")
        elif current == old:
            d["frequency"] = new
            changes += 1
            log.append(f"#{did} {name}: frequency «{old}» → «{new}» ({why})")
        else:
            log.append(f"#{did} {name}: frequency «{current}» ≠ ожидаемой «{old}» — НЕ ТРОНУТ (разобрать)")
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
