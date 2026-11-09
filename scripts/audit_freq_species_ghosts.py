#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""audit_freq_species_ghosts.py — скан «видов-призраков» в общей frequency.

Task 228 (2026-11-10, аудит старого): общая frequency (голосовой сценарий,
«до выбора вида») может упоминать вид, которого уже НЕТ в animals — хвосты
срезки видов (Task 227 резал animals, не регенерируя видовые сводки) и
артефакты копирования сводок (Task 225 раскатывал TILM_COMMON/FLOR_COMMON
на всё семейство, включая записи без соответствующих веток).

Read-only: НИЧЕГО не пишет. Не подключён к CI — находки разбираются
владельцем (регенерация сводок = правка данных, отдельной волной).
Выход: 0 — призраков нет; 1 — есть (отчёт выше); 2 — сломался сам скан.

Ложные срабатывания исключены осторожными паттернами: «курс» НЕ птица,
«который» НЕ кошка, «контакт» НЕ лошадь. Телята/котята/щенки считаются
молодью своего вида (Кошки/Собаки/КРС).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "assets" / "data" / "drugs_calc.json"

WORD2SPEC = [
    (re.compile(r"свинь|свиньям|свиней|поросят|подсвин", re.I), "Свиньи"),
    (re.compile(r"КРС|коров|телят|тёлоч|крупн\w*\s+рогат", re.I), "КРС"),
    (re.compile(r"МРС|овц|коз\B|баран", re.I), "МРС"),
    (re.compile(r"кошк|котят|\bкот(ам|ов|ах|ы|а)\b", re.I), "Кошки"),
    (re.compile(r"собак|сукам|щенк|\bпс(ам|ов|ы|а)\b", re.I), "Собаки"),
    (re.compile(r"лошад|жереб|мерин|\bкон(я|ей|ям|ях)\b", re.I), "Лошади"),
    (re.compile(r"птиц|бройлер|голуб", re.I), "Птица"),
    (re.compile(r"кролик", re.I), "Кролики"),
    (re.compile(r"пушн\w*\s+звер|норк\w*\b|собол", re.I), "Пушные звери"),
]


def main() -> int:
    try:
        data = json.loads(DATA.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(f"scan broken: {exc}")
        return 2
    recs = data["drugs_calc"]
    hits = []
    for r in recs:
        freq = r.get("frequency") or ""
        if not freq:
            continue
        animals = set(r.get("animals") or [])
        mentioned = {spec for rx, spec in WORD2SPEC if rx.search(freq)}
        ghost = mentioned - animals
        if ghost:
            branches = r.get("animal_specific") or {}
            own = "; ".join(
                f"{a.lower()}м — {br.get('frequency')}"
                for a, br in branches.items()
                if br.get("frequency")
            )
            hits.append((r.get("id"), r.get("name"), sorted(ghost), sorted(animals), freq, own))

    print(f"записей: {len(recs)}; призраков frequency-vs-animals: {len(hits)}")
    for rid, name, ghost, animals, freq, own in hits:
        print(f"  #{rid} {name} | animals={animals} | призраки={ghost}")
        print(f"      freq: {freq}")
        if own:
            print(f"      сводка своих веток (материал, не автоправка): {own}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
