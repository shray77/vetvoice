// ExportService — экспорт истории расчётов в CSV и PDF.
//
// Возможности:
//   - exportToCsv() — генерирует CSV-строку, сохраняет во временный файл,
//     открывает share dialog
//   - exportToPdf() — генерирует PDF с историей, открывает print preview
//     (можно распечатать или сохранить в PDF)
//
// Зависимости:
//   - pdf: ^3.10.0 — генерация PDF
//   - printing: ^5.12.0 — preview/печать PDF
//   - share_plus: ^7.2.2 — share dialog для CSV
//   - path_provider: ^2.1.2 — временная директория
//
// Использование:
//   final svc = ExportService();
//   await svc.exportToCsv(entries);
//   await svc.exportToPdf(entries);

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'history_service.dart';

class ExportService {
  /// Экспорт истории в CSV-файл + share dialog.
  ///
  /// Возвращает путь к сохранённому файлу или null при ошибке.
  static Future<String?> exportToCsv(List<HistoryEntry> entries) async {
    if (entries.isEmpty) return null;

    // Заголовок CSV
    final buffer = StringBuffer();
    buffer.writeln('Дата,Препарат,МНН,Животное,Вес (кг),Доза,Объём,Путь,Частота');

    for (final e in entries) {
      final row = [
        _escapeCsv(e.formattedTime),
        _escapeCsv(e.drugName),
        _escapeCsv(e.inn),
        _escapeCsv(e.animal),
        e.weightKg.toStringAsFixed(1),
        e.dosePerKg > 0 ? e.dosePerKg.toString() : '',
        e.volumeMl > 0 ? e.volumeMl.toStringAsFixed(2) : '',
        _escapeCsv(e.method),
        _escapeCsv(e.frequency),
      ];
      buffer.writeln(row.join(','));
    }

    // Сохраняем во временный файл
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'vetvoice_history_${now.day}${now.month}${now.year}_${now.hour}${now.minute}.csv';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString('\uFEFF${buffer.toString()}'); // BOM для Excel

    // Share dialog
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'VetVoice — История расчётов ($fileName)',
      text: 'История расчётов VetVoice AI от ${now.day}.${now.month}.${now.year}',
    );

    return file.path;
  }

  /// Экранирование CSV-значения (кавычки, запятые, переносы строк).
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Экспорт истории в PDF + print preview.
  ///
  /// Открывает системный print dialog — можно распечатать или
  /// сохранить как PDF.
  static Future<void> exportToPdf(List<HistoryEntry> entries) async {
    if (entries.isEmpty) return;

    final pdf = pw.Document();

    // Заголовок
    final now = DateTime.now();
    final dateStr =
        '${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'VetVoice AI — История расчётов',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Сформировано: $dateStr',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Страница ${context.pageNumber} из ${context.pagesCount} — VetVoice AI',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
          ),
        ),
        build: (context) => [
          // Таблица с историей
          pw.TableHelper.fromTextArray(
            headers: [
              'Дата',
              'Препарат',
              'Животное',
              'Вес',
              'Доза',
              'Путь',
            ],
            data: entries.map((e) {
              return [
                e.formattedTime,
                e.drugName,
                e.animal,
                '${e.weightKg.toStringAsFixed(1)} кг',
                e.formattedResult,
                e.method,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(80),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Всего записей: ${entries.length}\n'
              'Это автоматически сгенерированный отчёт приложения VetVoice AI.\n'
              'Перед применением дозировок — консультируйтесь с инструкцией производителя.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    // Открываем print preview
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'vetvoice_history_${now.day}${now.month}${now.year}',
    );
  }
}
