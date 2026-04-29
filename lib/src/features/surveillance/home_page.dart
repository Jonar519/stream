import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'epidemic_monitor_bloc.dart';
import 'models.dart';

class SurveillanceHomePage extends StatefulWidget {
  const SurveillanceHomePage({super.key, required this.bloc});

  final EpidemicMonitorBloc bloc;

  @override
  State<SurveillanceHomePage> createState() => _SurveillanceHomePageState();
}

class _SurveillanceHomePageState extends State<SurveillanceHomePage> {
  static const _defaultZones = [
    'Bogota Centro',
    'Bogota Norte',
    'Medellin Sur',
    'Cali Oeste',
    'Barranquilla Norte',
    'Bucaramanga Este',
    'Cartagena Centro',
    'Pereira Norte',
  ];

  final TextEditingController _customSymptomsController =
      TextEditingController();
  final Set<SymptomType> _selectedSymptoms = {
    SymptomType.fever,
    SymptomType.cough,
  };

  StreamSubscription<HealthAlert>? _alertSubscription;
  String _selectedZone = _defaultZones.first;

  @override
  void initState() {
    super.initState();
    _alertSubscription = widget.bloc.alertStream.listen((alert) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _riskColor(alert.riskLevel),
            content: Text(alert.message),
          ),
        );
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _customSymptomsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardState>(
      stream: widget.bloc.dashboardStream,
      initialData: widget.bloc.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? DashboardState.initial();

        return Scaffold(
          appBar: AppBar(title: const Text('Radar Epidemiologico')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(context, state),
                  const SizedBox(height: 18),
                  _buildReportComposer(context),
                  const SizedBox(height: 18),
                  _buildKpiGrid(state),
                  const SizedBox(height: 18),
                  _Panel(
                    title: 'Tendencia en tiempo real',
                    subtitle:
                        'Ultima hora agregada en intervalos de 10 minutos y actualizacion sin recarga.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 170,
                          child: _TrendChart(
                            values: state.globalTimeline,
                            lineColor: Theme.of(context).colorScheme.primary,
                            fillColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('-60m'),
                            Text('-40m'),
                            Text('-20m'),
                            Text('Ahora'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    title: 'Mapa de calor comunitario',
                    subtitle:
                        'Las zonas cambian de verde a rojo segun la concentracion relativa de reportes.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: state.zoneHeat.entries
                          .map(
                            (entry) => _HeatCell(
                              zone: entry.key,
                              intensity: entry.value,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    title: 'Analisis por zona',
                    subtitle:
                        'Priorizacion automatica por frecuencia, tendencia y prediccion.',
                    child: Column(
                      children: state.zoneSnapshots.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'Aun no hay reportes para analizar.',
                                ),
                              ),
                            ]
                          : state.zoneSnapshots
                                .take(5)
                                .map((zone) => _ZoneTile(snapshot: zone))
                                .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    title: 'Alertas inteligentes',
                    subtitle:
                        'Se activan cuando la frecuencia supera el umbral o aparece un incremento repentino.',
                    child: Column(
                      children: state.alerts.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'Sin alertas activas por el momento.',
                                ),
                              ),
                            ]
                          : state.alerts
                                .map((alert) => _AlertTile(alert: alert))
                                .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    title: 'Reportes recientes',
                    subtitle: 'Ultimos registros recibidos desde la comunidad.',
                    child: Column(
                      children: state.recentReports.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text('Esperando nuevos reportes...'),
                              ),
                            ]
                          : state.recentReports
                                .map((report) => _ReportTile(report: report))
                                .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(BuildContext context, DashboardState state) {
    final highestRisk = state.zoneSnapshots.fold<RiskLevel>(
      RiskLevel.low,
      (current, zone) =>
          zone.riskLevel.index > current.index ? zone.riskLevel : current,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F766E),
            _riskColor(highestRisk).withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.health_and_safety_outlined, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoreo epidemiologico comunitario',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Procesamiento reactivo con streams para deteccion temprana de brotes.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricPill(
                label: 'Riesgo actual',
                value: _riskLabel(highestRisk),
                color: _riskColor(highestRisk),
              ),
              _MetricPill(
                label: 'Zonas activas',
                value:
                    '${state.zoneSnapshots.where((zone) => zone.recentCount > 0).length}',
                color: Theme.of(context).colorScheme.secondary,
              ),
              _MetricPill(
                label: 'Proyeccion 1h',
                value: state.projectedLoad.toStringAsFixed(0),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  value: state.simulatorActive,
                  onChanged: widget.bloc.setSimulationActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simulador en tiempo real'),
                  subtitle: const Text(
                    'Genera trafico sintomatico para pruebas.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportComposer(BuildContext context) {
    return _Panel(
      title: 'Registrar reporte',
      subtitle:
          'Captura sintomas, zona aproximada y dispara el procesamiento inmediato.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedZone,
            items: _defaultZones
                .map(
                  (zone) =>
                      DropdownMenuItem<String>(value: zone, child: Text(zone)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedZone = value);
            },
            decoration: const InputDecoration(
              labelText: 'Ubicacion aproximada',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSymptomChip(SymptomType.fever),
              _buildSymptomChip(SymptomType.cough),
              _buildSymptomChip(SymptomType.headache),
              _buildSymptomChip(SymptomType.custom),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _customSymptomsController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Otros sintomas personalizados',
              hintText: 'Ej: dolor de garganta, escalofrios',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _submitReport,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Enviar reporte'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.bloc.simulateCluster(_selectedZone),
                icon: const Icon(Icons.auto_graph_rounded),
                label: const Text('Simular brote'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomChip(SymptomType type) {
    final isSelected = _selectedSymptoms.contains(type);

    return FilterChip(
      label: Text(type.label),
      selected: isSelected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _selectedSymptoms.add(type);
          } else {
            _selectedSymptoms.remove(type);
          }
        });
      },
    );
  }

  Widget _buildKpiGrid(DashboardState state) {
    final cards = [
      _KpiData(
        label: 'Reportes 24h',
        value: '${state.totalReports24h}',
        caption: 'Acumulado reciente',
        icon: Icons.monitor_heart_outlined,
      ),
      _KpiData(
        label: 'Ultima hora',
        value: '${state.reportsLastHour}',
        caption: 'Flujo en tiempo real',
        icon: Icons.bolt_rounded,
      ),
      _KpiData(
        label: 'Zonas en alza',
        value: '${state.risingZones}',
        caption: 'Tendencia ascendente',
        icon: Icons.trending_up_rounded,
      ),
      _KpiData(
        label: 'Sintoma dominante',
        value: state.topSymptom,
        caption: 'Mayor frecuencia actual',
        icon: Icons.coronavirus_outlined,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) => _KpiCard(data: cards[index]),
    );
  }

  void _submitReport() {
    final trimmedCustom = _customSymptomsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (_selectedSymptoms.isEmpty && trimmedCustom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un sintoma.')),
      );
      return;
    }

    final symptoms = {..._selectedSymptoms};
    if (trimmedCustom.isNotEmpty) {
      symptoms.add(SymptomType.custom);
    }

    widget.bloc.submitReport(
      SymptomReport(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        zone: _selectedZone,
        reportedAt: DateTime.now(),
        symptoms: symptoms,
        customSymptoms: trimmedCustom,
      ),
    );

    _customSymptomsController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte enviado correctamente.')),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(
              data.value,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(data.label),
            const SizedBox(height: 4),
            Text(
              data.caption,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.zone, required this.intensity});

  final String zone;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      const Color(0xFF22C55E),
      const Color(0xFFEF4444),
      intensity.clamp(0, 1),
    )!;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(zone, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: intensity.clamp(0.04, 1),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text('${(intensity * 100).round()}% concentracion relativa'),
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.snapshot});

  final ZoneSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.zone,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _RiskBadge(level: snapshot.riskLevel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Reportes 1h',
                  value: '${snapshot.recentCount}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Tendencia',
                  value: snapshot.isRising
                      ? '+${snapshot.trendDelta}'
                      : '${snapshot.trendDelta}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Prediccion',
                  value: snapshot.predictedNextHour.toStringAsFixed(0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: _TrendChart(
              values: snapshot.timeline,
              lineColor: _riskColor(snapshot.riskLevel),
              fillColor: _riskColor(snapshot.riskLevel),
            ),
          ),
          const SizedBox(height: 12),
          Text('Sintoma predominante: ${snapshot.topSymptom}'),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final HealthAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(alert.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Zona: ${alert.zone}  |  Reportes: ${alert.metricValue}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final SymptomReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.zone,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(_formatTime(report.reportedAt)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: report.symptomLabels
                .map((label) => Chip(label: Text(label)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
      ),
      child: Text(
        _riskLabel(level),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendChartPainter(
        values: values,
        lineColor: lineColor,
        fillColor: fillColor,
      ),
      child: Container(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      return;
    }

    final maxValue = max(1, values.reduce(max));
    final stepX = values.length == 1
        ? size.width
        : size.width / (values.length - 1);
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final normalized = values[i] / maxValue;
      final x = stepX * i;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          fillColor.withValues(alpha: 0.28),
          fillColor.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

Color _riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return const Color(0xFF22C55E);
    case RiskLevel.medium:
      return const Color(0xFFFACC15);
    case RiskLevel.high:
      return const Color(0xFFEF4444);
  }
}

String _riskLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return 'Normal';
    case RiskLevel.medium:
      return 'Precaucion';
    case RiskLevel.high:
      return 'Alerta';
  }
}

String _formatTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}
