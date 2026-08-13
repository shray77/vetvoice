import 'package:flutter/foundation.dart';

/// Срок ожидания для конкретного продукта (мясо, молоко, яйца)
class WithdrawalProduct {
  final int? meat;
  final int? milk;
  final dynamic eggs; // int или строка типа "НЕ ПРИМЕНЯТЬ"

  const WithdrawalProduct({
    this.meat,
    this.milk,
    this.eggs,
  });

  factory WithdrawalProduct.fromJson(Map<String, dynamic> json) {
    return WithdrawalProduct(
      meat: json['meat'] is int ? json['meat'] as int : null,
      milk: json['milk'] is int ? json['milk'] as int : null,
      eggs: json['eggs'],
    );
  }

  String formatMeat() => meat != null ? '$meat суток' : 'Не указан';
  String formatMilk() => milk != null ? '$milk суток' : 'Не указан';
  String formatEggs() => eggs is int ? '$eggs суток' : (eggs is String ? eggs : 'Не указан');
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

  /// Ищет по МНН
  WithdrawalEntry? findByInn(String inn) {
    final q = inn.toLowerCase();
    for (final d in drugs) {
      if (d.inn.toLowerCase() == q) return d;
    }
    // Частичное совпадение
    for (final d in drugs) {
      if (d.inn.toLowerCase().contains(q) || q.contains(d.inn.toLowerCase())) {
        return d;
      }
    }
    return null;
  }
}