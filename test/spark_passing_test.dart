import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pass_the_spark/main.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/models/spark_contribution.dart';
import 'package:pass_the_spark/models/today_overview.dart';
import 'package:pass_the_spark/repositories/local_group_repository.dart';
import 'package:pass_the_spark/screens/pass_spark.dart';
import 'package:pass_the_spark/screens/groups/group_timeline.dart';
import 'package:pass_the_spark/theme/app_theme.dart';
import 'helpers/memory_draft_store.dart';

class PassingRepository extends LocalGroupRepository {
  int passCalls = 0;
  bool failPass = false;
  bool failAfterCommit = false;
  bool noOtherMembers = false;
  bool stale = false;
  bool failLoad = false;
  bool failHistory = false;
  Completer<void>? pending;
  @override
  Future<GroupDetails> loadGroup(String groupId) async {
    if (failLoad) throw StateError('Offline');
    final details = await super.loadGroup(groupId);
    final g = details.group;
    return GroupDetails(
      viewerId: details.viewerId,
      members: noOtherMembers ? [details.members.first] : details.members,
      group: SparkGroup(
        id: g.id,
        name: g.name,
        memberCount: g.memberCount,
        holderId: g.holderId,
        holderName: g.holderName,
        promptId: g.promptId,
        prompt: g.prompt,
        version: g.version + (stale ? 1 : 0),
      ),
    );
  }

  @override
  Future<SparkContribution> passSpark({
    required SparkGroup turn,
    required String recipientId,
    required String answer,
  }) async {
    passCalls++;
    if (pending != null) await pending!.future;
    if (failPass) {
      throw const GroupInputException(
        'Could not confirm the pass. Your draft is still local.',
      );
    }
    final saved = await super.passSpark(
      turn: turn,
      recipientId: recipientId,
      answer: answer,
    );
    if (failAfterCommit) throw StateError('Response lost');
    return saved;
  }

  @override
  Future<List<SparkContribution>> loadContributions(String groupId) {
    if (failHistory) throw StateError('Offline');
    return super.loadContributions(groupId);
  }
}

