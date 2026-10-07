import '../../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../repositories/supabase_group_repository.dart';
import '../../services/account_session.dart';
import 'account.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({super.key, required this.session, required this.client});
  final AccountSession session;
  final SupabaseClient client;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final account = session.account;
      if (account == null || session.recovering) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          home: AccountScreen(session: session),
        );
      }
      return _SignedInApplication(
        key: ValueKey(account.id),
        client: client,
        session: session,
      );
    },
  );
}

class _SignedInApplication extends StatefulWidget {
  const _SignedInApplication({
    super.key,
    required this.client,
    required this.session,
  });
  final SupabaseClient client;
  final AccountSession session;
  @override
  State<_SignedInApplication> createState() => _SignedInApplicationState();
}

class _SignedInApplicationState extends State<_SignedInApplication> {
  late final _groups = SupabaseGroupRepository(widget.client);
  @override
  void dispose() {
    _groups.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PassTheSparkApp(repository: _groups, accountSession: widget.session);
}
