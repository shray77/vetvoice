// HistoryService — лог последних расчётов доз.
//
// Использует SharedPreferences для持久ного хранения.
// Хранит до 50 последних расчётов — этого достаточно для обычного дня ветврача.
//
// Структура записи:
//   {
//     "timestamp": 1692000000000,
//     "drug_id": 123,
//     "drug_name": "Мариния®",
//     "inn": "маропитант",
//     "animal": "Собаки",
//     "weight_kg": 12.5,
//     "dose_per_kg": 1.0,
//     "volume_ml": 2.5,
//     "method": "внутримышечно",
//     "frequency": "1 раз в день"
//   }
//
// В UI:
//   final histService = HistoryService();
//   await histService.init();
//   await histService.addCalculation(drug, weight, calculation);
//   final history = histService.history;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final int timestamp;
  final int drugId;
  final String drugName;
  final String inn;
  final String animal;
  final double weightKg;
  final double dosePerKg;
  final double volumeMl;
  final String method;
  final String frequency;

  const HistoryEntry({
    required this.timestamp,
    required this.drugId,
    required this.drugName,
    this.inn = '',
    required this.animal,
    required this.weightKg,
    this.dosePerKg = 0,
    required this.volumeMl,
    this.method = '',
    this.frequency = '',
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      drugId: (json['drug_id'] as num?)?.toInt() ?? 0,
      drugName: json['drug_name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      animal: json['animal'] as String? ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      volumeMl: (json['volume_ml'] as num?)?.toDouble() ?? 0,
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'drug_id': drugId,
        'drug_name': drugName,
        'inn': inn,
        'animal': animal,
        'weight_kg': weightKg,
        'dose_per_kg': dosePerKg,
        'volume_ml': volumeMl,
        'method': method,
        'frequency': frequency,
      };

  /// Человекочитаемая дата.
  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Человекочитаемый результат.
  String get formattedResult {
    if (volumeMl > 0) {
      final ml = volumeMl >= 10
          ? volumeMl.toStringAsFixed(1)
          : volumeMl.toStringAsFixed(2);
      return '$ml мл';
    }
    if (dosePerKg > 0) {
      return '$dosePerKg мг/кг';
    }
    return '—';
  }
}

class HistoryService extends ChangeNotifier {
  // v1.16.1: синглтон. Раньше result_card и history_screen держали разные
  // инстансы: если init() ещё не успел отработать — _prefs был null и
  // записи молча терялись (_prefs?.setString — no-op), история пустовала.
  HistoryService._internal();
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;

  static const String _key = 'vetvoice_history';
  static const int _maxEntries = 50;  // храним последние 50 расчётов

  List<HistoryEntry> _entries = [];

  // ⚠ Фикс VV-018 (ревью 26.11.2026): кеш Future<SharedPreferences>.
  // init() из UI вызывается БЕЗ await (result_card.dart), а _save() работал
  // через `_prefs?.` и до завершения getInstance() молча нет-опил: запись
  // жила только в памяти и пропадала после перезапуска. Теперь init() и
  // _save() ждут один и тот же Future — гонка исчезла без правок виджетов.
  // Неудача в кеше не оседает — повторный вызов ретраит.
  Future<SharedPreferences>? _prefsFuture;
  Future<void>? _initFuture;

  /// Единая точка доступа к SharedPreferences: один Future на сессию —
  /// его ждут и init(), и _save().
  Future<SharedPreferences> _getPrefs() {
    final cached = _prefsFuture;
    if (cached != null) return cached;
    final future = SharedPreferences.getInstance();
    return _prefsFuture = future.then(
      (prefs) => prefs,
      onError: (Object e) {
        _prefsFuture = null; // transient-сбой плагина — кеш сбрасываем
        throw e;
      },
    );
  }

  /// Список записей истории (новые — в начале).
  List<HistoryEntry> get history => List.unmodifiable(_entries);

  /// Инициализация — загрузка из SharedPreferences.
  ///
  /// VV-018: мемоизируется in-flight Future (не bool-флаг): параллельные
  /// init() разделяют одну загрузку, после успеха повторный вызов — no-op,
  /// после неудачи — ретрай.
  Future<void> init() {
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final future = _init();
    _initFuture = future;
    return future;
  }

  Future<void> _init() async {
    try {
      _loadHistory(await _getPrefs());
    } catch (e) {
      _initFuture = null; // неудача не мемоизируется — ретрай возможен
      rethrow;
    }
  }

  void _loadHistory(SharedPreferences prefs) {
    final json = prefs.getString(_key);
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List<dynamic>;
      _entries = list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('HistoryService: load error: $e');
      _entries = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    // VV-018: ждём тот же Future, что и init() — запись больше не теряется
    // в гонке «init() без await + мгновенный расчёт дозы».
    final prefs = await _getPrefs();
    final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, json);
  }

  /// Добавить расчёт в историю.
  Future<void> addCalculation({
    required int drugId,
    required String drugName,
    String inn = '',
    required String animal,
    required double weightKg,
    double dosePerKg = 0,
    required double volumeMl,
    String method = '',
    String frequency = '',
  }) async {
    final entry = HistoryEntry(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      drugId: drugId,
      drugName: drugName,
      inn: inn,
      animal: animal,
      weightKg: weightKg,
      dosePerKg: dosePerKg,
      volumeMl: volumeMl,
      method: method,
      frequency: frequency,
    );
    _entries.insert(0, entry);  // новые — сверху
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    await _save();
    notifyListeners();
  }

  /// Очистить всю историю.
  Future<void> clear() async {
    _entries.clear();
    await _save();
    notifyListeners();
  }

  /// Удалить конкретную запись.
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    await _save();
    notifyListeners();
  }
}
