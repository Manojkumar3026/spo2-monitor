import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../pdf_report.dart';
import '../widgets/report_actions.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.ctrl});
  final AppController ctrl;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'All saved measurements will be deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (ok == true) ctrl.clearHistory();
  }

  void _details(BuildContext context, Measurement m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: C.line,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.patient,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusChip(ok: m.allOk),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${dateFmt.format(m.at)} · ${timeFmt.format(m.at)}',
                style: const TextStyle(color: C.muted),
              ),
            ),
            const SizedBox(height: 18),
            _row(
              'SpO2',
              '${m.spo2.toStringAsFixed(1)} %',
              '${fmtLimit(m.limits.spo2Min)} – ${fmtLimit(m.limits.spo2Max)} %',
              m.spo2Ok,
            ),
            const SizedBox(height: 10),
            _row(
              'Heart rate',
              '${m.bpm.toStringAsFixed(1)} BPM',
              '${fmtLimit(m.limits.bpmMin)} – ${fmtLimit(m.limits.bpmMax)} BPM',
              m.bpmOk,
            ),
            const SizedBox(height: 20),
            ReportActions(m: m),
          ],
        ),
      ),
    );
  }

  Widget _row(String t, String v, String limits, bool ok) => SoftCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: const TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                v,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ok ? C.green : C.red,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusChip(ok: ok, compact: true),
            const SizedBox(height: 6),
            Text(
              'Limits $limits',
              style: const TextStyle(color: C.muted, fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final list = ctrl.history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (list.isNotEmpty)
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Clear history',
                  onTap: () => _confirmClear(context),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: C.muted),
                        SizedBox(height: 12),
                        Text(
                          'No measurements yet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Completed measurements will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: C.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return Dismissible(
                      key: ValueKey(m.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: C.red,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) => ctrl.deleteMeasurement(m),
                      child: GestureDetector(
                        onTap: () => _details(context, m),
                        child: SoftCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.patient,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  StatusChip(ok: m.allOk, compact: true),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateTimeFmt.format(m.at),
                                style: const TextStyle(
                                  color: C.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _val('SpO2', '${m.spo2.toStringAsFixed(1)}%', m.spo2Ok),
                                  const SizedBox(width: 28),
                                  _val('BPM', m.bpm.toStringAsFixed(1), m.bpmOk),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _val(String label, String v, bool ok) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
      Text(
        v,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: ok ? C.green : C.red,
        ),
      ),
    ],
  );
}
