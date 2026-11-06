import 'package:flutter/material.dart';

import '../models.dart';
import '../pdf_report.dart';
import 'ui.dart';

/// Print / Share / Save(Download) buttons for the PDF report.
class ReportActions extends StatelessWidget {
  const ReportActions({super.key, required this.m});
  final Measurement m;

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() job,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await job();
      if (msg != null) {
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDF failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String label, Future<String?> Function() job) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _run(context, job),
            icon: Icon(i, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.ink,
              side: const BorderSide(color: C.line),
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        );

    return Row(
      children: [
        btn(Icons.download_rounded, 'Save', () async {
          final p = await saveReport(m);
          return 'PDF saved: $p';
        }),
        const SizedBox(width: 8),
        btn(Icons.print_outlined, 'Print', () async {
          await printReport(m);
          return null;
        }),
        const SizedBox(width: 8),
        btn(Icons.ios_share_rounded, 'Share', () async {
          await shareReport(m);
          return null;
        }),
      ],
    );
  }
}
