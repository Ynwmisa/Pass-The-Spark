import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/screens/groups/groups.dart';
import 'package:pass_the_spark/screens/groups/invite_member.dart';
import 'package:pass_the_spark/theme/app_theme.dart';
import 'group_approval_test.dart' show ApprovalRepository;

class InvitationRepository extends ApprovalRepository {
  bool hasInvitation = true;
  bool failSend = false;
  bool failResponse = false;
  int sends = 0;
  int responses = 0;
  String? sentEmail;
  bool? accepted;
  Completer<void>? sending;
  Completer<void>? responding;
  @override
  Future<GroupOverview> loadGroups() async {
    final original = await super.loadGroups();
    return GroupOverview(
      viewerId: original.viewerId,
      groups: original.groups,
      requests: original.requests,
      invitations: hasInvitation
          ? const [
              GroupInvitation(
                id: 'invite-1',
                groupId: 'study-circle',
                groupName: 'Study Circle',
              ),
            ]
          : [],
    );
  }

  @override
  Future<void> inviteMember(String groupId, String email) async {
    sends++;
    sentEmail = email;
    if (sending != null) await sending!.future;
    if (failSend) throw const GroupInputException('Send failed. Try again.');
  }

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    responses++;
    if (responding != null) await responding!.future;
    if (failResponse) {
      throw const GroupInputException('Response failed. Try again.');
    }
    accepted = accept;
    hasInvitation = false;
    notifyListeners();
  }
}

void main() {
  Future<void> open(
    WidgetTester t,
    InvitationRepository repo, {
    bool send = false,
    bool large = false,
  }) async {
    if (large) {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final router = GoRouter(
      initialLocation: send ? '/invite' : '/groups',
      routes: [
        GoRoute(
          path: '/invite',
          builder: (_, _) =>
              InviteMemberScreen(repository: repo, groupId: 'mobile-dev'),
        ),
        GoRoute(
          path: '/groups',
          builder: (_, _) => GroupsScreen(repository: repo),
        ),
        GoRoute(
          path: '/groups/study-circle',
          builder: (_, _) => const Scaffold(body: Text('Accepted group')),
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

  Future<void> review(WidgetTester t) async {
    await t.scrollUntilVisible(
      find.text('Study Circle invited you'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Study Circle invited you'));
    await t.pumpAndSettle();
  }

  testWidgets(
    'send validates email, retains failures and confirms only after save',
    (t) async {
      final repo = InvitationRepository()..failSend = true;
      await open(t, repo, send: true);
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repo.sends, 0);
      await t.enterText(find.byType(TextFormField), 'student@example.com');
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(find.text('Send failed. Try again.'), findsOneWidget);
      expect(
        t.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        'student@example.com',
      );
      repo.failSend = false;
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(repo.sends, 2);
      expect(repo.sentEmail, 'student@example.com');
      expect(find.text('Invitation sent'), findsOneWidget);
      expect(
        find.textContaining('No email notification was sent.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('send disables repeat submission while waiting', (t) async {
    final repo = InvitationRepository()..sending = Completer<void>();
    await open(t, repo, send: true);
    await t.enterText(find.byType(TextFormField), 'student@example.com');
    await t.tap(find.text('Send invitation'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sending…'))
          .onPressed,
      isNull,
    );
    expect(repo.sends, 1);
    repo.sending!.complete();
    await t.pumpAndSettle();
    expect(find.text('Invitation sent'), findsOneWidget);
  });
  testWidgets('ordinary members cannot open the send form', (t) async {
    final repo = InvitationRepository()..normalMember = true;
    await open(t, repo, send: true);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.text('Only the group organiser can invite members.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'cancel preserves invite and accept opens the group after refresh',
    (t) async {
      final repo = InvitationRepository();
      await open(t, repo);
      expect(find.text('1 invite'), findsOneWidget);
      await review(t);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repo.responses, 0);
      await review(t);
      await t.tap(find.text('Accept invitation'));
      await t.pumpAndSettle();
      expect(repo.accepted, isTrue);
      expect(find.text('Accepted group'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('decline removes invitation without navigating to the group', (
    t,
  ) async {
    final repo = InvitationRepository();
    await open(t, repo);
    await review(t);
    await t.tap(find.text('Decline'));
    await t.pumpAndSettle();
    expect(repo.accepted, isFalse);
    expect(find.text('Study Circle invited you'), findsNothing);
    expect(find.text('Accepted group'), findsNothing);
    expect(find.text('No invitations yet'), findsOneWidget);
  });
  testWidgets(
    'failed response stays open for retry and pending actions are disabled',
    (t) async {
      final repo = InvitationRepository()..failResponse = true;
      await open(t, repo);
      await review(t);
      await t.tap(find.text('Accept invitation'));
      await t.pumpAndSettle();
      expect(find.text('Response failed. Try again.'), findsOneWidget);
      expect(repo.hasInvitation, isTrue);
      repo.failResponse = false;
      repo.responding = Completer<void>();
      await t.tap(find.text('Accept invitation'));
      await t.pump();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept invitation'),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<TextButton>(find.widgetWithText(TextButton, 'Decline'))
            .onPressed,
        isNull,
      );
      repo.responding!.complete();
      await t.pumpAndSettle();
      expect(find.text('Accepted group'), findsOneWidget);
    },
  );
  testWidgets('invitation confirmation fits large text on a small screen', (
    t,
  ) async {
    await open(t, InvitationRepository(), large: true);
    await review(t);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Decline'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('send form stays usable with large text and keyboard', (t) async {
    final repo = InvitationRepository();
    await open(t, repo, send: true, large: true);
    await t.scrollUntilVisible(
      find.byType(TextFormField),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'student@example.com');
    t.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Send invitation'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Send invitation'));
    await t.pumpAndSettle();
    expect(repo.sends, 1);
    expect(find.text('Invitation sent'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
