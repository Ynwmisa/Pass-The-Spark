import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/main.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/models/today_overview.dart';
import 'package:pass_the_spark/repositories/local_group_repository.dart';

import 'helpers/memory_draft_store.dart';

class ControlledGroups extends LocalGroupRepository {
  ControlledGroups({super.seedDemo});
  bool failLoad = false;
  bool failCreate = false;
  Completer<GroupDetails>? pendingCreate;
  int createCalls = 0;
  bool anotherHolder = false;

  @override
  Future<GroupOverview> loadGroups() async {
    if (failLoad) throw StateError('offline');
    return super.loadGroups();
  }

  @override
  Future<GroupDetails> createGroup(String name) async {
    createCalls++;
    if (failCreate) throw StateError('save failed');
    if (pendingCreate != null) return pendingCreate!.future;
    return super.createGroup(name);
  }

  @override
  Future<GroupDetails> loadGroup(String id) async {
    final original = await super.loadGroup(id);
    if (!anotherHolder) return original;
    final g = original.group;
    final holder = original.members.last;
    return GroupDetails(
      viewerId: original.viewerId,
      members: original.members,
      group: SparkGroup(
        id: g.id,
        name: g.name,
        memberCount: g.memberCount,
        holderId: holder.id,
        holderName: holder.name,
        promptId: g.promptId,
        prompt: g.prompt,
      ),
    );
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    ControlledGroups repo, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      PassTheSparkApp(repository: repo, draftStore: MemoryDraftStore()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groups').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create validation, success and Today share the same session data',
    (tester) async {
      final repo = ControlledGroups(seedDemo: false);
      await open(tester, repo);
      expect(find.textContaining('No groups yet.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Create group'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a group name.'), findsOneWidget);
      expect(repo.createCalls, 0);
      await tester.enterText(find.byType(TextFormField), 'Project Circle');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Your circle is ready'), findsOneWidget);
      await tester.tap(find.text('Open group'));
      await tester.pumpAndSettle();
      expect(find.text('Project Circle'), findsOneWidget);
      expect(find.text('You hold the spark'), findsOneWidget);
      expect(find.text('Misael (you)'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Project Circle'), findsWidgets);
      expect(find.text('1 of 1'), findsOneWidget);
    },
  );

  testWidgets(
    'unknown code preserves input; valid request stays pending and private',
    (tester) async {
      await open(tester, ControlledGroups(seedDemo: false));
      await tester.tap(find.text('Join with a code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'WRONG77');
      await tester.tap(find.text('Request to join'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This code was not found.'), findsOneWidget);
      expect(find.text('WRONG77'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'study26');
      await tester.tap(find.text('Request to join'));
      await tester.pumpAndSettle();
      expect(find.text('Request saved locally'), findsOneWidget);
      await tester.tap(find.text('Back to groups'));
      await tester.pumpAndSettle();
      expect(find.text('Study Circle'), findsOneWidget);
      expect(
        find.text('Pending in this preview. You are not a member yet.'),
        findsOneWidget,
      );
      expect(find.text('Your spark'), findsNothing);
    },
  );

  testWidgets('load failure supports retry without recreating repository', (
    tester,
  ) async {
    final repo = ControlledGroups()..failLoad = true;
    await open(tester, repo);
    expect(find.text('Your groups could not be loaded.'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile Dev'), findsOneWidget);
  });

  testWidgets(
    'save failure preserves the name and retry creates only one circle',
    (tester) async {
      final repo = ControlledGroups()..failCreate = true;
      await open(tester, repo);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Create group'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Keep my name');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your input is kept.'), findsOneWidget);
      expect(find.text('Keep my name'), findsOneWidget);
      repo.failCreate = false;
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Your circle is ready'), findsOneWidget);
      expect(
        (await repo.loadGroups()).groups.where((g) => g.name == 'Keep my name'),
        hasLength(1),
      );
    },
  );

  testWidgets('pending save blocks duplicate submit and back until result', (
    tester,
  ) async {
    final repo = ControlledGroups()..pendingCreate = Completer<GroupDetails>();
    await open(tester, repo);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create group'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Once');
    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Saving…'),
    );
    expect(button.onPressed, isNull);
    expect(repo.createCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    repo.pendingCreate!.completeError(StateError('temporary failure'));
    await tester.pumpAndSettle();
    expect(find.text('Once'), findsOneWidget);
    expect(find.textContaining('Your input is kept.'), findsOneWidget);
  });

  testWidgets('another holder has waiting context and no answer action', (
    tester,
  ) async {
    final repo = ControlledGroups()..anotherHolder = true;
    await open(tester, repo);
    await tester.tap(find.text('Mobile Dev'));
    await tester.pumpAndSettle();
    expect(find.text('Noor holds the spark'), findsOneWidget);
    expect(find.text('Answer prompt'), findsNothing);
    expect(find.textContaining('It is their turn.'), findsOneWidget);
  });

  testWidgets(
    'small screen large text and keyboard keep forms and members scrollable',
    (tester) async {
      await open(
        tester,
        ControlledGroups(),
        size: const Size(320, 640),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Create group'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextFormField),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextFormField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Mobile Dev'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile Dev'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Noor'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Noor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
