import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/models/account.dart';
import 'package:pass_the_spark/screens/account/account.dart';
import 'package:pass_the_spark/services/account_session.dart';
import 'package:pass_the_spark/theme/app_theme.dart';

class TestAccountSession extends ChangeNotifier implements AccountSession {
  @override
  SparkAccount? account;
  @override
  bool recovering = false;
  bool fail = false;
  Completer<void>? pending;
  int signIns = 0;
  int registrations = 0;
  int resets = 0;
  @override
  Future<bool> register(String n, String e, String p) async {
    registrations++;
    return true;
  }

  @override
  Future<void> signIn(String e, String p) async {
    signIns++;
    if (pending != null) await pending!.future;
    if (fail) {
      throw const AccountException('The email or password is incorrect.');
    }
  }

  @override
  Future<void> resendConfirmation(String e) async {}
  @override
  Future<void> requestRecovery(String e) async {
    resets++;
  }

  @override
  Future<void> setPassword(String p) async {
    recovering = false;
  }

  @override
  Future<void> signOut() async {
    account = null;
    recovering = false;
    notifyListeners();
  }
}

void main() {
  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Future<void> open(WidgetTester t, TestAccountSession s) async {
    addTearDown(s.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: AccountScreen(session: s),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('invalid sign in never calls the service', (t) async {
    final s = TestAccountSession();
    await open(t, s);
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(s.signIns, 0);
  });
  testWidgets('service failure keeps email and allows retry', (t) async {
    final s = TestAccountSession()..fail = true;
    await open(t, s);
    await t.enterText(field('Email'), 'student@example.com');
    await t.enterText(field('Password'), 'A password123!');
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pumpAndSettle();
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    s.fail = false;
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pumpAndSettle();
    expect(s.signIns, 2);
  });
  testWidgets(
    'registration validates matching passwords and requests an email link',
    (t) async {
      final s = TestAccountSession();
      await open(t, s);
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      await t.enterText(field('Display name'), 'Student');
      await t.enterText(field('Email'), 'student@example.com');
      await t.enterText(field('Password'), 'A password123!');
      await t.enterText(field('Confirm password'), 'different');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(s.registrations, 0);
      await t.enterText(field('Confirm password'), 'A password123!');
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(s.registrations, 1);
      expect(find.textContaining('Open the confirmation link'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Back to sign in'));
      await t.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
  testWidgets('pending sign in disables duplicate submission', (t) async {
    final s = TestAccountSession()..pending = Completer<void>();
    await open(t, s);
    await t.enterText(field('Email'), 'student@example.com');
    await t.enterText(field('Password'), 'A password123!');
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(s.signIns, 1);
    s.pending!.complete();
    await t.pumpAndSettle();
  });
  testWidgets('recovery waits for the authenticated email-link callback', (
    t,
  ) async {
    final s = TestAccountSession();
    await open(t, s);
    await t.tap(find.text('Forgot password?'));
    await t.pumpAndSettle();
    await t.enterText(field('Email'), 'student@example.com');
    await t.tap(find.text('Send reset link'));
    await t.pumpAndSettle();
    expect(s.resets, 1);
    expect(
      find.textContaining('a reset link has been requested'),
      findsOneWidget,
    );
    expect(find.text('Save new password'), findsNothing);
    s.recovering = true;
    s.notifyListeners();
    await t.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);
    expect(s.recovering, isTrue);
    await t.enterText(field('Password'), 'A different password123!');
    await t.enterText(field('Confirm password'), 'A different password123!');
    await t.tap(find.text('Save new password'));
    await t.pumpAndSettle();
    expect(s.recovering, isFalse);
    expect(
      find.text('Password updated. Sign in with your new password.'),
      findsOneWidget,
    );
  });
  testWidgets('large text and keyboard keep registration scrollable', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await open(t, TestAccountSession());
    await t.scrollUntilVisible(
      find.text('Create an account'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Create an account'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      field('Email'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.showKeyboard(field('Email'));
    t.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create account'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
