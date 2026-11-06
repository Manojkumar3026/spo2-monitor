import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const deviceName = 'MAX30102_Monitor';
const serviceUUID = '180D0001-0000-1000-8000-00805F9B34FB';
const resultUUID = '180D0002-0000-1000-8000-00805F9B34FB';
const commandUUID = '180D0003-0000-1000-8000-00805F9B34FB';

const countdownSeconds = 5;
const recordSeconds = 30;
const resultTimeoutSeconds = 45; // give up if no result this long after start

enum Phase { idle, countdown, measuring }

enum BleState { disconnected, scanning, connecting, connected }

class AppController extends ChangeNotifier {
  final patient = TextEditingController();

  Limits limits = const Limits();
  List<Measurement> history = [];
  Measurement? latest;

  // Connection
  BleState bleState = BleState.disconnected;
  bool get connected => bleState == BleState.connected;
  bool get connecting =>
      bleState == BleState.scanning || bleState == BleState.connecting;
  String connectionStatus = 'Disconnected';

  // Measurement
  Phase phase = Phase.idle;
  int countdown = 0;
  double progress = 0; // 0..1 of the 30 s recording
  int elapsed = 0;
  String? error;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _char;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _ticker;
  int _runId = 0;
  bool _starting = false;
  bool _invalidSeen = false;
  bool demo = false;
  int _invalidCount = 0;
  int _validCount = 0;
  bool loaded = false;

  // Physiologically plausible ranges; anything else is a sensor artefact.
  static bool validSpo2(double v) => v >= 70 && v <= 100;
  static bool validBpm(double v) => v >= 30 && v <= 220;

  bool get busy => phase != Phase.idle;

  void refresh() => notifyListeners();

  // ---------------------------------------------------------------- storage
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    patient.text = p.getString('patient') ?? '';
    final l = p.getString('limits');
    if (l != null) limits = Limits.fromJson(jsonDecode(l));
    final h = p.getString('history');
    if (h != null) {
      try {
        history = Measurement.decodeList(h);
        latest = history.isEmpty ? null : history.first;
      } catch (_) {}
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('history', Measurement.encodeList(history));
  }

  Future<void> setLimits(Limits l) async {
    limits = l;
    if (latest != null) {
      latest = latest!.withLimits(l);
      history[0] = latest!;
      _saveHistory();
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('limits', jsonEncode(l.toJson()));
    notifyListeners();
  }

  Future<void> savePatientName() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('patient', patient.text.trim());
  }

  Future<void> deleteMeasurement(Measurement m) async {
    history.removeWhere((e) => e.id == m.id);
    if (latest?.id == m.id) latest = history.isEmpty ? null : history.first;
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    history.clear();
    latest = null;
    notifyListeners();
    await _saveHistory();
  }

  // -------------------------------------------------------------- bluetooth
  Future<bool> _ensurePermissions() async {
    final List<Permission> needed = Platform.isAndroid
        ? [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission
                .locationWhenInUse, // only enforced on Android 11 and below
          ]
        : [Permission.bluetooth];

    final result = await needed.request();
    for (final entry in result.entries) {
      // Location is irrelevant on Android 12+, where it reports denied.
      if (entry.key == Permission.locationWhenInUse) continue;
      if (!entry.value.isGranted) {
        if (entry.value.isPermanentlyDenied) {
          connectionStatus =
              'Bluetooth permission blocked. Enable it in system Settings.';
          await openAppSettings();
        } else {
          connectionStatus = 'Bluetooth permission denied';
        }
        return false;
      }
    }
    return true;
  }

