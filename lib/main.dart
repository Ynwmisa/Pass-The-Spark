import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'repositories/demo_today_repository.dart';
import 'repositories/today_repository.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'services/draft_store.dart';

void main() {
  runApp(const PassTheSparkApp());
}

class PassTheSparkApp extends StatefulWidget {
  const PassTheSparkApp({
    super.key,
    this.repository = const DemoTodayRepository(),
    this.draftStore,
  });
  final TodayRepository repository;
  final DraftStore? draftStore;

  @override
  State<PassTheSparkApp> createState() => _PassTheSparkAppState();
}

class _PassTheSparkAppState extends State<PassTheSparkApp> {
  late final GoRouter _router = createAppRouter(
    widget.repository,
    widget.draftStore ?? FileDraftStore(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Pass the Spark',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    routerConfig: _router,
  );
}
