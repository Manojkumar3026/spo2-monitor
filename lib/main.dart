import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'screens/history_screen.dart';
import 'screens/measure_view.dart';
import 'screens/monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SpO2 Patient Monitor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.red, surface: C.bg),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final ctrl = AppController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ctrl,
    builder: (context, _) {
      if (ctrl.busy) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, _) => ctrl.cancel(),
          child: MeasureView(ctrl: ctrl),
        );
      }
      if (!ctrl.loaded) {
        return const Scaffold(body: SizedBox.shrink());
      }
      final pages = [
        MonitorScreen(ctrl: ctrl),
        HistoryScreen(ctrl: ctrl),
        SettingsScreen(ctrl: ctrl),
      ];
      return Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: IndexedStack(index: tab, children: pages),
          ),
        ),
        bottomNavigationBar: _NavBar(
          index: tab,
          onChanged: (i) => setState(() => tab = i),
        ),
      );
    },
  );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Monitor'),
      (Icons.history_rounded, Icons.history_rounded, 'History'),
      (Icons.tune_rounded, Icons.tune_rounded, 'Limits'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: C.ink,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < items.length; i++)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].$3,
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        height: 52,
                        padding: EdgeInsets.symmetric(
                          horizontal: i == index ? 20 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: i == index ? C.red : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (i == index) ...[
                              const SizedBox(width: 8),
                              Text(
                                items[i].$3,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
