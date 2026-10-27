/// Парсинг десятичного ввода «как набирает пользователь».
///
/// Гейт-кейс Task 178: `TextInputType.numberWithOptions(decimal: true)`
/// на русской локали Android даёт на клавиатуре ЗАПЯТУЮ как десятичный
/// разделитель, а `double.tryParse` запятую не принимает. Ветеринар
/// печатает «12,5» — парсер возвращает null, и вес молча обнулялся
/// (home) или поле «не видело» введённое значение (fluid/ветэко).
/// Голосовой путь запятую чистил всегда (speech_service,
/// voice_command_parser, concentration_parser) — расхождение ручного
/// и голосового ввода закрыто единым хелпером.
///
/// Отрицательные значения ПРОХОДЯТ намеренно: парсер не судит, судят
/// гварды диапазонов в калькуляторах (см. infusion_calculator_screen).
double? parseDecimal(String raw) {
  final s = raw.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}
