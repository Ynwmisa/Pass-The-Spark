import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/account/account_gate.dart';
import 'screens/account/backend_setup.dart';
import 'services/account_session.dart';
import 'services/backend_config.dart';
import 'services/secure_session_storage.dart';
import 'services/supabase_account_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'repositories/group_repository.dart';
import 'repositories/local_group_repository.dart';
import 'repositories/today_repository.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'services/draft_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('DEMO_MODE')) {
    runApp(const PassTheSparkApp());
    return;
  }
  const config = BackendConfig.environment();
  final error = config.validationError;
  if (error != null) {
    runApp(
      MaterialApp(
        theme: appTheme,
        home: BackendSetupScreen(message: error),
      ),
    );
    return;
  }
  try {
    final backend = await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUri: true,
        detectSessionInUriPredicate: (uri) =>
            uri.scheme == 'passthespark' && uri.host == 'auth-callback',
        pkceAsyncStorage: SecurePkceStorage(),
        localStorage: SecureSessionStorage(Uri.parse(config.url).host),
      ),
    );
    runApp(BackendApplication(client: backend.client));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme,
        home: const BackendSetupScreen(
          message:
              'The account service could not be started. Check the configuration and restart the app.',
        ),
      ),
    );
  }
}

class BackendApplication extends StatefulWidget {
  const BackendApplication({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<BackendApplication> createState() => _BackendApplicationState();
}

class _BackendApplicationState extends State<BackendApplication> {
  late final _session = SupabaseAccountSession(widget.client);
  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AccountGate(session: _session, client: widget.client);
}

class PassTheSparkApp extends StatefulWidget {
  const PassTheSparkApp({
    super.key,
    this.repository,
    this.groupRepository,
    this.draftStore,
    this.accountSession,
  });
  final TodayRepository? repository;
  final GroupRepository? groupRepository;
  final DraftStore? draftStore;
  final AccountSession? accountSession;

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
    accountSession: widget.accountSession,
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
