import 'package:flutter/material.dart';

import '../controller.dart';
import '../widgets/ui.dart';

/// Full-screen dark view shown during the 5 s countdown and 30 s recording.
class MeasureView extends StatelessWidget {
  const MeasureView({super.key, required this.ctrl});
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final counting = ctrl.phase == Phase.countdown;
    final pct = (ctrl.progress * 100).round();

    return Scaffold(
      backgroundColor: C.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    dark: true,
                    tooltip: 'Cancel',
                    onTap: ctrl.cancel,
                  ),
                  Expanded(
                    child: Text(
                      counting ? 'Get ready' : 'Recording',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ctrl.patient.text.trim(),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                width: 320,
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DotRing(size: 320, intensity: counting ? .6 : 1.2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween(begin: 1.5, end: 1.0).animate(anim),
                          child: child,
                        ),
                      ),
                      child: counting
                          ? Column(
                              key: ValueKey(ctrl.countdown),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DotNumber(
                                  '${ctrl.countdown}',
                                  color: Colors.white,
                                  dot: 11,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'seconds',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('rec'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DotNumber(
                                  '${ctrl.elapsed}',
                                  color: Colors.white,
                                  dot: 9,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'of $recordSeconds s',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                counting
                    ? 'Place your finger on the sensor'
                    : 'Keep your finger still',
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                counting
                    ? 'Measurement starts in ${ctrl.countdown}…'
                    : 'Measuring…',
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: counting
                      ? (countdownSeconds - ctrl.countdown + 1) /
                            countdownSeconds
                      : ctrl.progress,
                  minHeight: 6,
                  color: C.red,
                  backgroundColor: const Color(0xFF2A2A2D),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                counting ? 'Starting…' : '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: const Color(0xFF1B1B1D),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: ctrl.cancel,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: C.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Stop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 56),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
