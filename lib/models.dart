import 'dart:convert';

class Limits {
  const Limits({
    this.spo2Min = 95,
    this.spo2Max = 100,
    this.bpmMin = 60,
    this.bpmMax = 100,
  });

  final double spo2Min, spo2Max, bpmMin, bpmMax;

  Map<String, dynamic> toJson() => {
    'spo2Min': spo2Min,
    'spo2Max': spo2Max,
    'bpmMin': bpmMin,
    'bpmMax': bpmMax,
  };

  factory Limits.fromJson(Map<String, dynamic> j) => Limits(
    spo2Min: (j['spo2Min'] as num).toDouble(),
    spo2Max: (j['spo2Max'] as num).toDouble(),
    bpmMin: (j['bpmMin'] as num).toDouble(),
    bpmMax: (j['bpmMax'] as num).toDouble(),
  );
}

String fmtLimit(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class Measurement {
  const Measurement({
    required this.id,
    required this.patient,
    required this.spo2,
    required this.bpm,
    required this.at,
    required this.limits,
    this.recordedSeconds = 30,
    this.validReadings = 1,
    this.invalidReadings = 0,
    this.demo = false,
  });

  final String id;
  final String patient;
  final double spo2, bpm;
  final DateTime at;
  final Limits limits;

  /// Seconds the sensor recorded before the result arrived.
  final int recordedSeconds;

  /// Result notifications accepted / rejected as implausible during the run.
  final int validReadings, invalidReadings;
  final bool demo;

  /// App-derived quality grade (not a sensor signal-quality metric).
  String get quality {
    if (demo) return 'Simulated';
    if (recordedSeconds < 28) return 'Incomplete';
    if (invalidReadings > 0) return 'Fair';
    return 'Good';
  }

  String get qualityNote {
    switch (quality) {
      case 'Simulated':
        return 'Demo data, not measured by a sensor.';
      case 'Incomplete':
        return 'Recording ended before the full 30 seconds.';
      case 'Fair':
        return 'Some invalid readings were received during recording; the final reading was valid.';
      default:
        return 'Full recording completed with no invalid readings.';
    }
  }

  bool get spo2Ok => spo2 >= limits.spo2Min && spo2 <= limits.spo2Max;
  bool get bpmOk => bpm >= limits.bpmMin && bpm <= limits.bpmMax;
  bool get allOk => spo2Ok && bpmOk;

  Measurement withLimits(Limits l) => Measurement(
    id: id,
    patient: patient,
    spo2: spo2,
    bpm: bpm,
    at: at,
    limits: l,
    recordedSeconds: recordedSeconds,
    validReadings: validReadings,
    invalidReadings: invalidReadings,
    demo: demo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient': patient,
    'spo2': spo2,
    'bpm': bpm,
    'at': at.toIso8601String(),
    'limits': limits.toJson(),
    'recordedSeconds': recordedSeconds,
    'validReadings': validReadings,
    'invalidReadings': invalidReadings,
    'demo': demo,
  };

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
    id: j['id'] as String,
    patient: j['patient'] as String,
    spo2: (j['spo2'] as num).toDouble(),
    bpm: (j['bpm'] as num).toDouble(),
    at: DateTime.parse(j['at'] as String),
    limits: Limits.fromJson(j['limits'] as Map<String, dynamic>),
    recordedSeconds: (j['recordedSeconds'] as num?)?.toInt() ?? 30,
    validReadings: (j['validReadings'] as num?)?.toInt() ?? 1,
    invalidReadings: (j['invalidReadings'] as num?)?.toInt() ?? 0,
    demo: j['demo'] as bool? ?? false,
  );

  static String encodeList(List<Measurement> l) =>
      jsonEncode(l.map((e) => e.toJson()).toList());

  static List<Measurement> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Measurement.fromJson(e as Map<String, dynamic>))
      .toList();
}
