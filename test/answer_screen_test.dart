import 'dart:async';
import 'package:pass_the_spark/models/today_overview.dart';
import 'package:pass_the_spark/repositories/today_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/main.dart';
import 'package:pass_the_spark/repositories/demo_today_repository.dart';
import 'package:pass_the_spark/services/draft_store.dart';
import 'helpers/memory_draft_store.dart';

class DelayedCheckRepository implements TodayRepository {
  int calls = 0;
  final check = Completer<TodayOverview>();
  @override
  Future<TodayOverview> loadToday() {
    calls++;
    return calls >= 3
        ? check.future
        : Future.value(DemoTodayRepository.overview);
  }
}

void main() {
  Future<void> openAnswer(
    WidgetTester tester,
    DraftStore store, {
    TodayRepository repository = const DemoTodayRepository(),
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      PassTheSparkApp(draftStore: store, repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Answer prompt'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer prompt'));
    await tester.pumpAndSettle();
  }

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save answer & continue'),
      );

  testWidgets('answer survives leaving the editor and reopening it', (
    tester,
  ) async {
    final store = MemoryDraftStore();
    await openAnswer(tester, store);
    expect(continueButton(tester).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'We tested the prototype together.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft saved locally'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Answer prompt'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer prompt'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'We tested the prototype together.',
    );
  });

  testWidgets('continue reviews a local answer without moving the spark', (
    tester,
  ) async {
    await openAnswer(tester, MemoryDraftStore());
    await tester.enterText(find.byType(TextField), 'A useful update.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save answer & continue'));
    await tester.tap(find.text('Save answer & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review answer'), findsOneWidget);
    expect(find.text('A useful update.'), findsOneWidget);
    expect(DemoTodayRepository.overview.yourTurns, hasLength(2));
    expect(find.textContaining('Nothing has been shared'), findsOneWidget);
  });

  testWidgets('over-limit text stays recoverable but cannot continue', (
    tester,
  ) async {
    await openAnswer(tester, MemoryDraftStore());
    await tester.enterText(find.byType(TextField), 'a' * 301);
    await tester.pumpAndSettle();
    expect(continueButton(tester).onPressed, isNull);
    expect(
      find.text('Keep your answer to 300 characters or fewer.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      301,
    );
  });

  testWidgets('save failure warns before leaving and allows retry', (
    tester,
  ) async {
    final store = MemoryDraftStore()..failWrite = true;
    await openAnswer(tester, store);
    await tester.enterText(find.byType(TextField), 'Do not lose this.');
    await tester.pumpAndSettle();
    expect(find.text('Draft could not be saved'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Your latest changes are not saved'), findsOneWidget);
    await tester.tap(find.text('Stay and retry'));
    await tester.pumpAndSettle();
    store.failWrite = false;
    await tester.ensureVisible(find.text('Try saving again'));
    await tester.tap(find.text('Try saving again'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved locally'), findsOneWidget);
  });

  testWidgets('small screen with large text can reach the save action', (
    tester,
  ) async {
    await openAnswer(
      tester,
      MemoryDraftStore(),
      textScale: 2,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Save answer & continue'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during a pending turn check does not reopen review', (
    tester,
  ) async {
    final repository = DelayedCheckRepository();
    await openAnswer(tester, MemoryDraftStore(), repository: repository);
    await tester.enterText(find.byType(TextField), 'An answer to retain.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save answer & continue'));
    await tester.tap(find.text('Save answer & continue'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    repository.check.complete(DemoTodayRepository.overview);
    await tester.pumpAndSettle();
    expect(find.text('Review answer'), findsNothing);
    expect(find.text('Good afternoon!'), findsOneWidget);
  });
}
