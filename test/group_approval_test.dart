import 'package:pass_the_spark/main.dart';
import 'helpers/memory_draft_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/models/today_overview.dart';
import 'package:pass_the_spark/repositories/local_group_repository.dart';
import 'package:pass_the_spark/screens/groups/group_members.dart';
import 'package:pass_the_spark/theme/app_theme.dart';

class ApprovalRepository extends LocalGroupRepository {
  bool approved = false;
  bool failLoad = false;
  bool failApproval = false;
  bool normalMember = false;
  int requestLoads = 0;
  int approvals = 0;
  Completer<void>? pending;
  String requestName = 'Riley';
  @override
  bool get isLocalPreview => false;
  @override
  Future<GroupDetails> loadGroup(String id) async {
    if (failLoad) throw StateError('Unavailable');
    final original = await super.loadGroup(id);
    final g = original.group;
    return GroupDetails(
      viewerId: normalMember ? original.members.last.id : original.viewerId,
      members: [
        ...original.members,
        if (approved) const GroupMember(id: 'new-student', name: 'Riley'),
      ],
      group: SparkGroup(
        id: g.id,
        name: g.name,
        memberCount: g.memberCount + (approved ? 1 : 0),
        holderId: g.holderId,
        holderName: g.holderName,
        promptId: g.promptId,
        prompt: g.prompt,
      ),
    );
  }

  @override
  Future<List<GroupMembershipRequest>> loadMembershipRequests(String id) async {
    requestLoads++;
    return approved
        ? []
        : [GroupMembershipRequest(id: 'request-1', displayName: requestName)];
  }

  @override
  Future<void> approveMembershipRequest(String id) async {
    approvals++;
    if (pending != null) await pending!.future;
    if (failApproval) {
      throw const GroupInputException('Approval failed. Please try again.');
    }
    approved = true;
    notifyListeners();
  }
}

void main() {
  Future<void> open(
    WidgetTester t,
    ApprovalRepository repo, {
    double scale = 1,
  }) async {
    addTearDown(repo.dispose);
    t.view.physicalSize = scale == 1
        ? const Size(390, 844)
        : const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: GroupMembersScreen(repository: repo, groupId: 'mobile-dev'),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester t) async {
    await t.tap(find.text('Review request'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Approve'));
    await t.pump();
  }

  testWidgets(
    'cancel changes nothing and approved request becomes one member',
    (t) async {
      final repo = ApprovalRepository();
      await open(t, repo);
      expect(find.text('4 accepted members'), findsOneWidget);
      await t.tap(find.text('Review request'));
      await t.pumpAndSettle();
      expect(find.text('Approve Riley?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repo.approvals, 0);
      expect(find.text('Riley'), findsOneWidget);
      await confirm(t);
      await t.pumpAndSettle();
      expect(repo.approvals, 1);
      expect(find.text('5 accepted members'), findsOneWidget);
      expect(find.text('No pending requests.'), findsOneWidget);
      expect(find.text('Riley was approved.'), findsOneWidget);
      expect(find.text('Organiser · Current spark holder'), findsOneWidget);
    },
  );
  testWidgets('failed approval keeps request and allows retry', (t) async {
    final repo = ApprovalRepository()..failApproval = true;
    await open(t, repo);
    await confirm(t);
    await t.pumpAndSettle();
    expect(find.text('Approval failed. Please try again.'), findsOneWidget);
    expect(find.text('Review request'), findsOneWidget);
    expect(find.text('4 accepted members'), findsOneWidget);
    repo.failApproval = false;
    await confirm(t);
    await t.pumpAndSettle();
    expect(find.text('5 accepted members'), findsOneWidget);
    expect(repo.approvals, 2);
  });
  testWidgets('pending approval disables repeat actions until the response', (
    t,
  ) async {
    final repo = ApprovalRepository()..pending = Completer<void>();
    await open(t, repo);
    await confirm(t);
    expect(repo.approvals, 1);
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approving…'))
          .onPressed,
      isNull,
    );
    expect(find.text('4 accepted members'), findsOneWidget);
    repo.pending!.complete();
    await t.pumpAndSettle();
    expect(find.text('5 accepted members'), findsOneWidget);
  });
  testWidgets(
    'ordinary member never requests pending names or sees approval controls',
    (t) async {
      final repo = ApprovalRepository()..normalMember = true;
      await open(t, repo);
      expect(repo.requestLoads, 0);
      expect(find.text('Join requests'), findsNothing);
      expect(find.text('Review request'), findsNothing);
      expect(find.text('4 accepted members'), findsOneWidget);
    },
  );
  testWidgets('loading failure can be retried', (t) async {
    final repo = ApprovalRepository()..failLoad = true;
    await open(t, repo);
    expect(find.textContaining('Members could not be loaded.'), findsOneWidget);
    repo.failLoad = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Riley'), findsOneWidget);
  });
  testWidgets('empty requests offer no inactive approval controls', (t) async {
    final repo = ApprovalRepository()..approved = true;
    await open(t, repo);
    expect(find.text('No pending requests.'), findsOneWidget);
    expect(find.text('Review request'), findsNothing);
  });
  testWidgets(
    'large text keeps long request names and confirmation scrollable',
    (t) async {
      final repo = ApprovalRepository()
        ..requestName = List.filled(5, 'Riley with a long name').join(' ');
      await open(t, repo, scale: 2);
      await t.scrollUntilVisible(
        find.text('Review request'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('Review request'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.widgetWithText(TextButton, 'Approve'), findsOneWidget);
    },
  );
  testWidgets('leaving during approval does not update a disposed screen', (
    t,
  ) async {
    final repo = ApprovalRepository()..pending = Completer<void>();
    await open(t, repo);
    await confirm(t);
    await t.pumpWidget(const SizedBox());
    repo.pending!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('approval navigation preserves the selected Today prompt', (
    t,
  ) async {
    final repo = ApprovalRepository();
    addTearDown(repo.dispose);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      PassTheSparkApp(repository: repo, draftStore: MemoryDraftStore()),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Next prompt'));
    await t.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    await t.tap(find.text('Groups').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Mobile Dev'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Members & invitations'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Members & invitations'));
    await t.pumpAndSettle();
    await confirm(t);
    await t.pumpAndSettle();
    expect(find.text('5 accepted members'), findsOneWidget);
    await t.tap(find.text('Today'));
    await t.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
  });
}
