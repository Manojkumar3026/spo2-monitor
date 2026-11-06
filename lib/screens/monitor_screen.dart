import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../pdf_report.dart';
import '../widgets/report_actions.dart';
import '../widgets/ui.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key, required this.ctrl});
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final m = ctrl.latest;
    final name = ctrl.patient.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
      children: [
        // Header
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: C.ink,
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'New patient' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Patient',
                    style: TextStyle(color: C.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            _BleBadge(ctrl: ctrl),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          'Check Your',
          style: TextStyle(
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            color: Color(0xFFA0A0A8),
          ),
        ),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'SpO₂ & Heart Rate',
            maxLines: 1,
            style: TextStyle(
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: C.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Place a finger on the sensor and stay still for 30 seconds.',
          style: TextStyle(color: C.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 22),

        if (ctrl.error != null) ...[
          _ErrorBanner(message: ctrl.error!, onClose: ctrl.dismissError),
          const SizedBox(height: 14),
        ],

        // Patient name
        SoftCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: TextField(
            controller: ctrl.patient,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) => ctrl.refresh(),
            onSubmitted: (_) => ctrl.savePatientName(),
            decoration: const InputDecoration(
              labelText: 'Patient name',
              hintText: 'Enter patient name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Connection
        _ConnectionCard(ctrl: ctrl),
        const SizedBox(height: 14),

        // Start
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: ctrl.connected && !ctrl.busy
                ? () {
                    FocusScope.of(context).unfocus();
                    final problem = ctrl.validateStart();
                    if (problem != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(problem)));
                      return;
                    }
                    ctrl.start();
                  }
                : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('Start measurement'),
            style: FilledButton.styleFrom(
              backgroundColor: C.ink,
              disabledBackgroundColor: const Color(0xFFD5D5DA),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (!ctrl.connected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Connect to the sensor to enable measurement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 26),

        // Results
        Row(
          children: [
            const Text(
              'Latest result',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (m != null)
              Text(
                dateTimeFmt.format(m.at),
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'SpO2',
                unit: '%',
                icon: Icons.bloodtype_rounded,
                value: m?.spo2,
                ok: m?.spo2Ok,
                limits:
                    '${fmtLimit(ctrl.limits.spo2Min)} – ${fmtLimit(ctrl.limits.spo2Max)} %',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Heart rate',
                unit: 'BPM',
                icon: Icons.favorite_rounded,
                value: m?.bpm,
                ok: m?.bpmOk,
                limits:
                    '${fmtLimit(ctrl.limits.bpmMin)} – ${fmtLimit(ctrl.limits.bpmMax)} BPM',
              ),
            ),
          ],
        ),
        if (m != null) ...[
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: C.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.patient,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    StatusChip(ok: m.allOk),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: C.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dateFmt.format(m.at)} · ${timeFmt.format(m.at)}',
                      style: const TextStyle(color: C.muted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ReportActions(m: m),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Prototype only: SpO2 and BPM calculations are experimental and must be '
          'validated before clinical use. Do not use these readings for diagnosis or treatment.',
          style: TextStyle(fontSize: 11, color: C.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _BleBadge extends StatelessWidget {
  const _BleBadge({required this.ctrl});
  final AppController ctrl;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (ctrl.bleState) {
      BleState.connected => (Icons.bluetooth_connected_rounded, C.green),
      BleState.scanning => (Icons.bluetooth_searching_rounded, C.ink),
      BleState.connecting => (Icons.bluetooth_searching_rounded, C.ink),
      BleState.disconnected => (Icons.bluetooth_disabled_rounded, C.muted),
    };
    return Container(
      width: 48,
      height: 48,
      decoration: cardDeco(r: 24),
      child: Icon(icon, color: color),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.ctrl});
  final AppController ctrl;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (ctrl.bleState) {
      BleState.connected => ('CONNECTED', C.green),
      BleState.scanning => ('SCANNING', C.ink),
      BleState.connecting => ('CONNECTING', C.ink),
      BleState.disconnected => ('DISCONNECTED', C.muted),
    };
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: ctrl.connecting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: C.ink,
                    ),
                  )
                : Icon(Icons.bluetooth_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ctrl.connectionStatus,
                  style: const TextStyle(color: C.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ctrl.connected
              ? TextButton(
                  onPressed: ctrl.disconnect,
                  child: const Text('Disconnect'),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: ctrl.connecting ? null : ctrl.connect,
                      style: FilledButton.styleFrom(
                        backgroundColor: C.ink,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(ctrl.connecting ? 'Wait…' : 'Connect'),
                    ),
                    TextButton(
                      onPressed: ctrl.connecting ? null : ctrl.connectDemo,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: C.muted,
                      ),
                      child: const Text(
                        'Demo mode',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.unit,
    required this.icon,
    required this.value,
    required this.ok,
    required this.limits,
  });
  final String title, unit, limits;
  final IconData icon;
  final double? value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final color = ok == null ? C.muted : (ok! ? C.green : C.red);
    final text = value == null ? '--' : value!.toStringAsFixed(1);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: DotNumber(
              text,
              color: ok == null ? C.ink.withValues(alpha: .35) : color,
              dot: 6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              unit,
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          StatusChip(ok: ok, compact: true),
          const SizedBox(height: 6),
          Text(
            'Limits $limits',
            style: const TextStyle(color: C.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
    decoration: BoxDecoration(
      color: C.red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.red.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: C.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.3),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Dismiss',
          icon: const Icon(Icons.close_rounded, color: C.red, size: 20),
        ),
      ],
    ),
  );
}