  Future<void> connect() async {
    if (connecting || connected) return;
    bleState = BleState.scanning;
    error = null;
    connectionStatus = 'Checking Bluetooth permissions…';
    notifyListeners();

    StreamSubscription<List<ScanResult>>? scanSub;
    try {
      if (!await _ensurePermissions()) return;

      if (!await FlutterBluePlus.isSupported) {
        connectionStatus = 'Bluetooth LE is not supported on this device';
        return;
      }

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        connectionStatus = 'Please turn Bluetooth on…';
        notifyListeners();
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (_) {}
        }
        await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 15));
      }

      connectionStatus = 'Scanning for $deviceName…';
      notifyListeners();

      final found = Completer<BluetoothDevice>();
      bool isTarget(ScanResult r) =>
          r.device.platformName == deviceName ||
          r.advertisementData.advName == deviceName;

      scanSub = FlutterBluePlus.scanResults.listen((list) {
        for (final r in list) {
          if (isTarget(r) && !found.isCompleted) found.complete(r.device);
        }
      });
      await FlutterBluePlus.startScan(
        withNames: [deviceName],
        withServices: [Guid(serviceUUID)],
        timeout: const Duration(seconds: 12),
      );
      final device = await found.future.timeout(const Duration(seconds: 13));
      await FlutterBluePlus.stopScan();

      bleState = BleState.connecting;
      connectionStatus = 'Connecting to $deviceName…';
      notifyListeners();
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      _device = device;

      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _onDisconnected();
      });

      connectionStatus = 'Setting up sensor service…';
      notifyListeners();
      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == Guid(serviceUUID));
      _char = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(resultUUID),
      );

      _cmdChar = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(commandUUID),
      );

      await _char!.setNotifyValue(true);
      _notifySub = _char!.onValueReceived.listen(_onData);
      device.cancelWhenDisconnected(_notifySub!);

      bleState = BleState.connected;
      connectionStatus = 'Connected to $deviceName';
    } on TimeoutException {
      bleState = BleState.disconnected;
      connectionStatus =
          FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on
          ? '$deviceName not found. Power on the ESP32 and keep it close.'
          : 'Bluetooth is turned off.';
      await _cleanupConnection();
    } on StateError {
      bleState = BleState.disconnected;
      connectionStatus =
          'Connected, but the sensor service was not found on this device.';
      await _cleanupConnection();
    } catch (e) {
      bleState = BleState.disconnected;
      connectionStatus = 'Connection failed: ${_short(e)}';
      await _cleanupConnection();
    } finally {
      await scanSub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      if (bleState != BleState.connected) bleState = BleState.disconnected;
      notifyListeners();
    }
  }

  /// Simulated sensor for trying the UI without hardware.
  void connectDemo() {
    if (connected || connecting) return;
    demo = true;
    error = null;
    bleState = BleState.connected;
    connectionStatus = 'Demo mode: simulated sensor';
    notifyListeners();
  }

  Future<void> disconnect() async {
    demo = false;
    _cancelRun();
    await _cleanupConnection();
    bleState = BleState.disconnected;
    connectionStatus = 'Disconnected';
    notifyListeners();
  }

  Future<void> _cleanupConnection() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _notifySub = null;
    _connSub = null;
    _char = null;
    _cmdChar = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  void _onDisconnected() {
    if (!connected) return;
    bleState = BleState.disconnected;
    connectionStatus =
        'Disconnected. Connection lost. Tap Connect to reconnect.';
    if (busy) {
      _cancelRun();
      error = 'Bluetooth connection lost during measurement.';
    }
    _notifySub?.cancel();
    _notifySub = null;
    _char = null;
    _cmdChar = null;
    notifyListeners();
  }

  String _short(Object e) {
    final s = e.toString().replaceAll('Exception: ', '');
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  // ------------------------------------------------------------ measurement
  /// Returns an error message if the measurement cannot start.
  String? validateStart() {
    if (patient.text.trim().isEmpty)
      return 'Please enter the patient name first.';
    if (!connected || ((_char == null || _cmdChar == null) && !demo))
      return 'Connect to $deviceName first.';
    return null;
  }

  Future<void> start() async {
    if (busy || _starting) return; // ignore repeated Start presses
    final problem = validateStart();
    if (problem != null) {
      error = problem;
      notifyListeners();
      return;
    }
    savePatientName();

    _starting = true;
    final run = ++_runId;
    error = null;
    progress = 0;
    elapsed = 0;
    _invalidSeen = false;
    _invalidCount = 0;
    _validCount = 0;
    phase = Phase.countdown;
    notifyListeners();
    _starting = false;

    for (int i = countdownSeconds; i >= 1; i--) {
      countdown = i;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      if (run != _runId) return;
    }

    try {
      countdown = 0;
      phase = Phase.measuring;
      notifyListeners();
      if (!demo) await _cmdChar!.write(utf8.encode('s'), withoutResponse: false);
      if (run != _runId) return;

      final sw = Stopwatch()..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (run != _runId) return;
        final sec = sw.elapsedMilliseconds / 1000;
        elapsed = sec.floor();
        progress = (sec / recordSeconds).clamp(0.0, 1.0);
        if (demo && sec >= recordSeconds) {
          final r = DateTime.now().millisecond;
          _onData(utf8.encode('SPO2=${96 + r % 4},BPM=${72 + r % 14}'));
          return;
        }
        if (sec >= resultTimeoutSeconds) {
          _fail(
            _invalidSeen
                ? 'The sensor returned invalid SpO2/BPM values. Place your finger firmly on the sensor, keep still and try again.'
                : 'No reading received from the sensor. Check the finger placement and try again.',
          );
          return;
        }
        notifyListeners();
      });
    } catch (e) {
      if (run == _runId) _fail('Could not start measurement: ${_short(e)}');
    }
  }

  void cancel() {
    _cancelRun();
    notifyListeners();
  }

  void _cancelRun() {
    _runId++;
    _ticker?.cancel();
    _ticker = null;
    phase = Phase.idle;
    countdown = 0;
    progress = 0;
  }

  void _fail(String msg) {
    _cancelRun();
    error = msg;
    notifyListeners();
  }

  void dismissError() {
    error = null;
    notifyListeners();
  }

  void _onData(List<int> data) {
    if (phase != Phase.measuring) return;
    final message = utf8.decode(data, allowMalformed: true);

    final values = <String, double>{};
    for (final part in message.split(RegExp(r'[,;\n]'))) {
      final pair = part.split('=');
      if (pair.length == 2) {
        final v = double.tryParse(pair[1].trim());
        if (v != null) values[pair[0].trim().toUpperCase()] = v;
      }
    }

    final s = values['SPO2'];
    final b = values['BPM'];

    if (s == null || b == null) {
      final up = message.toUpperCase();
      if (up.contains('ERR') ||
          up.contains('NO_FINGER') ||
          up.contains('FAIL')) {
        _fail('Sensor reported: ${message.trim()}');
      }
      return; // intermediate notification
    }
    // The firmware sends SpO2 and BPM in separate notifications; the first
    // one carries -1 as a "not computed yet" placeholder. Wait for the full one.
    if (s < 0 || b < 0) {
      _invalidSeen = true;
      return;
    }
    // Reject invalid / implausible values instead of showing misleading numbers.
    if (!validSpo2(s) || !validBpm(b)) {
      _invalidSeen = true;
      _invalidCount++;
      if (elapsed >= recordSeconds) {
        _fail(
          'Invalid reading (SpO2 ${s.toStringAsFixed(0)}, BPM ${b.toStringAsFixed(0)}). '
          'No finger detected or signal too weak. Please try again.',
        );
      }
      return; // keep waiting for a valid result
    }

    final m = Measurement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      patient: patient.text.trim(),
      spo2: s,
      bpm: b,
      at: DateTime.now(),
      limits: limits,
      recordedSeconds: elapsed,
      validReadings: _validCount + 1,
      invalidReadings: _invalidCount,
      demo: demo,
    );
    _cancelRun();
    latest = m;
    history.insert(0, m);
    if (history.length > 200) history.removeLast();
    _saveHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    patient.dispose();
    super.dispose();
  }
}
