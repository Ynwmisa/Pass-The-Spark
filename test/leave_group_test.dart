import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/screens/groups/leave_group.dart';
import 'package:pass_the_spark/theme/app_theme.dart';
import 'package:pass_the_spark/screens/groups/group_detail.dart';
import 'group_approval_test.dart' show ApprovalRepository;

class LeaveRepository extends ApprovalRepository {
  int leaves = 0;
  bool fail = false;
  Completer<void>? leaving;
  @override
  Future<void> leaveGroup(String groupId) async {
    leaves++;
    if (leaving != null) await leaving!.future;
    if (fail) {
      throw const GroupInputException('Leave failed. Please try again.');
    }
    failLoad = true;
    notifyListeners();
  }
}

void main() {
  Future<void> open(
    WidgetTester t,
    LeaveRepository repo, {
    bool ordinary = true,
    bool fullScreen = false,
  }) async {
    repo.normalMember = ordinary;
    final details = await repo.loadGroup('mobile-dev');
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => fullScreen
              ? GroupDetailScreen(repository: repo, groupId: 'mobile-dev')
              : Scaffold(
                  body: LeaveGroupAction(repository: repo, details: details),
                ),
        ),
        GoRoute(
          path: '/groups',
          builder: (_, _) => const Scaffold(body: Text('Your groups')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(repo.dispose);
    await t.pumpWidget(
      MaterialApp.router(theme: appTheme, routerConfig: router),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'cancel preserves membership and confirmed leave returns to groups',
    (t) async {
      final repo = LeaveRepository();
      await open(t, repo);
      await t.tap(find.text('Leave group'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repo.leaves, 0);
      await t.tap(find.text('Leave group'));
      await t.pumpAndSettle();
      await t.tap(find.text('Leave'));
      await t.pumpAndSettle();
      expect(repo.leaves, 1);
      expect(find.text('Your groups'), findsOneWidget);
    },
  );
  testWidgets('failure keeps confirmation open and supports retry', (t) async {
    final repo = LeaveRepository()..fail = true;
    await open(t, repo);
    await t.tap(find.text('Leave group'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leave'));
    await t.pumpAndSettle();
    expect(find.text('Leave failed. Please try again.'), findsOneWidget);
    expect(find.text('Your groups'), findsNothing);
    repo.fail = false;
    await t.tap(find.text('Leave'));
    await t.pumpAndSettle();
    expect(repo.leaves, 2);
    expect(find.text('Your groups'), findsOneWidget);
  });
  testWidgets('pending leave disables repeat actions and cancel', (t) async {
    final repo = LeaveRepository()..leaving = Completer<void>();
    await open(t, repo);
    await t.tap(find.text('Leave group'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leave'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Leaving…'))
          .onPressed,
      isNull,
    );
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed,
      isNull,
    );
    expect(repo.leaves, 1);
    repo.leaving!.complete();
    await t.pumpAndSettle();
    expect(find.text('Your groups'), findsOneWidget);
  });
  testWidgets('organiser sees why leaving is unavailable', (t) async {
    final repo = LeaveRepository();
    await open(t, repo, ordinary: false);
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Leave group'),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('Organiser handover is needed'), findsOneWidget);
    expect(repo.leaves, 0);
  });
  testWidgets(
    'repository refresh removes private detail but still returns to Groups',
    (t) async {
      final repo = LeaveRepository()..normalMember = true;
      final router = GoRouter(
        initialLocation: '/detail',
        routes: [
          GoRoute(
            path: '/detail',
            builder: (_, _) =>
                GroupDetailScreen(repository: repo, groupId: 'mobile-dev'),
          ),
          GoRoute(
            path: '/groups',
            builder: (_, _) => const Scaffold(body: Text('Your groups')),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(repo.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: appTheme, routerConfig: router),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Leave group'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Leave group'));
      await t.pumpAndSettle();
      await t.tap(find.text('Leave'));
      await t.pumpAndSettle();
      expect(find.text('Your groups'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
