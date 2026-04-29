import 'dart:async';
import 'dart:math';

import 'models.dart';
import 'simulated_surveillance_repository.dart';

class EpidemicMonitorBloc {
  EpidemicMonitorBloc({required SurveillanceRepository repository})
    : _repository = repository {
    _manualInputSubscription = _manualInputController.stream
        .asyncMap(_repository.submitReport)
        .listen((_) {});

    _repositorySubscription = _repository.liveReports.listen(
      _handleIncomingReport,
    );
    _repository.startSimulation();
    _emitState();
  }

  final SurveillanceRepository _repository;
  final StreamController<SymptomReport> _manualInputController =
      StreamController<SymptomReport>();
  final StreamController<DashboardState> _dashboardController =
      StreamController<DashboardState>.broadcast();
  final StreamController<HealthAlert> _alertController =
      StreamController<HealthAlert>.broadcast();

  late final StreamSubscription<void> _manualInputSubscription;
  late final StreamSubscription<SymptomReport> _repositorySubscription;

  final List<SymptomReport> _reports = [];
  final List<HealthAlert> _alerts = [];
  final Map<String, DateTime> _recentAlertKeys = {};

  DashboardState _currentState = DashboardState.initial();
  bool _simulatorActive = true;

  Sink<SymptomReport> get reportSink => _manualInputController.sink;
  Stream<DashboardState> get dashboardStream => _dashboardController.stream;
  Stream<HealthAlert> get alertStream => _alertController.stream;
  DashboardState get currentState => _currentState;

  Future<void> submitReport(SymptomReport report) async {
    reportSink.add(report);
  }

  void setSimulationActive(bool isActive) {
    _simulatorActive = isActive;
    if (isActive) {
      _repository.startSimulation();
    } else {
      _repository.stopSimulation();
    }
    _emitState();
  }

  void simulateCluster(String zone) {
    final repository = _repository;
    if (repository is SimulatedSurveillanceRepository) {
      repository.injectCluster(zone);
    }
  }

  void _handleIncomingReport(SymptomReport report) {
    _reports.add(report);
    _trimOldReports();
    _emitState(lastReport: report);
  }

  void _trimOldReports() {
    final limit = DateTime.now().subtract(const Duration(hours: 24));
    _reports.removeWhere((report) => report.reportedAt.isBefore(limit));
  }

