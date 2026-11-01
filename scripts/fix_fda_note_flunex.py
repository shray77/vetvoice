#!/usr/bin/env python3
"""Решение владельца (2026-11-02): сноски о зарубежных лейблах не нужны.

«Сноски я думаю не нужны, ибо всё-таки приложение под РФ идёт» — критерий
истины один: российская инструкция. Сравнительные сноски «по FDA иначе» в
UI и не строились (открытый пункт хвоста Task 224 закрыт этим решением);
здесь вычищается единственный остаток лейбл-волны Task 223 в данных —
FDA-цитата в заметке свиной ветки Флунекса #1918. Доза 2.2 мг/кг уже
живёт в структурированных полях (dose_per_kg/dose_min/dose_max), заметка
целиком состояла из ссылки «(FDA Flunazine-S: 1 мг/фунт IM)» — ключ notes
удаляется как пустой после снятия цитаты.

EMA-цитаты в заметках колистинов СОЗНАТЕЛЬНО не трогаем: это провенанс
дозировок (75 000 МЕ/кг/день через питьевую воду и т.п.), для которых нет
российских лейблов, а не сравнительные сноски «у них иначе»; в UI
калькулятора поле notes не рендерится вовсе (внутренняя гигиена данных).

Идемпотентен: повторный запуск — no-op (exit 0, «already clean»).
Канон: assets/data/drugs_calc.json (формат: indent=2, ensure_ascii=False,
завершающий \n — round-trip байт-в-байт).

Запуск: python3 scripts/fix_fda_note_flunex.py [--check]
  --check  только проверить, не переписывая файл (exit 1, если найдено).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DB = REPO / "assets" / "data" / "drugs_calc.json"

TARGET_ID = 1918  # Флунекс, флуниксин меглумин
TARGET_ANIMAL = "Свиньи"
FDA_MARK = "FDA"


def iter_problem_notes(db: dict) -> list[tuple[int, str, str]]:
    """Все (id, животное, notes) с FDA-упоминанием в повидовых заметках."""
    out = []
    for d in db.get("drugs_calc", []):
        spec = d.get("animal_specific") or {}
        for animal, branch in spec.items():
            if isinstance(branch, dict) and FDA_MARK in str(branch.get("notes", "")):
                out.append((d.get("id"), animal, branch["notes"]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="только проверить")
    args = ap.parse_args()

    raw = DB.read_text(encoding="utf-8")
    db = json.loads(raw)
    hits = iter_problem_notes(db)

    if not hits:
        print("already clean: FDA-упоминаний в повидовых заметках нет")
        return 0

    for drug_id, animal, note in hits:
        print(f"#{drug_id} [{animal}] notes: {note!r}")

    if args.check:
        print(f"check: найдено {len(hits)} — файл не переписывался")
        return 1

    for d in db["drugs_calc"]:
        if d.get("id") != TARGET_ID:
            continue
        spec = d.get("animal_specific") or {}
        branch = spec.get(TARGET_ANIMAL)
        if not isinstance(branch, dict):
            continue
        note = str(branch.get("notes", ""))
        if FDA_MARK not in note:
            continue
        # Снимаем цитату: «Свиньи: 2.2 мг/кг (FDA Flunazine-S: ...)» ->
        # «Свиньи: 2.2 мг/кг». Доза уже в структурированных полях, остаток —
        # тавтология вида «Свиньи: 2.2 мг/кг», ключ удаляем целиком.
        cleaned = note
        while "(" in cleaned and FDA_MARK in cleaned:
            start = cleaned.find("(")
            end = cleaned.find(")", start)
            if end == -1:
                break
            inner = cleaned[start + 1 : end]
            if FDA_MARK in inner:
                cleaned = (cleaned[:start] + cleaned[end + 1 :]).strip()
            else:
                break
        branch.pop("notes", None)  # остаток — тавтология дозы
        print(f"#{TARGET_ID} [{TARGET_ANIMAL}]: ключ notes удалён "
              f"(после снятия цитаты остаток {cleaned!r} — доза дублируется полями)")

    DB.write_text(json.dumps(db, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fixed: {len(hits)} заметка(и), файл переписан (round-trip формат сохранён)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
