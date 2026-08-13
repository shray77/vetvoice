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
  static const String _key = 'vetvoice_history';
  static const int _maxEntries = 50;  // храним последние 50 расчётов

  SharedPreferences? _prefs;
  List<HistoryEntry> _entries = [];

  /// Список записей истории (новые — в начале).
  List<HistoryEntry> get history => List.unmodifiable(_entries);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadHistory();
  }

  void _loadHistory() {
    final json = _prefs?.getString(_key);
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
    final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await _prefs?.setString(_key, json);
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
