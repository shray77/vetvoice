#!/usr/bin/env python3
"""Проверка Kotlin-файла: баланс блочных комментариев и скобок вне комментариев/строк.
Ловит досрочное закрытие /* */ последовательностью */ внутри текста комментария,
незакрытые комментарии и несбалансированные {} вне комментариев и строк."""
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()
i, n = 0, len(src)
depth = 0            # {} вне комментариев/строк
comment_open = False
line = 1
errors = []
block_starts = []    # позиции начала блочных комментариев
while i < n:
    ch = src[i]
    if ch == '\n':
        line += 1
        i += 1
        continue
    if comment_open:
        if src.startswith('*/', i):
            comment_open = False
            i += 2
            continue
        i += 1
        continue
    # вне комментария
    if src.startswith('//', i):
        # строчный комментарий — до конца строки
        j = src.find('\n', i)
        i = n if j == -1 else j
        continue
    if src.startswith('/*', i):
        comment_open = True
        block_starts.append(line)
        i += 2
        continue
    if ch == '"':
        # строка с учётом escape
        i += 1
        while i < n and src[i] != '"':
            if src[i] == '\\':
                i += 1
            elif src[i] == '\n':
                errors.append(f'line {line}: перевод строки внутри строкового литерала')
            i += 1
        i += 1
        continue
    if ch == "'":
        i += 1
        while i < n and src[i] != "'":
            if src[i] == '\\':
                i += 1
            i += 1
        i += 1
        continue
    if ch == '{':
        depth += 1
        i += 1
        continue
    if ch == '}':
        depth -= 1
        if depth < 0:
            errors.append(f'line {line}: лишняя закрывающая }}')
            depth = 0
        i += 1
        continue
    i += 1

if comment_open:
    errors.append('НЕЗАКРЫТЫЙ блочный комментарий (открыт на строке ' +
                  ', '.join(map(str, block_starts)) + ')')
if depth != 0:
    errors.append(f'итоговый баланс скобок вне комментариев: {depth} (ожидается 0)')

if errors:
    print('FAIL:', path)
    for e in errors:
        print('  -', e)
    sys.exit(1)
print(f'OK: {path} — комментарии закрыты, скобки вне комментариев сбалансированы ({{}}: баланс 0)')
