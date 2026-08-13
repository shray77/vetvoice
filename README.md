# VetVoice AI

> **Ветеринарный справочник и калькулятор дозировок с голосовым управлением**
>
> Flutter-приложение для Android с офлайн-распознаванием русской речи (Vosk STT).

[![CI](https://github.com/shray77/vetvoice/actions/workflows/ci.yml/badge.svg)](https://github.com/shray77/vetvoice/actions/workflows/ci.yml)
[![Release APK](https://github.com/shray77/vetvoice/actions/workflows/release.yml/badge.svg)](https://github.com/shray77/vetvoice/actions/workflows/release.yml)
[![Sync from GitLab](https://github.com/shray77/vetvoice/actions/workflows/sync.yml/badge.svg)](https://github.com/shray77/vetvoice/actions/workflows/sync.yml)
[![Latest Release](https://img.shields.io/github/v/release/shray77/vetvoice?include_prereleases)](https://github.com/shray77/vetvoice/releases)

## 📱 О приложении

VetVoice AI — карманный ветеринарный справочник с калькулятором дозировок.
Помогает ветеринарам-студентам и практикующим врачам быстро рассчитать
дозу препарата по весу животного, проверить совместимость, найти
противопоказания и схему вакцинации.

### Возможности

- **🧮 Калькулятор дозировок** — расчёт по весу, концентрации и виду животного
  (2400+ препаратов)
- **🎤 Голосовое управление** — поиск препаратов и навигация голосом
  (Vosk offline STT, не нужен интернет)
- **💉 Вакцины** — отдельная модель с разовой дозой и фасовкой (617 вакцин)
- **🔍 Поиск по симптомам** — «рвота у собаки» → 5 противорвотных
- **📜 Протоколы лечения** — 124 протокола с препаратами и дозами
- **🧪 Проверка совместимости** — взаимодействия препаратов с цветовой
  кодировкой по severity
- **🐄 Калькулятор каренции** — когда молоко/мясо безопасно после препарата
- **⭐ Избранное** и **🕒 История расчётов** (SharedPreferences)
- **🎨 Цветовая кодировка** по 17 категориям
- **🌓 Тёмная тема** (OLED-чёрный, 3 режима)

### Поддерживаемые виды животных

🐕 Собаки, 🐈 Кошки, 🐄 КРС, 🐑 МРС, 🐷 Свиньи, 🐴 Лошади, 🐇 Кролики,
🦊 Пушные звери, 🐔 Птица, 🐝 Пчёлы

## 📥 Скачать APK

Последнюю версию можно скачать на странице [Releases](https://github.com/shray77/vetvoice/releases).

```bash
# Прямая ссылка на последний релиз
https://github.com/shray77/vetvoice/releases/latest
```

APK собирается автоматически через GitHub Actions при пуше тега `v*`.
Подпись release-ключом — если задан секрет `ANDROID_KEYSTORE_BASE64`.

## 🚀 Быстрый старт

### Требования
- Flutter 3.27.0+
- Dart 3.5.0+
- Android SDK 24+ (минимальная версия)
- Java 17

### Запуск из исходников

```bash
git clone https://github.com/shray77/vetvoice.git
cd vetvoice
flutter pub get
flutter run
```

### Сборка release APK

```bash
flutter build apk --release --no-tree-shake-icons
# APK в build/app/outputs/flutter-apk/app-release.apk
```

### Сборка через GitHub Actions

```bash
# Создать тег и запушить
git tag v1.15.0+18
git push origin v1.15.0+18

# Или через Actions UI: Run workflow → выбрать версию
```

## 🗂️ Структура проекта

```
vetvoice/
├── lib/
│   ├── main.dart                    # Точка входа, ThemeService
│   ├── models/                      # Модели данных
│   │   ├── calc_drug.dart           # Основная модель препарата
│   │   ├── vaccine_specific.dart    # 🆕 Вакцины (single_dose, vials)
│   │   ├── drug.dart                # Пол/беременность/возраст
│   │   └── ...
│   ├── screens/                     # Экраны UI
│   │   ├── home_screen.dart         # Главный экран + TopBar
│   │   ├── symptom_search_screen.dart   # 🔍 Sprint 2
│   │   ├── treatment_protocols_screen.dart  # 📜 Sprint 2
│   │   ├── interactions_checker_screen.dart  # 🧪 Sprint 2
│   │   ├── withdrawal_calculator_screen.dart # 🐄 Sprint 2
│   │   ├── favorites_screen.dart    # ⭐ Sprint 1
│   │   ├── history_screen.dart      # 🕒 Sprint 1
│   │   ├── settings_screen.dart     # ⚙️ Sprint 1
│   │   └── ...
│   ├── services/                    # Сервисы
│   │   ├── speech_service.dart      # Speech-to-Text (speech_to_text package)
│   │   ├── wake_word_service.dart   # Vosk wake word (MethodChannel)
│   │   ├── favorites_service.dart   # SharedPreferences
│   │   ├── history_service.dart     # SharedPreferences
│   │   ├── theme_service.dart       # ThemeMode
│   │   ├── symptom_search_service.dart  # 🔍 Sprint 2
│   │   └── ...
│   ├── providers/vet_provider.dart  # State management
│   ├── utils/app_theme.dart         # Тема + цвета категорий
│   └── widgets/                     # Переиспользуемые виджеты
│       ├── vaccine_card.dart        # 💉 Карточка вакцины
│       ├── drug_dropdown.dart       # Выбор препарата с цветовой кодировкой
│       └── ...
├── android/
│   └── app/src/main/kotlin/com/vetvoice/vetvoice/
│       ├── MainActivity.kt
│       └── VoskWakeWordService.kt   # Vosk wake word (Kotlin, native)
├── assets/data/                     # JSON базы данных
│   ├── drugs_calc.json              # 2401 препарат (v7.6)
│   └── advanced/
│       ├── drug_interactions.json   # Взаимодействия
│       ├── treatment_protocols.json # 124 протокола
│       ├── withdrawal_by_product.json  # Каренция
│       └── ...
├── .github/workflows/
│   ├── ci.yml                       # Линтинг + тесты
│   ├── release.yml                  # Сборка APK + GitHub Releases
│   └── sync.yml                     # Зеркало с GitLab
└── pubspec.yaml
```

## 🎤 Vosk — голосовое распознавание

Приложение использует [Vosk](https://alphacephei.com/vosk/) для
офлайн-распознавания русской речи:

- **Библиотека:** `com.alphacephei:vosk-android:0.3.47`
- **Модель:** `vosk-model-small-ru-0.22` (45 МБ, скачивается при первом запуске)
- **Wake word:** «ВетВойс», «вет помощь», «ветеринар»
- **Лицензия:** Apache 2.0 (open-source)

### Как работает

1. При первом включении wake word — скачивается модель (~45 МБ) с
   alphacephei.com, кешируется, обновляется раз в неделю
2. Wake word слушает микрофон постоянно (foreground service)
3. После wake word — основное распознавание через `speech_to_text` package
   (использует системный STT Android)

### Адаптация под мед-термину

Vosk плохо распознает «маропитант», «флорфеникол» и т.п. Планируется
подключить JSGF-грамматику с топ-500 вет. препаратов — это можно сделать
в рантайме без перекомпиляции модели.

Подробнее см. в `docs/STT_RESEARCH.md`.

## 📊 Источники данных

База препаратов `drugs_calc.json` (v7.6, 2401 препарат) валидируется по:

| Источник | Что даёт | Тип доступа |
|----------|----------|-------------|
| **fsvps.gov.ru** | Государственный реестр ЛС (2347 препаратов) | Открытые данные (CSV) |
| **vetprotocol.ru** | 434 препарата по МНН | Парсинг HTML |
| **vetlek.ru** | 1337 инструкций | Парсинг HTML (cp1251) |
| **vidal.ru/veterinar** | Справочник Видаль | Парсинг HTML |

Парсеры и валидатор: [`shray77/vetvoice-parsers`](https://github.com/shray77/vetvoice-parsers)

## 🔄 Зеркало GitLab ↔ GitHub

- **Основной репозиторий:** [gitlab.com/shray77/vetvoice](https://gitlab.com/shray77/vetvoice)
- **GitHub зеркало:** [github.com/shray77/vetvoice](https://github.com/shray77/vetvoice)

GitHub Actions каждые 6 часов синхронизирует main с GitLab через
`sync.yml` workflow. Ветки и теги на GitHub не пушатся (только main).

## 📜 Лицензия

MIT — см. [LICENSE](LICENSE).

## 🙏 Благодарности

- [Vosk](https://alphacephei.com/vosk/) — офлайн STT
- [alphacephei.com](https://alphacephei.com/vosk/models) — русская модель
- [fsvps.gov.ru](https://fsvps.gov.ru) — Открытые данные Россельхознадзора
- [vetprotocol.ru](https://vetprotocol.ru), [vetlek.ru](https://www.vetlek.ru) — справочники
