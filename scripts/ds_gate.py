#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_gate.py — гейт Material-портов vet-ds против канонического среза.

v2 (Task 176, идея №7): гейт ПАРИТ lib/lib/theme/ds.dart против design/tokens.json
(срез ядра, синкается из vet-ds/vet-ds.css). До этого словари были
захардкожены в самом гейте и расходились с ds.dart молча (доказано:
border-strong v2.3.3 #857F6E не доехал ни до одного порта).

Правила:
  1. ДРЕЙФ: не-акцентные токены ds.dart должны совпадать с ядром
     (характер-тройка accent/accent-strong/accent-ink — территория
     приложения, гейтится контрастом, не сравнением).
  2. КОНТРАСТ AA 4.5:1: text/muted/faint × bg/surface/surface2;
     характер-акцент как текст/иконка × поверхности; accentInk × accent.
  3. §1.4.11 графика ≥3:1: borderStrong × поверхности (рамки инпутов),
     rule × bg (линейки) — паритет с contrast_v2.py ядра.

Запуск: python3 scripts/ds_gate.py    (exit 1 — дрейф или контраст)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = ROOT / "design" / "tokens.json"
DS_DART = ROOT / "lib/theme/ds.dart"

# класс ds.dart → тема ядра (срез tokens.json)
THEME_MAP = {'DsLight': 'root', 'DsDark': 'dark'}

AA = 4.5
GRAPHIC_AA = 3.0
ACCENT_TRIPLE = ("accent", "accentStrong", "accentInk")


def lum(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(fg, bg):
    l1, l2 = sorted((lum(fg), lum(bg)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


CLASS_RE = re.compile(r'abstract\s+final\s+class\s+(\w+)\s*\{')
COLOR_RE = re.compile(r'static\s+const\s+Color\s+(\w+)\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)')


def parse_ds_dart():
    """{класс: {токен: hex-6}} — только static const Color."""
    out = {}
    cur = None
    for line in DS_DART.read_text(encoding='utf-8').splitlines():
        m = CLASS_RE.search(line)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        m = COLOR_RE.search(line)
        if m and cur:
            out[cur][m.group(1)] = m.group(2)[-6:].upper()
    return out


def main():
    if not TOKENS.exists():
        sys.exit("нет design/tokens.json — синк из vet-ds (codegen.py --push-flutter)")
    if not DS_DART.exists():
        sys.exit("нет " + str(DS_DART))
    core = json.loads(TOKENS.read_text(encoding='utf-8'))
    core_v = core.get("version", "?")
    dart = parse_ds_dart()
    fails, pairs = [], []

    # 1. дрейф значений против ядра
    for cls, th in THEME_MAP.items():
        d = dart.get(cls)
        if d is None:
            fails.append(f"класс {cls} не найден в ds.dart")
            continue
        ct = core["themes"][th]
        for name, val in d.items():
            # camelCase → kebab: borderStrong→border-strong, surface2→surface2.
            # (Task 184: спец-ветки для этих форм были мёртвыми — регекс
            # уже даёт их, ветки были тождественными no-op. Task 198: шаблон
            # выровнен с вычищенными гейтами портов — раскладка больше не
            # регрессит мёртвыми ветками.)
            kebab = re.sub(r'([A-Z])', lambda m: '-' + m.group(1).lower(), name).lstrip('-')
            if name in ACCENT_TRIPLE:
                continue                    # характер приложения
            if kebab in ct and ct[kebab][1:].upper() != val:
                fails.append(f"ДРЕЙФ {cls}.{name}: #{val} ≠ ядро #{ct[kebab][1:].upper()}"
                             f" (v{core_v})")

    # 2/3. контраст на ЗНАЧЕНИЯХ ds.dart (как рендерит приложение)
    def pair(name, fg, bg, need=AA):
        r = ratio(fg, bg)
        pairs.append((r, name))
        if r < need:
            fails.append(f"КОНТРАСТ {name}: {r:.2f}:1 (нужно {need})")

    for cls, th in THEME_MAP.items():
        d = dart.get(cls)
        if not d:
            continue
        surf = [d.get(k) for k in ("bg", "surface", "surface2") if d.get(k)]
        label = cls
        for role in ("text", "muted", "faint"):
            for s in surf:
                if d.get(role):
                    pair(f"{label} {role} × bg-поверхность", d[role], s)
        for s in surf:
            if d.get("accent"):
                pair(f"{label} accent × поверхность (текст/иконка)", d["accent"], s)
        if d.get("accentInk") and d.get("accent"):
            pair(f"{label} accentInk × accent (кнопка)", d["accentInk"], d["accent"])
        for sem in ("red", "green", "amber", "orange", "blue", "violet"):
            for s in surf:
                if d.get(sem):
                    pair(f"{label} {sem} × поверхность", d[sem], s)
        for s in surf:
            if d.get("borderStrong"):
                pair(f"{label} borderStrong × поверхность (§1.4.11)",
                     d["borderStrong"], s, GRAPHIC_AA)
        if d.get("rule") and d.get("bg"):
            pair(f"{label} rule × bg (§1.4.11)", d["rule"], d["bg"], GRAPHIC_AA)

    pairs.sort(reverse=True)
    print(f"ds_gate v2 · ядро v{core_v} · ds.dart: {len(dart)} класс(а), "
          f"пар: {len(pairs)}")
    if pairs:
        print("  топ-5: " + " | ".join(f"{n} {r:.2f}" for r, n in pairs[:5]))
    if fails:
        print("\n".join("  ✗ " + f for f in fails))
        print(f"\n✗ {len(fails)} нарушений — гейт красный")
        return 1
    print("✓ дрейфа нет, все пары зелёные — ds.dart синхронен с ядром v" + core_v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
