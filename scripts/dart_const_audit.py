#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dart_const_audit.py — аудит const-выражений в Dart-коде VetVoice.

ЗАЧЕМ (Release APK #45): `const Text(style: TextStyle(color: AppTheme.textTertiary))`
компилируется `dart analyze`... и падает на AOT-компиляции — AppTheme.textTertiary
это theme-aware ГЕТТЕР (runtime), а не const. Локального Flutter SDK в
окружении нет, analyze недоступен, поэтому единственная защита до CI —
статический скрипт.

ЧТО ЛОВИТ:
  1. AppTheme.<getter> внутри span'а const-выражения (геттеры, а не const-поля).
  2. --balance: дисбаланс скобок ()[]{} по файлу (строки и комментарии игнорируются).

ГРАНИЦЫ (упрощения, задокументированы сознательно):
  - содержимое строковых литералов пропускается целиком, вместе с
    интерполяцией ${...} (в нашем коде геттеры внутри const-интерполяции
    не встречаются; false-negative здесь не критичны — CI добьёт);
  - `const` без последующей скобки/литерала (объявления `const int x = 5;`)
    не проверяются.

Запуск:  python3 scripts/dart_const_audit.py lib/ [--balance]
Выход:   0 — чисто, 1 — есть находки (для CI-гейта в будущем).
"""
import re
import sys
from pathlib import Path

# Theme-aware геттеры AppTheme (не константы!) + методы.
GETTERS = {
    'white', 'surface', 'background', 'backgroundGray', 'fieldFill',
    'dividerGray', 'outlineVariant', 'textPrimary', 'textSecondary',
    'textTertiary', 'isDarkNow', 'softShadow', 'greenGlow',
    'lightTheme', 'darkTheme', 'getCategoryColor', 'getCategoryIcon',
    'getTheme',
}

PAIRS = {')': '(', ']': '[', '}': '{'}


def strip_strings_comments(src: str):
    """Заменяет содержимое строк и комментариев пробелами, сохраняя длину
    и построчную структуру (номера строк валидны и после замены).

    Интерполяция ${...} обрабатывается НАСТОЯЩИМ стейт-машином: внутри
    интерполяции снова код (в т.ч. вложенные строки с кавычками —
    классика 'd['field']' в export-сервисах). Скобки интерполяции
    считаются кодом и в баланс входят."""
    out = list(src)
    n = len(src)
    i = 0
    state = 'code'          # code | line_comment | block_comment | string
    quote = ''
    triple = False
    brace_depth = 0         # глубина {} в коде (включая интерполяцию)
    # стек ${...}: (глубина на входе, кавычка и triple объемлющей строки) —
    # кавычку НУЖНО восстанавливать: '…join(", ")…' — после закрытия
    # двойной строки внутри интерполяции текущая quote == '"', и без
    # восстановления одинарная объемлющая строка никогда не закроется.
    interp_stack = []
    while i < n:
        c = src[i]
        if state == 'code':
            if c == '/' and i + 1 < n and src[i + 1] == '/':
                state = 'line_comment'
                out[i] = ' '
                i += 1
            elif c == '/' and i + 1 < n and src[i + 1] == '*':
                state = 'block_comment'
                out[i] = ' '
                i += 1
            elif c in ('"', "'"):
                quote = c
                if src[i:i + 3] == c * 3:
                    triple = True
                    out[i] = out[i + 1] = out[i + 2] = ' '
                    i += 3
                else:
                    triple = False
                    out[i] = ' '
                    i += 1
                state = 'string'
            elif c in '([{':
                if c == '{':
                    brace_depth += 1
                i += 1
            elif c in ')]}':
                if c == '}' and interp_stack and brace_depth == interp_stack[-1][0]:
                    # закрывающая скобка ${...} — возвращаемся в строку
                    _, quote, triple = interp_stack.pop()
                    state = 'string'
                    out[i] = ' '
                    i += 1
                else:
                    if c == '}':
                        brace_depth -= 1
                    i += 1
            else:
                i += 1
        elif state == 'line_comment':
            if c == '\n':
                state = 'code'
            else:
                out[i] = ' '
            i += 1
        elif state == 'block_comment':
            if c == '*' and i + 1 < n and src[i + 1] == '/':
                out[i] = out[i + 1] = ' '
                i += 2
                state = 'code'
            else:
                if c != '\n':
                    out[i] = ' '
                i += 1
        else:  # string
            if c == '\\' and i + 1 < n:
                out[i] = out[i + 1] = ' '
                i += 2
            elif c == '$' and i + 1 < n and src[i + 1] == '{':
                interp_stack.append((brace_depth, quote, triple))
                out[i] = out[i + 1] = ' '
                i += 2
                state = 'code'
            elif not triple and c == quote:
                out[i] = ' '
                i += 1
                state = 'code'
            elif triple and src[i:i + 3] == quote * 3:
                out[i] = out[i + 1] = out[i + 2] = ' '
                i += 3
                state = 'code'
            else:
                if c != '\n':
                    out[i] = ' '
                i += 1
    return ''.join(out)


def const_spans(code: str):
    """[(start, end)] — span'ы const-выражений по очищенному коду."""
    spans = []
    for m in re.finditer(r'\bconst\b', code):
        i = m.end()
        n = len(code)
        # пропускаем пробелы
        while i < n and code[i].isspace():
            i += 1
        if i >= n:
            continue
        # явный литерал: const [...], const {...}
        if code[i] in '[{':
            opener = code[i]
        else:
            # идентификатор/дженерики до первой открывающей скобки
            j = i
            while j < n and code[j] not in '([{,;=)\n':
                j += 1
            if j >= n or code[j] not in '([{':
                continue  # объявление без конструктора/литерала
            opener = code[j]
            i = j
        depth = 0
        j = i
        while j < n:
            ch = code[j]
            if ch in '([{':
                depth += 1
            elif ch in ')]}':
                depth -= 1
                if depth == 0:
                    if PAIRS[ch] == opener:
                        spans.append((m.start(), j + 1))
                    break
            j += 1
    return spans


def audit_file(path: Path):
    findings = []
    raw = path.read_text(encoding='utf-8')
    code = strip_strings_comments(raw)
    line_starts = [0]
    for idx, ch in enumerate(raw):
        if ch == '\n':
            line_starts.append(idx + 1)

    def line_of(off):
        lo, hi = 0, len(line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if line_starts[mid] <= off:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    for start, end in const_spans(code):
        window = code[start:end]
        for gm in re.finditer(r'AppTheme\.(\w+)', window):
            name = gm.group(1)
            if name in GETTERS:
                findings.append(
                    (line_of(start + gm.start()),
                     f'AppTheme.{name} внутри const-выражения'))

    if '--balance' in sys.argv:
        depth = {'(': 0, '[': 0, '{': 0}
        for ch in code:
            if ch in depth:
                depth[ch] += 1
            elif ch in PAIRS:
                depth[PAIRS[ch]] -= 1
        bad = {k: v for k, v in depth.items() if v != 0}
        if bad:
            findings.append((0, f'дисбаланс скобок: {bad}'))
    return findings


def main():
    roots = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not roots:
        roots = ['lib']
    problems = 0
    for root in roots:
        for path in sorted(Path(root).rglob('*.dart')):
            for line, msg in audit_file(path):
                print(f'{path}:{line}: {msg}')
                problems += 1
    if problems == 0:
        print('const-audit: чисто (0 находок)')
        return 0
    print(f'const-audit: {problems} находок — const нужно снять')
    return 1


if __name__ == '__main__':
    sys.exit(main())
