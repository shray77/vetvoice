#!/usr/bin/env python3
"""Task 173 — контраст-гейт Material-токенов vet-ds v2.3.2 (голос A + характер).

Аналог scripts/contrast_v2.py ядра vet-ds (тот меряет CSS-токены витрин),
этот меряет DsLight/DsDark из lib/theme/ds.dart приложений. Правило DS:
текст >= AA (4.5:1) на bg/surface/surface2 в обеих темах. Проверяются:
текстовые роли, характер (акцент как текст/иконка), accent-ink на акценте
(кнопки), семантика статусов. Запуск: python3 scripts/ds_gate.py [vetvoice|veteco]
"""
import sys

def lum(hexv: str) -> float:
    r, g, b = (int(hexv[i:i+2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(fg: str, bg: str) -> float:
    l1, l2 = sorted((lum(fg), lum(bg)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)

# ── Ядро DS v2.3.2, голос A (одинаков в обоих приложениях) ──────────────────
A_LIGHT = dict(bg='FAF9F5', surface='FFFFFF', surface2='F1EEE6',
               text='1C1B1A', muted='5B564C', faint='6E695C',
               red='B3261E', green='47753A', amber='8A5A14', orange='AC4E18',
               blue='33608C', violet='6D4FC4')
A_DARK = dict(bg='211E19', surface='2A2620', surface2='34302A',
              text='EDE9E0', muted='B8B1A3', faint='9E9789',
              red='E87963', green='8DB96F', amber='D9A24A', orange='E08A4F',
              blue='82A9CC', violet='B9A5E3')

# Характер приложения: (light accent, strong, ink; dark accent, strong, ink)
CHARACTERS = {
    'vetvoice': dict(
        name='VetVoice — зелёный бренда (5-е применение паттерна)',
        light=dict(accent='097A38', strong='087534', ink='F2FBF5'),
        dark=dict(accent='3DDC7B', strong='5CE68F', ink='0A120C')),
    'veteco': dict(
        name='VetEco — бирюза Vet Teal, зеркально vet-insilico (6-е применение)',
        light=dict(accent='0F766E', strong='0C5D57', ink='F0FDFA'),
        dark=dict(accent='2DD4BF', strong='5EE3D4', ink='0A1B19')),
}

def check(app):
    ch = CHARACTERS[app]
    fails, worst = [], []
    def pair(name, fg, bg, need=4.5):
        r = ratio(fg, bg)
        worst.append((r, name))
        if r < need:
            fails.append(f"  FAIL {name}: {r:.2f}:1 (нужно {need})")

    for theme, tokens, accent in (('A-light', A_LIGHT, ch['light']),
                                  ('A-dark',  A_DARK,  ch['dark'])):
        surf = ['bg', 'surface', 'surface2']
        # Текстовые роли DS (значения ядра — должны быть зелёными по построению)
        for role in ('text', 'muted', 'faint'):
            for s in surf:
                pair(f'{theme} {role} × {s}', tokens[role], tokens[s])
        # Характер: акцент как текст/иконка на поверхностях
        for s in surf:
            pair(f'{theme} accent × {s}', accent['accent'], tokens[s])
        # Кнопка: ink на заливке акцентом
        pair(f'{theme} accentInk × accent (кнопка)', accent['ink'], accent['accent'])
        # Семантика статусов как текст
        for sem in ('red', 'green', 'amber', 'orange', 'blue'):
            for s in surf:
                pair(f'{theme} {sem} × {s}', tokens[sem], tokens[s])

    worst.sort(reverse=True)
    print(f"══ {app}: {ch['name']}")
    print(f"  пар проверено: {len(worst)}, AA-порог 4.5:1")
    print(f"  топ-5: " + ' | '.join(f"{n} {r:.2f}" for r, n in worst[:5]))
    if fails:
        print('\n'.join(fails))
        return False
    print('  ГЕЙТ ЗЕЛЁНЫЙ — все пары AA')
    return True

if __name__ == '__main__':
    apps = sys.argv[1:] or ['vetvoice']
    ok = all(check(a) for a in apps)
    sys.exit(0 if ok else 1)
