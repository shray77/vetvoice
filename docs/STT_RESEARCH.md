# STT Research — Vosk и альтернативы для ветеринарного приложения

## Контекст

Приложение использует Vosk (`com.alphacephei:vosk-android:0.3.47`) с моделью
`vosk-model-small-ru-0.22` (45 МБ) для офлайн-распознавания русской речи.
Vosk плохо распознаёт медицинские термины (названия препаратов, МНН).

## Текущая реализация

### Wake word (VoskWakeWordService.kt)
- Модель: `vosk-model-small-ru-0.22` (45 МБ)
- URL: `https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip`
- SHA-256: `961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4`
- Скачивается при первом запуске, кешируется, обновляется раз в неделю
- Wake words: «ветвойс», «вет войс», «ветпомощь», «ветеринар», и т.п.
- Foreground service + Levenshtein для нечёткого матчинга

### Основное распознавание (speech_service.dart)
- Package: `speech_to_text: ^7.0.3`
- Использует системный STT Android (`android.speech.SpeechRecognizer`)
- Локаль: `ru_RU`
- Это **НЕ Vosk** — это Google/системный движок, требует онлайн

## Проблема

Vosk-small (45 МБ) обучена на общей русской речи, не знает:
- «маропитант», «флорфеникол», «амоксициллин», «энрофлоксацин»
- Диагнозы: «пиодермия», «демодекоз», «отодектоз»
- Торговые наименования: «Мариния», «Флорфорте», «БАРС»

## Сравнение альтернатив (open-source, офлайн, русский)

| Движок | Лицензия | RU-модели | Flutter | Адаптация под мед-термины |
|--------|----------|-----------|---------|---------------------------|
| **Vosk** | Apache 2.0 | ✅ 45 МБ / 1.8 ГБ | ✅ `vosk_flutter` | ⭐⭐⭐⭐⭐ словарь+LM+JSGF |
| **Sherpa-onnx** | Apache 2.0 | ✅ Zipformer-ru, GigaAM (MIT) | ✅ `sherpa_onnx` | ⭐⭐⭐ fine-tune через icefall |
| **Whisper.cpp** | MIT | ✅ tiny→large-v3 | ✅ `whisper_cpp_flutter_plus` | ⭐⭐ fine-tune (сложно, GPU) |
| Coqui STT | MPL-2.0 | ❌ заброшен (2024) | ❌ | — |
| Mozilla DeepSpeech | — | ❌ deprecated | ❌ | — |
| OpenWakeWord | MIT | ❌ только EN | ❌ | не STT |
| Picovoice Porcupine | ❌ закрытая | — | — | НЕ подходит |
| Android SpeechRecognizer | ❌ закрытый | ✅ | через platform channel | ❌ |

## Рекомендация: адаптировать Vosk, не менять

Vosk — правильный фундамент. Три уровня адаптации:

### Уровень 1 (быстрая победа, 1-2 дня)

**JSGF-грамматика** — добавить топ-500 вет. препаратов/МНН с произношением.
Можно в рантайме через `Recognizer.setGrammar()`:

```kotlin
val grammar = """
[
  маропитант
  флорфеникол
  амоксициллин
  энрофлоксацин
  триметоприм
  сульфаметоксазол
  ...
]
"""
recognizer.setGrammar(grammar)
```

После этого распознавание ограничится заданным списком — точность на
названиях препаратов станет почти 100%.

**Плюсы:**
- Не требует перекомпиляции модели
- Можно менять список в рантайме (новые препараты добавляются в drugs_calc.json)
- Малый размер (словарь — килобайты)

**Минусы:**
- Только для командного ввода (ограниченный словарь)
- Не подходит для свободной диктовки карточки пациента

### Уровень 2 (среднее усилие, 1 неделя + сервер)

**Перекомпиляция small-графа с мед-LM**:
1. Скачать `vosk-model-ru-0.22-compile.zip` с alphacephei.com
2. Собрать корпус вет. текстов (инструкции к препаратам, диагнозы)
3. Добавить тексты в `db/extra.txt`
4. Добавить произношения терминов в `db/extra.dic` (через Phonetisaurus)
5. Запустить `compile-graph.sh` (~15 мин, Linux 32 ГБ RAM)

**Эффект:** +20-40% точности на мед-лексике в свободной диктовке.

### Уровень 3 (апгрейд, 1-2 недели)

**Whisper.cpp или Sherpa-onnx как второй движок** для длинных диктовок
(карточка пациента). Vosk остаётся как wake word + короткие команды.

- **Whisper.cpp small** (466 МБ) — лучшая общая точность, пакетный режим
- **Sherpa-onnx GigaAM-v2** (MIT) — стриминг, SOTA на русском

Гибридная схема:
```
Vosk-small (45 МБ, wake word) → активация
    ↓
Sherpa-onnx GigaAM (200 МБ, стриминг STT) → транскрипция
    ↓
Fuzzy-matching по словарю МНН → исправление редких слов
```

### Уровень 4 (постобработка, 2-3 дня)

**Fuzzy-matching выхода любого движка** по справочнику МНН:
- Levenshtein distance
- Phonetic match (если доступно)
- Словарь: `drugs_calc.json` → `inn` поле

Например, Whisper выдал «маропитан» → исправляем на «маропитант»
(Levenshtein = 1, в словаре есть «маропитант»).

## Чего НЕ делать

- ❌ `vosk-model-ru-0.42` (1.8 ГБ) на телефоне — OOM, нужно 8-16 ГБ RAM
- ❌ Coqui STT — заброшен
- ❌ Mozilla DeepSpeech — deprecated
- ❌ Старый `nemo-ctc-giga-am-russian-2024-10-24` — non-commercial license.
  Только GigaAM-v2/v3 (MIT)
- ❌ OpenWakeWord для русского — только английский
- ❌ Android `SpeechRecognizer` как open-source — это Google-движок

## Источники

- [Vosk models](https://alphacephei.com/vosk/models)
- [Vosk language model adaptation](https://alphacephei.com/vosk/lm)
- [Sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache 2.0)
- [Whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT)
- [GigaAM-v2 (MIT)](https://github.com/salute-developers/GigaAM)
- [sherpa_onnx Flutter package](https://pub.dev/packages/sherpa_onnx)
- [whisper_cpp_flutter_plus](https://pub.dev/packages/whisper_cpp_flutter_plus)
- arXiv:2503.21025 — Vosk для мед-терминов
