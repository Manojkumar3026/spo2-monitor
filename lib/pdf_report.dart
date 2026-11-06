import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';

final dateFmt = DateFormat('d MMM yyyy');
final timeFmt = DateFormat('hh:mm:ss a');
final dateTimeFmt = DateFormat('d MMM yyyy, hh:mm a');

String _fileName(Measurement m) {
  final safe = m.patient.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  return 'SpO2_BPM_${safe}_${DateFormat('yyyyMMdd_HHmmss').format(m.at)}.pdf';
}

Future<Uint8List> buildReport(Measurement m) async {
  final doc = pw.Document(title: 'SpO2 & BPM Report', author: 'SpO2 Monitor');
  const green = PdfColor.fromInt(0xFF16A34A);
  const red = PdfColor.fromInt(0xFFE5252A);
  const ink = PdfColor.fromInt(0xFF0B0B0C);
  const grey = PdfColor.fromInt(0xFF6B6B72);

  pw.Widget statusCell(bool ok) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      ok ? 'IN RANGE' : 'OUT OF RANGE',
      style: pw.TextStyle(
        color: ok ? green : red,
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
      ),
    ),
  );

  pw.Widget cell(String t, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  pw.Widget kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            k,
            style: const pw.TextStyle(color: grey, fontSize: 11),
          ),
        ),
        pw.Text(
          v,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
      ],
    ),
  );

  pw.Widget section(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      t.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 10,
        letterSpacing: 1,
        fontWeight: pw.FontWeight.bold,
        color: grey,
      ),
    ),
  );

  final q = m.quality;
  final qColor = q == 'Good'
      ? green
      : (q == 'Fair' ? PdfColors.orange700 : red);

  doc.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(36),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PATIENT SpO2 & BPM REPORT',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, width: 60, color: red),

          section('Patient information'),
          kv('Patient name', m.patient),

          section('Measurement details'),
          kv('Measurement date', dateFmt.format(m.at)),
          kv('Measurement time', timeFmt.format(m.at)),
          kv('Device', 'ESP32 + MAX30102 (BLE)'),
          kv('Recording duration', '${m.recordedSeconds} s (target 30 s)'),
          kv('Overall status', m.allOk ? 'WITHIN LIMITS' : 'OUT OF LIMITS'),

          section('Readings, limits and status'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(3),
              3: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell('Parameter', bold: true),
                  cell('Reading', bold: true),
                  cell('Configured limits', bold: true),
                  cell('Status', bold: true),
                ],
              ),
              pw.TableRow(
                children: [
                  cell('SpO2'),
                  cell('${m.spo2.toStringAsFixed(1)} %', bold: true),
                  cell(
                    '${fmtLimit(m.limits.spo2Min)} - ${fmtLimit(m.limits.spo2Max)} %',
                  ),
                  statusCell(m.spo2Ok),
                ],
              ),
              pw.TableRow(
                children: [
                  cell('Heart rate'),
                  cell('${m.bpm.toStringAsFixed(1)} BPM', bold: true),
                  cell(
                    '${fmtLimit(m.limits.bpmMin)} - ${fmtLimit(m.limits.bpmMax)} BPM',
                  ),
                  statusCell(m.bpmOk),
                ],
              ),
            ],
          ),

          section('Measurement quality'),
          pw.Row(
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(
                  'Quality grade',
                  style: const pw.TextStyle(color: grey, fontSize: 11),
                ),
              ),
              pw.Text(
                q,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: qColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          kv('Valid result received', 'Yes'),
          kv('Invalid readings rejected', '${m.invalidReadings}'),
          kv('Accepted ranges', 'SpO2 70-100 %, BPM 30-220'),
          pw.Text(
            m.qualityNote,
            style: const pw.TextStyle(fontSize: 10, color: grey),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'The grade is derived by the app from recording length and reading '
            'validity. It is not a sensor signal-quality measurement.',
            style: const pw.TextStyle(fontSize: 9, color: grey),
          ),

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Report generated ${dateTimeFmt.format(DateTime.now())}. Prototype report only. '
            'The SpO2 and heart rate calculations are experimental and have not been '
            'clinically validated. Not intended for diagnosis or treatment.',
            style: const pw.TextStyle(fontSize: 9, color: grey),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<void> printReport(Measurement m) async {
  final bytes = await buildReport(m);
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName(m));
}

Future<void> shareReport(Measurement m) async {
  final bytes = await buildReport(m);
  await Printing.sharePdf(bytes: bytes, filename: _fileName(m));
}

/// Saves the PDF to the device and returns the saved path.
Future<String> saveReport(Measurement m) async {
  final bytes = await buildReport(m);
  Directory? dir;
  if (Platform.isAndroid) {
    final dirs = await getExternalStorageDirectories(
      type: StorageDirectory.documents,
    );
    dir = (dirs != null && dirs.isNotEmpty) ? dirs.first : null;
  }
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/${_fileName(m)}');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
