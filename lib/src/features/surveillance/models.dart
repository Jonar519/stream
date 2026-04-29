enum SymptomType { fever, cough, headache, custom }

extension SymptomTypeLabel on SymptomType {
  String get label {
    switch (this) {
      case SymptomType.fever:
        return 'Fiebre';
      case SymptomType.cough:
        return 'Tos';
      case SymptomType.headache:
        return 'Dolor de cabeza';
      case SymptomType.custom:
        return 'Otros';
    }
  }
}

enum RiskLevel { low, medium, high }

class SymptomReport {
  SymptomReport({
    required this.id,
    required this.zone,
    required this.reportedAt,
    required this.symptoms,
    required this.customSymptoms,
  });

  final String id;
  final String zone;
  final DateTime reportedAt;
  final Set<SymptomType> symptoms;
  final List<String> customSymptoms;

  List<String> get symptomLabels {
    final labels = symptoms
        .where((type) => type != SymptomType.custom)
        .map((type) => type.label)
        .toList();

    if (customSymptoms.isNotEmpty) {
      labels.addAll(customSymptoms);
    }

    return labels;
  }
}

class ZoneSnapshot {
  ZoneSnapshot({
    required this.zone,
    required this.recentCount,
    required this.previousCount,
    required this.timeline,
    required this.symptomFrequency,
    required this.riskLevel,
    required this.predictedNextHour,
    required this.lastUpdate,
  });

  final String zone;
  final int recentCount;
  final int previousCount;
  final List<int> timeline;
  final Map<String, int> symptomFrequency;
  final RiskLevel riskLevel;
  final double predictedNextHour;
  final DateTime? lastUpdate;

  int get trendDelta => recentCount - previousCount;
  bool get isRising => trendDelta > 0;

  String get topSymptom {
    if (symptomFrequency.isEmpty) {
      return 'Sin datos';
    }

    final sorted = symptomFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class HealthAlert {
  HealthAlert({
    required this.id,
    required this.zone,
    required this.message,
    required this.riskLevel,
    required this.createdAt,
    required this.metricValue,
  });

  final String id;
  final String zone;
  final String message;
  final RiskLevel riskLevel;
  final DateTime createdAt;
  final int metricValue;
}

class DashboardState {
  DashboardState({
    required this.zoneSnapshots,
    required this.alerts,
    required this.recentReports,
    required this.globalTimeline,
    required this.zoneHeat,
    required this.totalReports24h,
    required this.reportsLastHour,
    required this.risingZones,
    required this.topSymptom,
    required this.projectedLoad,
    required this.simulatorActive,
    required this.lastUpdated,
  });

  final List<ZoneSnapshot> zoneSnapshots;
  final List<HealthAlert> alerts;
  final List<SymptomReport> recentReports;
  final List<int> globalTimeline;
  final Map<String, double> zoneHeat;
  final int totalReports24h;
  final int reportsLastHour;
  final int risingZones;
  final String topSymptom;
  final double projectedLoad;
  final bool simulatorActive;
  final DateTime? lastUpdated;

  factory DashboardState.initial() {
    return DashboardState(
      zoneSnapshots: const [],
      alerts: const [],
      recentReports: const [],
      globalTimeline: const [0, 0, 0, 0, 0, 0],
      zoneHeat: const {},
      totalReports24h: 0,
      reportsLastHour: 0,
      risingZones: 0,
      topSymptom: 'Sin datos',
      projectedLoad: 0,
      simulatorActive: true,
      lastUpdated: null,
    );
  }
}
