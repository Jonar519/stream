import 'dart:async';
import 'dart:math';

import 'models.dart';

abstract class SurveillanceRepository {
  Stream<SymptomReport> get liveReports;

  List<String> get supportedZones;

  Future<void> submitReport(SymptomReport report);

  void startSimulation();

  void stopSimulation();

  void dispose();
}

class SimulatedSurveillanceRepository implements SurveillanceRepository {
  SimulatedSurveillanceRepository();

  final StreamController<SymptomReport> _reportsController =
      StreamController<SymptomReport>.broadcast();
  final Random _random = Random();

  final List<String> _zones = const [
    'Bogota Centro',
    'Bogota Norte',
    'Medellin Sur',
    'Cali Oeste',
    'Barranquilla Norte',
    'Bucaramanga Este',
    'Cartagena Centro',
    'Pereira Norte',
  ];

  final Map<String, double> _zoneWeights = {
    'Bogota Centro': 1.8,
    'Bogota Norte': 1.2,
    'Medellin Sur': 1.1,
    'Cali Oeste': 1.0,
    'Barranquilla Norte': 0.9,
    'Bucaramanga Este': 0.8,
    'Cartagena Centro': 0.7,
    'Pereira Norte': 0.6,
  };

  Timer? _simulationTimer;

  @override
  Stream<SymptomReport> get liveReports => _reportsController.stream;

  @override
  List<String> get supportedZones => List.unmodifiable(_zones);

  @override
  Future<void> submitReport(SymptomReport report) async {
    _reportsController.add(report);
  }

  @override
  void startSimulation() {
    _simulationTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _emitSyntheticBatch(),
    );

    for (var i = 0; i < 8; i++) {
      _reportsController.add(_generateReport(backfillMinutes: 120 - (i * 12)));
    }
  }

  @override
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void injectCluster(String zone, {int count = 6}) {
    for (var i = 0; i < count; i++) {
      _reportsController.add(
        _generateReport(
          forcedZone: zone,
          forcedSymptoms: const {
            SymptomType.fever,
            SymptomType.cough,
            SymptomType.headache,
          },
        ),
      );
    }
  }

  void _emitSyntheticBatch() {
    final batchSize = _random.nextInt(2) + 1;
    for (var i = 0; i < batchSize; i++) {
      _reportsController.add(_generateReport());
    }
  }

  SymptomReport _generateReport({
    String? forcedZone,
    Set<SymptomType>? forcedSymptoms,
    int backfillMinutes = 0,
  }) {
    final zone = forcedZone ?? _pickWeightedZone();
    final symptoms = forcedSymptoms ?? _pickSymptoms();
    final customSymptoms = symptoms.contains(SymptomType.custom)
        ? [_randomCustomSymptom()]
        : const <String>[];

    return SymptomReport(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
      zone: zone,
      reportedAt: DateTime.now().subtract(Duration(minutes: backfillMinutes)),
      symptoms: symptoms,
      customSymptoms: customSymptoms,
    );
  }

  String _pickWeightedZone() {
    final totalWeight = _zoneWeights.values.fold<double>(
      0,
      (sum, w) => sum + w,
    );
    var cursor = _random.nextDouble() * totalWeight;

    for (final entry in _zoneWeights.entries) {
      cursor -= entry.value;
      if (cursor <= 0) {
        return entry.key;
      }
    }

    return _zones.first;
  }

  Set<SymptomType> _pickSymptoms() {
    final symptoms = <SymptomType>{};

    if (_random.nextDouble() > 0.35) {
      symptoms.add(SymptomType.fever);
    }
    if (_random.nextDouble() > 0.4) {
      symptoms.add(SymptomType.cough);
    }
    if (_random.nextDouble() > 0.5) {
      symptoms.add(SymptomType.headache);
    }
    if (_random.nextDouble() > 0.82) {
      symptoms.add(SymptomType.custom);
    }

    if (symptoms.isEmpty) {
      symptoms.add(SymptomType.headache);
    }

    return symptoms;
  }

  String _randomCustomSymptom() {
    const custom = [
      'Dolor de garganta',
      'Congestion nasal',
      'Escalofrios',
      'Fatiga',
      'Malestar general',
    ];

    return custom[_random.nextInt(custom.length)];
  }

  @override
  void dispose() {
    stopSimulation();
    _reportsController.close();
  }
}
