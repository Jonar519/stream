import 'package:flutter/material.dart';

import 'src/features/surveillance/epidemic_monitor_bloc.dart';
import 'src/features/surveillance/home_page.dart';
import 'src/features/surveillance/simulated_surveillance_repository.dart';
import 'src/theme/app_theme.dart';

void main() {
  runApp(const EpidemiologicalRadarApp());
}

class EpidemiologicalRadarApp extends StatefulWidget {
  const EpidemiologicalRadarApp({super.key});

  @override
  State<EpidemiologicalRadarApp> createState() => _EpidemiologicalRadarAppState();
}

class _EpidemiologicalRadarAppState extends State<EpidemiologicalRadarApp> {
  late final EpidemicMonitorBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = EpidemicMonitorBloc(
      repository: SimulatedSurveillanceRepository(),
    );
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Radar Epidemiologico',
      theme: buildAppTheme(),
      home: SurveillanceHomePage(bloc: _bloc),
    );
  }
}