  void _emitState({SymptomReport? lastReport}) {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final twoHoursAgo = now.subtract(const Duration(hours: 2));

    final recentReports =
        _reports
            .where((report) => report.reportedAt.isAfter(oneHourAgo))
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

    final previousReports = _reports
        .where(
          (report) =>
              report.reportedAt.isAfter(twoHoursAgo) &&
              report.reportedAt.isBefore(oneHourAgo),
        )
        .toList();

    final allZones = <String>{
      ..._reports.map((report) => report.zone),
      ..._repository.supportedZones,
    }.toList()..sort();

    final zoneSnapshots = allZones.map((zone) {
      final zoneRecent = recentReports
          .where((report) => report.zone == zone)
          .toList();
      final zonePrevious = previousReports
          .where((report) => report.zone == zone)
          .toList();

      final symptomFrequency = <String, int>{};
      for (final report in zoneRecent) {
        for (final symptom in report.symptomLabels) {
          symptomFrequency.update(
            symptom,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      return ZoneSnapshot(
        zone: zone,
        recentCount: zoneRecent.length,
        previousCount: zonePrevious.length,
        timeline: _buildTimeline(
          _reports.where((report) => report.zone == zone).toList(),
          bucketMinutes: 10,
          buckets: 6,
          now: now,
        ),
        symptomFrequency: symptomFrequency,
        riskLevel: _resolveRiskLevel(
          recent: zoneRecent.length,
          previous: zonePrevious.length,
          symptomFrequency: symptomFrequency,
        ),
        predictedNextHour: _predictNextHour(
          recent: zoneRecent.length,
          previous: zonePrevious.length,
        ),
        lastUpdate: zoneRecent.isEmpty ? null : zoneRecent.first.reportedAt,
      );
    }).toList()..sort((a, b) => b.recentCount.compareTo(a.recentCount));

    final alerts = _computeAlerts(zoneSnapshots, now);
    final globalTimeline = _buildTimeline(
      _reports,
      bucketMinutes: 10,
      buckets: 6,
      now: now,
    );
    final topSymptom = _globalTopSymptom(recentReports);
    final zoneHeat = <String, double>{
      for (final zone in zoneSnapshots)
        zone.zone: recentReports.isEmpty
            ? 0
            : zone.recentCount / max(1, recentReports.length),
    };

    _currentState = DashboardState(
      zoneSnapshots: zoneSnapshots,
      alerts: alerts,
      recentReports: recentReports.take(6).toList(),
      globalTimeline: globalTimeline,
      zoneHeat: zoneHeat,
      totalReports24h: _reports.length,
      reportsLastHour: recentReports.length,
      risingZones: zoneSnapshots.where((zone) => zone.isRising).length,
      topSymptom: topSymptom,
      projectedLoad: zoneSnapshots.fold<double>(
        0,
        (sum, zone) => sum + zone.predictedNextHour,
      ),
      simulatorActive: _simulatorActive,
      lastUpdated: lastReport?.reportedAt ?? _currentState.lastUpdated,
    );

    _dashboardController.add(_currentState);
  }

  List<HealthAlert> _computeAlerts(List<ZoneSnapshot> snapshots, DateTime now) {
    final generated = <HealthAlert>[];

    for (final snapshot in snapshots) {
      final dominant = snapshot.symptomFrequency[snapshot.topSymptom] ?? 0;
      final shouldAlert =
          snapshot.recentCount >= 6 ||
          snapshot.trendDelta >= 3 ||
          dominant >= 4;

      if (!shouldAlert) {
        continue;
      }

      final alertKey =
          '${snapshot.zone}-${snapshot.topSymptom}-${snapshot.riskLevel.name}';
      final lastAlert = _recentAlertKeys[alertKey];
      final isOnCooldown =
          lastAlert != null &&
          now.difference(lastAlert) < const Duration(minutes: 15);

      final alert = HealthAlert(
        id: '$alertKey-${now.millisecondsSinceEpoch}',
        zone: snapshot.zone,
        message:
            'Posible aumento de casos con ${snapshot.topSymptom.toLowerCase()} en ${snapshot.zone}',
        riskLevel: snapshot.riskLevel,
        createdAt: now,
        metricValue: snapshot.recentCount,
      );

      generated.add(alert);

      if (!isOnCooldown) {
        _recentAlertKeys[alertKey] = now;
        _alerts.insert(0, alert);
        if (_alerts.length > 8) {
          _alerts.removeRange(8, _alerts.length);
        }
        _alertController.add(alert);
      }
    }

    return _alerts.isEmpty ? generated : _alerts.take(5).toList();
  }

  List<int> _buildTimeline(
    List<SymptomReport> reports, {
    required int bucketMinutes,
    required int buckets,
    required DateTime now,
  }) {
    final values = List<int>.filled(buckets, 0);

    for (final report in reports) {
      final diff = now.difference(report.reportedAt).inMinutes;
      if (diff < 0 || diff >= bucketMinutes * buckets) {
        continue;
      }
      final index = buckets - 1 - (diff ~/ bucketMinutes);
      if (index >= 0 && index < values.length) {
        values[index] += 1;
      }
    }

    return values;
  }

  RiskLevel _resolveRiskLevel({
    required int recent,
    required int previous,
    required Map<String, int> symptomFrequency,
  }) {
    final dominant = symptomFrequency.values.isEmpty
        ? 0
        : symptomFrequency.values.reduce(max);
    final delta = recent - previous;

    if (recent >= 7 || delta >= 3 || dominant >= 5) {
      return RiskLevel.high;
    }
    if (recent >= 4 || delta >= 1 || dominant >= 3) {
      return RiskLevel.medium;
    }
    return RiskLevel.low;
  }

  double _predictNextHour({required int recent, required int previous}) {
    final trend = recent - previous;
    return max(0, recent + max(0, trend * 0.8));
  }

  String _globalTopSymptom(List<SymptomReport> recentReports) {
    final counts = <String, int>{};
    for (final report in recentReports) {
      for (final symptom in report.symptomLabels) {
        counts.update(symptom, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    if (counts.isEmpty) {
      return 'Sin datos';
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<void> dispose() async {
    _repository.stopSimulation();
    await _manualInputSubscription.cancel();
    await _repositorySubscription.cancel();
    await _manualInputController.close();
    await _dashboardController.close();
    await _alertController.close();
    _repository.dispose();
  }
}