void main() {
  Future<void> open(
    WidgetTester t,
    PassingRepository repo, {
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
    final g = (await repo.loadToday()).groups.first;
    final router = GoRouter(
      initialLocation: '/pass',
      routes: [
        GoRoute(
          path: '/pass',
          builder: (_, _) => PassSparkScreen(
            repository: repo,
            turn: g,
            answer: 'We tested the prototype together.',
          ),
        ),
        GoRoute(
          path: '/groups/mobile-dev',
          builder: (_, _) => const Scaffold(body: Text('Group destination')),
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

  Future<void> select(WidgetTester t) async {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Sam'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Sam'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Continue'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester t) async {
    await t.scrollUntilVisible(
      find.text('Confirm pass'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Confirm pass'));
    await t.pumpAndSettle();
  }

  testWidgets('selection and review stay local until confirmation', (t) async {
    final repo = PassingRepository();
    await open(t, repo);
    await t.scrollUntilVisible(
      find.text('Continue'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    expect(find.text('Misael'), findsNothing);
    await select(t);
    expect(find.text('Pass to Sam?'), findsOneWidget);
    expect(repo.passCalls, 0);
    expect(await repo.loadContributions('mobile-dev'), isEmpty);
    await t.scrollUntilVisible(
      find.text('Choose another member'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Choose another member'));
    await t.pumpAndSettle();
    expect(repo.passCalls, 0);
    await select(t);
    await confirm(t);
    expect(find.text('Spark passed to Sam'), findsOneWidget);
    expect(repo.passCalls, 1);
    expect(
      (await repo.loadContributions('mobile-dev')).single.answer,
      'We tested the prototype together.',
    );
    await t.tap(find.text('Back to group'));
    await t.pumpAndSettle();
    expect(find.text('Group destination'), findsOneWidget);
  });
  testWidgets('failed pass preserves review and can be retried', (t) async {
    final repo = PassingRepository()..failPass = true;
    await open(t, repo);
    await select(t);
    await confirm(t);
    expect(
      find.text('Could not confirm the pass. Your draft is still local.'),
      findsOneWidget,
    );
    expect(await repo.loadContributions('mobile-dev'), isEmpty);
    expect(
      (await repo.loadGroup('mobile-dev')).group.holderId,
      LocalGroupRepository.viewerId,
    );
    repo.failPass = false;
    await confirm(t);
    expect(find.text('Spark passed to Sam'), findsOneWidget);
    expect(repo.passCalls, 2);
  });
  testWidgets(
    'lost response retries the committed pass without duplicating it',
    (t) async {
      final repo = PassingRepository()..failAfterCommit = true;
      await open(t, repo);
      await select(t);
      await confirm(t);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(await repo.loadContributions('mobile-dev'), hasLength(1));
      repo.failAfterCommit = false;
      await confirm(t);
      expect(find.text('Spark passed to Sam'), findsOneWidget);
      expect(await repo.loadContributions('mobile-dev'), hasLength(1));
    },
  );
  testWidgets('pending pass disables submission and back', (t) async {
    final repo = PassingRepository()..pending = Completer<void>();
    await open(t, repo);
    await select(t);
    await t.scrollUntilVisible(
      find.text('Confirm pass'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Confirm pass'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Passing…'))
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Back',
            ),
          )
          .onPressed,
      isNull,
    );
    await t.binding.handlePopRoute();
    await t.pump();
    expect(repo.passCalls, 1);
    repo.pending!.complete();
    await t.pumpAndSettle();
    expect(find.text('Spark passed to Sam'), findsOneWidget);
  });
  testWidgets('empty recipients prevent passing with a helpful explanation', (
    t,
  ) async {
    final repo = PassingRepository()..noOtherMembers = true;
    await open(t, repo);
    expect(
      find.textContaining('There are no other members yet.'),
      findsOneWidget,
    );
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    expect(repo.passCalls, 0);
  });
  testWidgets('stale turn is blocked before member selection', (t) async {
    final repo = PassingRepository()..stale = true;
    await open(t, repo);
    expect(find.textContaining('Your turn has changed.'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
    expect(repo.passCalls, 0);
  });
  testWidgets('member-load failure supports retry', (t) async {
    final repo = PassingRepository()..failLoad = true;
    await open(t, repo);
    expect(find.textContaining('members could not be loaded'), findsOneWidget);
    repo.failLoad = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
  });
  testWidgets('small screen and large text keep confirmation usable', (
    t,
  ) async {
    final repo = PassingRepository();
    await open(t, repo, large: true);
    await select(t);
    await confirm(t);
    expect(t.takeException(), isNull);
    expect(find.text('Spark passed to Sam'), findsOneWidget);
  });
  testWidgets(
    'answer stays in draft store until final pass and then appears in timeline',
    (t) async {
      final repo = PassingRepository();
      final store = MemoryDraftStore();
      addTearDown(repo.dispose);
      await t.pumpWidget(PassTheSparkApp(repository: repo, draftStore: store));
      await t.pumpAndSettle();
      await t.tap(find.text('Answer prompt'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField),
        'Our first shared contribution.',
      );
      await t.pumpAndSettle();
      expect(store.drafts.values.single.text, 'Our first shared contribution.');
      expect(repo.passCalls, 0);
      await t.scrollUntilVisible(
        find.text('Save answer & continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Save answer & continue'));
      await t.pumpAndSettle();
      expect(repo.passCalls, 0);
      expect(await repo.loadContributions('mobile-dev'), isEmpty);
      await select(t);
      await confirm(t);
      expect(find.text('Spark passed to Sam'), findsOneWidget);
      await t.tap(find.text('Back to group'));
      await t.pumpAndSettle();
      await t.tap(find.text('Shared timeline'));
      await t.pumpAndSettle();
      expect(find.text('Our first shared contribution.'), findsOneWidget);
      expect(find.text('Misael → Sam'), findsOneWidget);
    },
  );
  testWidgets('timeline handles empty history and a retryable error', (
    t,
  ) async {
    final repo = PassingRepository()..failHistory = true;
    addTearDown(repo.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: GroupTimelineScreen(repository: repo, groupId: 'mobile-dev'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('timeline could not be loaded'), findsOneWidget);
    repo.failHistory = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.textContaining('No contributions yet.'), findsOneWidget);
  });
}
