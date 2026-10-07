import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../services/account_session.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key, required this.session});
  final AccountSession session;
  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your drafts stay on this device under your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.signOut();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.session.account;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            account?.displayName ?? 'Student',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(account?.email ?? ''),
          const SizedBox(height: 24),
          const Text('Your groups are private to accepted members.'),
          const SizedBox(height: 24),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          FilledButton(
            onPressed: _busy ? null : _logout,
            child: Text(_busy ? 'Signing out…' : 'Sign out'),
          ),
        ],
      ),
    );
  }
}
