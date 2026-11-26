import 'package:flutter/foundation.dart';

/// Срок ожидания для конкретного продукта (мясо, молоко, яйца)
class WithdrawalProduct {
  // ⚠ Фикс (ревью 26.11.2026, VV-006): meat/milk в базе бывают не только
  // числом суток, но и СТРОКОВЫМ запретом — «ЗАПРЕЩЁН» (хлорамфеникол),
  // «НЕ ДЛЯ ДОЙНЫХ!» (тилмикозин, флорфеникол, ивермектин… 10 записей) —
  // всего 24 строковых значения. Прежний `is int` превращал запреты в null,
  // formatMeat()/formatMilk() печатали «Не указан»: ЯВНЫЙ запрет читался
  // врачом как «ограничений нет» — это опасно. Теперь, как и у eggs, храним
  // сырое значение базы и форматируем честно (см. _format).
  final dynamic meat; // int суток или строка-запрет («ЗАПРЕЩЁН»)
  final dynamic milk; // int суток или строка-запрет («НЕ ДЛЯ ДОЙНЫХ!»)
  final dynamic eggs; // int или строка типа «НЕ ПРИМЕНЯТЬ несушкам!»

  const WithdrawalProduct({
    this.meat,
    this.milk,
    this.eggs,
  });

  factory WithdrawalProduct.fromJson(Map<String, dynamic> json) {
    return WithdrawalProduct(
      meat: json['meat'],
      milk: json['milk'],
      eggs: json['eggs'],
    );
  }

  String formatMeat() => _format(meat);
  String formatMilk() => _format(milk);
  String formatEggs() => _format(eggs);

  /// int → «N суток», String → дословно как в базе, null/иное → «Не указан».
  static String _format(dynamic v) =>
      v is int ? '$v суток' : (v is String ? v : 'Не указан');
}

/// Запись срока ожидания по МНН
class WithdrawalEntry {
  final String inn;
  final Map<String, WithdrawalProduct> products;
  final String notes;

  const WithdrawalEntry({
    required this.inn,
    required this.products,
    required this.notes,
  });

  factory WithdrawalEntry.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'] as Map<String, dynamic>? ?? {};
    final products = <String, WithdrawalProduct>{};
    rawProducts.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        products[key] = WithdrawalProduct.fromJson(value);
      }
    });
    return WithdrawalEntry(
      inn: json['inn'] as String? ?? '',
      products: products,
      notes: json['notes'] as String? ?? '',
    );
  }

  /// Ищет срок ожидания для конкретного вида и продукта
  String? findWithdrawal(String species, String productType) {
    final sp = products[species];
    if (sp == null) return null;
    switch (productType) {
      case 'meat': return sp.formatMeat();
      case 'milk': return sp.formatMilk();
      case 'eggs': return sp.formatEggs();
      default: return null;
    }
  }
}

/// База сроков ожидания
class WithdrawalDatabase {
  final List<WithdrawalEntry> drugs;
  final Map<String, List<String>> specialNotes;

  const WithdrawalDatabase({
    required this.drugs,
    required this.specialNotes,
  });

  factory WithdrawalDatabase.fromJson(Map<String, dynamic> json) {
    final list = <WithdrawalEntry>[];
    final raw = json['drugs'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(WithdrawalEntry.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ WithdrawalEntry #$i parse error: $e');
        }
      }
    }
    final notes = <String, List<String>>{};
    final snRaw = json['special_notes'];
    if (snRaw is Map) {
      snRaw.forEach((k, v) {
        if (v is List) {
          notes[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }
    return WithdrawalDatabase(drugs: list, specialNotes: notes);
  }

  /// Ищет по МНН.
  ///
  /// ⚠ Фикс (ревью 26.11.2026, VV-029): составные МНН в drugs_calc пишутся
  /// и через запятую, и через « + » («сульфадоксин + триметоприм»,
  /// «празиквантел, оксфендазол»), а здесь — через «+» без пробелов.
  /// Прежнее сравнение строк теряло такие пары. Порядок приоритета:
  ///  1) точное совпадение множества компонентов (разделители не важны);
  ///  2) компоненты записи ⊆ компоненты запроса — монопрепарат/комбинация
  ///     внутри составного МНН; берём запись с максимумом компонентов
  ///     (самую близкую к составу препарата: «фебантел, пирантел,
  ///     празиквантел» → «празиквантел+пирантел+фебантел», не голый
  ///     «празиквантел»);
  ///  3) прежнее поведение — вхождение подстроки в обе стороны (ловит
  ///     словоформы: «хлортетрациклина» ⊃ «хлортетрациклин»).
  WithdrawalEntry? findByInn(String inn) {
    final q = _innComponents(inn);
    if (q.isEmpty) return null;
    for (final d in drugs) {
      final dc = _innComponents(d.inn);
      if (dc.length == q.length && q.containsAll(dc)) return d;
    }
    WithdrawalEntry? best;
    int bestLen = 0;
    for (final d in drugs) {
      final dc = _innComponents(d.inn);
      if (dc.isEmpty || dc.length > q.length) continue;
      if (q.containsAll(dc) && dc.length > bestLen) {
        best = d;
        bestLen = dc.length;
      }
    }
    if (best != null) return best;
    final raw = inn.toLowerCase();
    for (final d in drugs) {
      final dbInn = d.inn.toLowerCase();
      if (dbInn.contains(raw) || raw.contains(dbInn)) return d;
    }
    return null;
  }

  /// Компоненты МНН: нижний регистр, ё→е, разделители «,»/«+»/«;»/скобки →
  /// пробел, сплит по пробелам. Множество: порядок компонентов составного
  /// МНН не фиксирован («пирантел, празиквантел» vs «празиквантел+пирантел»).
  static Set<String> _innComponents(String inn) {
    final flat = inn
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[,+;()]'), ' ');
    return flat
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
  }
}