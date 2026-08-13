import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/drug.dart';
import 'package:vetvoice_ai/models/disease.dart';
import 'package:vetvoice_ai/models/drug_interaction.dart';
import 'package:vetvoice_ai/models/drug_registry.dart';
import 'package:vetvoice_ai/models/antidote.dart';

/// Юнит-тесты для null-safe fromJson.
/// Покрывают фикс B-13: один битый JSON-элемент не должен убивать весь файл.
void main() {
  group('Drug.fromJson — фикс B-13', () {
    test('корректный JSON парсится без ошибок', () {
      final drug = Drug.fromJson({
        'id': 1,
        'name': 'Тест',
        'dose': 5.0,
        'unit': 'ml/kg',
        'animals': ['Собака', 'Кошка'],
        'method': 'внутрь',
        'method_short': 'внутрь',
        'active_ingredient': 'тест',
        'withdrawal_days': 7,
        'description': 'описание',
      });
      expect(drug.id, 1);
      expect(drug.name, 'Тест');
      expect(drug.dose, 5.0);
      expect(drug.animals, ['Собака', 'Кошка']);
    });

    test('битый JSON с отсутствующими полями — fallback на дефолты, без исключения', () {
      // Раньше 'as int' / 'as String' / 'as num' кидали TypeError,
      // вышестоящий try/catch дискардил весь файл.
      final drug = Drug.fromJson({
        'id': null,
        'name': null,
        'dose': null,
        // animals отсутствует
        // method отсутствует
      });
      expect(drug.id, 0);
      expect(drug.name, '');
      expect(drug.dose, 0);
      expect(drug.animals, isEmpty);
      expect(drug.method, '');
    });

    test('dose как int должен конвертиться в double', () {
      final drug = Drug.fromJson({
        'id': 1,
        'name': 'Тест',
        'dose': 5, // int, не double
        'animals': [],
        'method': 'внутрь',
      });
      expect(drug.dose, 5.0);
    });
  });

  group('DrugDatabase.fromJson — фикс B-13 per-item try/catch', () {
    test('один битой препарат не убивает весь список', () {
      final db = DrugDatabase.fromJson({
        'version': '1.0',
        'source': 'test',
        'last_updated': '2024-01-01',
        'drugs': [
          {'id': 1, 'name': 'Хороший', 'dose': 5, 'animals': [], 'method': 'внутрь'},
          // Битой — у этого id как строка (несоответствие типа не должно падать после фикса)
          {'id': 'битый', 'name': 'Плохой', 'dose': 5, 'animals': [], 'method': 'внутрь'},
          {'id': 3, 'name': 'Тоже хороший', 'dose': 5, 'animals': [], 'method': 'внутрь'},
        ],
        'animals': [],
      });
      // Должно распарситься хотя бы 2 препарата (битой может либо распарситься с id=0, либо нет — оба варианта OK)
      expect(db.drugs.length, greaterThanOrEqualTo(2),
          reason: 'Битой препарат не должен валить весь файл');
      expect(db.version, '1.0');
    });

    test('пустой drugs list — не падает', () {
      final db = DrugDatabase.fromJson({
        'version': '1.0',
        'source': 'test',
        'last_updated': '2024',
      });
      expect(db.drugs, isEmpty);
      expect(db.animals, isEmpty);
    });
  });

  group('Animal.fromJson — фикс B-13', () {
    test('битой Animal с null полями не падает', () {
      final animal = Animal.fromJson({});
      expect(animal.id, '');
      expect(animal.name, '');
      expect(animal.icon, '');
      expect(animal.minWeight, 0.1);
      expect(animal.maxWeight, 2000);
    });
  });

  group('Disease.fromJson — фикс B-13', () {
    test('битой Disease не падает', () {
      final disease = Disease.fromJson({});
      expect(disease.id, 0);
      expect(disease.name, '');
      expect(disease.animals, isEmpty);
    });

    test('DiseaseDatabase с битой записью пропускает её', () {
      final db = DiseaseDatabase.fromJson({
        'version': '1.0',
        'source': 'test',
        'description': '',
        'categories': {'infectious': 'Инфекционная'},
        'diseases': [
          {'id': 1, 'name': 'Хорошая', 'code': 'A', 'category': 'infectious', 'animals': []},
          // Битой — categories.type = List вместо Map
          // (это проверяется отдельно, тут просто битой Disease)
          {'id': 'строка вместо числа', 'name': null, 'code': null, 'category': null},
          {'id': 3, 'name': 'Тоже хорошая', 'code': 'B', 'category': 'infectious', 'animals': []},
        ],
      });
      expect(db.diseases.length, greaterThanOrEqualTo(2),
          reason: 'Битой болезнь не должен валить весь файл');
      expect(db.categories['infectious'], 'Инфекционная');
    });

    test('DiseaseDatabase с categories=null — не падает, возвращает пустой map', () {
      final db = DiseaseDatabase.fromJson({
        'version': '1.0',
        'source': 'test',
        'description': '',
        'diseases': [],
      });
      expect(db.categories, isEmpty);
      expect(db.diseases, isEmpty);
    });
  });

  group('DrugInteraction.fromJson — фикс B-13', () {
    test('битой DrugInteraction не падает', () {
      final interaction = DrugInteraction.fromJson({});
      expect(interaction.drug1, '');
      expect(interaction.drug2, '');
      expect(interaction.severity, 'info'); // дефолт
      expect(interaction.isInfo, true);
    });

    test('InteractionDatabase с битой записью пропускает её', () {
      final db = InteractionDatabase.fromJson({
        'interactions': [
          {'drug1': 'A', 'drug2': 'B', 'severity': 'critical'},
          // Битой
          {'drug1': null, 'drug2': null, 'severity': 'invalid'},
          {'drug1': 'C', 'drug2': 'D', 'severity': 'warning'},
        ],
      });
      // После фикса все 3 должны распарситься (с fallback на пустые значения),
      // но главное — никакого исключения.
      expect(db.interactions.length, 3);
    });
  });

  group('RegistryDrug.fromJson — фикс B-13', () {
    test('битой RegistryDrug не падает', () {
      final drug = RegistryDrug.fromJson({});
      expect(drug.id, 0);
      expect(drug.tradeName, '');
      expect(drug.inn, '');
      expect(drug.animals, isEmpty);
    });

    test('DrugRegistry с битой записью пропускает её', () {
      final registry = DrugRegistry.fromJson({
        'version': '1.0',
        'source': 'test',
        'last_updated': '2024',
        'total_drugs': 2,
        'drugs': [
          {'id': 1, 'trade_name': 'Хороший', 'inn': 'test'},
          // Битой: все поля отсутствуют
          {},
          {'id': 3, 'trade_name': 'Тоже хороший', 'inn': 'test2'},
        ],
      });
      expect(registry.drugs.length, greaterThanOrEqualTo(2));
      // total_drugs может быть не равен drugs.length, если запись была битая
      expect(registry.totalDrugs, 2);
    });
  });

  group('Antidote.fromJson — фикс B-13', () {
    test('битой Antidote не падает', () {
      final antidote = Antidote.fromJson({});
      expect(antidote.toxin, '');
      expect(antidote.commonNames, isEmpty);
      expect(antidote.symptoms, isEmpty);
      expect(antidote.antidote, '');
    });

    test('AntidoteDatabase с битой записью пропускает её', () {
      final db = AntidoteDatabase.fromJson({
        'poisonings': [
          {'toxin': 'Яд1', 'antidote': 'Антидот1'},
          // Битой
          {'toxin': null, 'antidote': null},
          {'toxin': 'Яд3', 'antidote': 'Антидот3'},
        ],
      });
      expect(db.poisonings.length, greaterThanOrEqualTo(2));
    });
  });
}
