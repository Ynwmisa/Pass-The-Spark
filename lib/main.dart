import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'repositories/group_repository.dart';
import 'repositories/local_group_repository.dart';
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
    this.repository,
    this.groupRepository,
    this.draftStore,
  });
  final TodayRepository? repository;
  final GroupRepository? groupRepository;
  final DraftStore? draftStore;

  @override
  State<PassTheSparkApp> createState() => _PassTheSparkAppState();
}

class _PassTheSparkAppState extends State<PassTheSparkApp> {
  late final LocalGroupRepository? _ownedGroups =
      widget.groupRepository == null && widget.repository is! GroupRepository
      ? LocalGroupRepository()
      : null;
  late final GroupRepository _groups =
      widget.groupRepository ??
      (widget.repository is GroupRepository
          ? widget.repository! as GroupRepository
          : _ownedGroups!);
  late final TodayRepository _repository = widget.repository ?? _groups;
  late final GoRouter _router = createAppRouter(
    _repository,
    widget.draftStore ?? FileDraftStore(),
    _groups,
  );

  @override
  void dispose() {
    _router.dispose();
    _ownedGroups?.dispose();
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
