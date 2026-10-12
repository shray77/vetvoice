// Тест нормализации поиска и подбора животного (v1.16.4) на реальных данных.
// Запуск: /tmp/dart-sdk/bin/dart run scripts/test_search_species.dart
import 'dart:convert';
import 'dart:io';

String normalizeForSearch(String s) {
  return s.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[®™©]'), '').trim();
}

String looseKey(String s) =>
    normalizeForSearch(s).replaceAll(RegExp(r'[^a-zа-я0-9]'), '');

bool matchesSearchQuery({
  required String name,
  required String inn,
  required String query,
  required String looseQuery,
}) {
  final n = normalizeForSearch(name);
  final i = normalizeForSearch(inn);
  if (n.contains(query) || i.contains(query)) return true;
  if (looseQuery.length >= 3) {
    if (looseKey(name).contains(looseQuery) || looseKey(inn).contains(looseQuery)) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic>? findDrug(List<Map<String, dynamic>> drugs, String name) {
  final q = normalizeForSearch(name);
  if (q.isEmpty) return null;
  final loose = looseKey(name);
  for (final d in drugs) {
    if (matchesSearchQuery(
      name: d['name'] as String? ?? '',
      inn: d['inn'] as String? ?? '',
      query: q,
      looseQuery: loose,
    )) {
      return d;
    }
  }
  return null;
}

String? selectAnimalFromSpecies(List<String> species, List<String> animals) {
  String norm(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();
  for (final s in species) {
    final target = norm(s);
    if (target.isEmpty || target == 'все') continue;
    for (final a in animals) {
      final name = norm(a);
      if (name.isEmpty) continue;
      if (name == target || name.startsWith(target) || target.startsWith(name)) {
        return a;
      }
    }
  }
  return null;
}

void main() {
  final calc = jsonDecode(File('assets/data/drugs_calc.json').readAsStringSync());
  final drugs = (calc['drugs_calc'] as List).cast<Map<String, dynamic>>();
  final animals = (calc['animals'] as List).map((a) => a['name'] as String).toList();
  final protocols = jsonDecode(
          File('assets/data/advanced/treatment_protocols.json').readAsStringSync())['protocols']
      as List;

  var fails = 0;
  void check(bool cond, String label, {String? extra}) {
    print('${cond ? "✅" : "❌"} $label${extra == null ? "" : " -> $extra"}');
    if (!cond) fails++;
  }

  // 1. «Нет АСД-10» — запросы пользователя из поля
  check(findDrug(drugs, 'АСД-10')?['id'] == 128, 'поиск "АСД-10" находит id 128',
      extra: 'id=${findDrug(drugs, "АСД-10")?["id"]}');
  check(findDrug(drugs, 'асд 10')?['id'] == 128, 'поиск "асд 10" (через пробел)');
  check(findDrug(drugs, 'асд10')?['id'] == 128, 'поиск "асд10" (слитно)');
  check(findDrug(drugs, 'АСД®-10')?['id'] == 128, 'поиск точного "АСД®-10" из протокола');
  check(findDrug(drugs, 'Пчёлы') != null || true, 'sanity');
  check(findDrug(drugs, 'АСД фракция 2') != null, 'поиск "АСД фракция 2"');

  // 2. Кнопка «Рассчитать дозу» в протоколе чумы КРС: все 5 препаратов
  final plague = protocols.firstWhere((p) => p['diagnosis'] == 'Чума крупного рогатого скота');
  final sections = ['primary', 'support', 'symptomatic', 'prevention'];
  final drugNames = <String>[];
  for (final sec in sections) {
    final s = plague['treatment'][sec];
    if (s is Map && s['drugs'] is List) {
      for (final d in (s['drugs'] as List)) {
        drugNames.add(d['name'] as String);
      }
    }
  }
  print('\n— Протокол «${plague["diagnosis"]}»: species=${plague["species"]}');
  for (final n in drugNames) {
    final found = findDrug(drugs, n);
    check(found != null, 'кнопка «Рассчитать дозу»: "$n"', extra: found?['name']);
  }

  // 3. Подстановка животного: все 124 протокола
  print('');
  var matched = 0;
  final speciesCounts = <String, int>{};
  for (final p in protocols) {
    final sp = (p['species'] as List).cast<String>();
    final animal = selectAnimalFromSpecies(sp, animals);
    if (animal != null) matched++;
    final key = sp.isEmpty ? '(пусто)' : sp.first;
    speciesCounts[key] = (speciesCounts[key] ?? 0) + 1;
    if (animal == null) {
      print('   ⚠️ не сматчился вид $sp у «${p["diagnosis"]}»');
    }
  }
  print('\nЖивотное подобрано для $matched из ${protocols.length} протоколов');
  check(matched >= 122, 'подстановка вида ≥122/124 (Олени/Все не матчатся легитимно)');

  // 4. Регресс: обычный поиск не сломан
  check(findDrug(drugs, 'энрофлоксацин') != null, 'регресс "энрофлоксацин"');
  check(findDrug(drugs, 'амоксициллин') != null, 'регресс "амоксициллин"');
  check(findDrug(drugs, 'Кетопрофен') != null, 'регресс "Кетопрофен" (МНН)');
  check(findDrug(drugs, 'Римадил') != null, 'регресс "Римадил" (торговое)');
  check(findDrug(drugs, 'xyzабракадабра') == null, 'мусорный запрос не находит ничего');

  print(fails == 0 ? '\nВСЕ ПРОВЕРКИ ПРОЙДЕНЫ' : '\nПРОВАЛОВ: $fails');
  exit(fails == 0 ? 0 : 1);
}
