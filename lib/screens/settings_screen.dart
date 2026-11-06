import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.ctrl});
  final AppController ctrl;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final sMin = TextEditingController(
    text: fmtLimit(widget.ctrl.limits.spo2Min),
  );
  late final sMax = TextEditingController(
    text: fmtLimit(widget.ctrl.limits.spo2Max),
  );
  late final bMin = TextEditingController(
    text: fmtLimit(widget.ctrl.limits.bpmMin),
  );
  late final bMax = TextEditingController(
    text: fmtLimit(widget.ctrl.limits.bpmMax),
  );
  String? error;
  bool saved = false;

  @override
  void dispose() {
    for (final c in [sMin, sMax, bMin, bMax]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final a = double.tryParse(sMin.text.trim());
    final b = double.tryParse(sMax.text.trim());
    final c = double.tryParse(bMin.text.trim());
    final d = double.tryParse(bMax.text.trim());
    String? err;
    if (a == null || b == null || c == null || d == null) {
      err = 'Enter a number in every field.';
    } else if (a >= b) {
      err = 'SpO2 minimum must be lower than maximum.';
    } else if (c >= d) {
      err = 'BPM minimum must be lower than maximum.';
    } else if (a < 0 || b > 100) {
      err = 'SpO2 limits must be between 0 and 100.';
    } else if (c < 0 || d > 300) {
      err = 'BPM limits must be between 0 and 300.';
    }
    setState(() {
      error = err;
      saved = err == null;
    });
    if (err == null) {
      widget.ctrl.setLimits(
        Limits(spo2Min: a!, spo2Max: b!, bpmMin: c!, bpmMax: d!),
      );
    }
  }

  Widget _field(String label, TextEditingController c) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _apply(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: C.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _group(
    String title,
    IconData icon,
    String unit,
    TextEditingController min,
    TextEditingController max,
  ) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: C.red.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: C.red),
            ),
            const SizedBox(width: 10),
            Text(
              '$title ($unit)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _field('Minimum', min),
            const SizedBox(width: 12),
            _field('Maximum', max),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
      children: [
        const Text(
          'Limits',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Readings inside the range show in green. Readings below the minimum or above the maximum show in red.',
          style: TextStyle(color: C.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        _group('SpO2', Icons.bloodtype_rounded, '%', sMin, sMax),
        const SizedBox(height: 14),
        _group('Heart rate', Icons.favorite_rounded, 'BPM', bMin, bMax),
        if (saved && error == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: C.green, size: 18),
                SizedBox(width: 6),
                Text('Limits saved', style: TextStyle(color: C.green)),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: C.red)),
          ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              const d = Limits();
              sMin.text = fmtLimit(d.spo2Min);
              sMax.text = fmtLimit(d.spo2Max);
              bMin.text = fmtLimit(d.bpmMin);
              bMax.text = fmtLimit(d.bpmMax);
              _apply();
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset to defaults'),
          ),
        ),
        const SizedBox(height: 20),
        SoftCard(
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: C.muted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This app is a prototype. The ESP32 + MAX30102 SpO2 and BPM '
                  'calculations and measurement accuracy must be validated before '
                  'any clinical use.',
                  style: TextStyle(color: C.muted, height: 1.4, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
