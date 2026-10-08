import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../services/account_session.dart';

enum _Step { signIn, register, confirm, recovery, awaitingRecovery, password }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.session});
  final AccountSession session;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _Step _step = _Step.signIn;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.session.recovering) _step = _Step.password;
    widget.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted && widget.session.recovering && _step != _Step.password) {
      _switch(_Step.password);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    for (final c in [_name, _email, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(_Step step) {
    setState(() {
      _step = step;
      _error = null;
      _message = null;
      _password.clear();
      _confirmation.clear();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not complete the request. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      switch (_step) {
        case _Step.signIn:
          await widget.session.signIn(_email.text, _password.text);
        case _Step.register:
          final confirm = await widget.session.register(
            _name.text,
            _email.text,
            _password.text,
          );
          if (mounted && confirm) _switch(_Step.confirm);
        case _Step.confirm:
          _switch(_Step.signIn);
        case _Step.recovery:
          await widget.session.requestRecovery(_email.text);
          if (mounted) _switch(_Step.awaitingRecovery);
        case _Step.awaitingRecovery:
          await widget.session.requestRecovery(_email.text);
          if (mounted) {
            setState(
              () => _message =
                  'If the account exists, another reset link has been requested.',
            );
          }
        case _Step.password:
          await widget.session.setPassword(_password.text);
          if (mounted) {
            _switch(_Step.signIn);
            setState(
              () => _message =
                  'Password updated. Sign in with your new password.',
            );
          }
      }
    });
  }

  Future<void> _back() => _run(() async {
    if (widget.session.recovering) await widget.session.signOut();
    if (mounted) _switch(_Step.signIn);
  });

  @override
  Widget build(BuildContext context) {
    final hasEmail = [
      _Step.signIn,
      _Step.register,
      _Step.confirm,
      _Step.recovery,
    ].contains(_step);
    final hasPassword = [
      _Step.signIn,
      _Step.register,
      _Step.password,
    ].contains(_step);
    final title = switch (_step) {
      _Step.signIn => 'Welcome back',
      _Step.register => 'Create your account',
      _Step.confirm => 'Confirm your email',
      _Step.recovery => 'Reset your password',
      _Step.awaitingRecovery => 'Check your email',
      _Step.password => 'Choose a new password',
    };
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pass the Spark')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  _step == _Step.confirm
                      ? 'Open the confirmation link in your email on this device. If you already confirmed it elsewhere, return here and sign in.'
                      : _step == _Step.awaitingRecovery
                      ? 'If an account exists for ${_email.text.trim()}, a reset link has been requested. Open it on this device to choose a new password.'
                      : 'A little connection, one spark at a time.',
                ),
                const SizedBox(height: 24),
                if (_step == _Step.register) ...[
                  TextFormField(
                    key: const ValueKey('name'),
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (hasEmail) ...[
                  TextFormField(
                    key: const ValueKey('email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (hasPassword) ...[
                  TextFormField(
                    key: const ValueKey('password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      _step == _Step.signIn
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password.';
                      if (_step != _Step.signIn && v.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_step != _Step.signIn) ...[
                    TextFormField(
                      key: const ValueKey('confirmation'),
                      controller: _confirmation,
                      enabled: !_busy,
                      obscureText: _hide,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == _password.text
                          ? null
                          : 'The passwords do not match.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_message != null) ...[
                  Semantics(liveRegion: true, child: Text(_message!)),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Please wait…'
                        : switch (_step) {
                            _Step.signIn => 'Sign in',
                            _Step.register => 'Create account',
                            _Step.confirm => 'Back to sign in',
                            _Step.recovery => 'Send reset link',
                            _Step.awaitingRecovery => 'Resend reset link',
                            _Step.password => 'Save new password',
                          },
                  ),
                ),
                const SizedBox(height: 12),
                if (_step == _Step.signIn) ...[
                  TextButton(
                    onPressed: _busy ? null : () => _switch(_Step.register),
                    child: const Text('Create an account'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _switch(_Step.recovery),
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _switch(_Step.confirm),
                    child: const Text('Resend account confirmation'),
                  ),
                ] else ...[
                  if (_step == _Step.confirm)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_form.currentState!.validate()) {
                                _run(() async {
                                  await widget.session.resendConfirmation(
                                    _email.text,
                                  );
                                  if (mounted) {
                                    setState(
                                      () => _message =
                                          'Confirmation requested. Check your email.',
                                    );
                                  }
                                });
                              }
                            },
                      child: const Text('Resend confirmation link'),
                    ),
                  if (_step != _Step.confirm)
                    TextButton(
                      onPressed: _busy ? null : _back,
                      child: const Text('Back to sign in'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
