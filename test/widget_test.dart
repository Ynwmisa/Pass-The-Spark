import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/app.dart';
import 'package:pass_the_spark/models/today_overview.dart';
import 'package:pass_the_spark/repositories/demo_today_repository.dart';
import 'package:pass_the_spark/repositories/today_repository.dart';

class TestTodayRepository implements TodayRepository {
  TestTodayRepository(this.overview, {this.failFirst = false});
  final TodayOverview overview;
  final bool failFirst;
  int calls = 0;

  @override
  Future<TodayOverview> loadToday() async {
    calls++;
    if (failFirst && calls == 1) throw StateError('Unavailable');
    return overview;
  }
}

void main() {
  const demo = DemoTodayRepository.overview;

  test('turn eligibility uses the viewer and leaves the group data intact', () {
    final overview = TodayOverview(
      viewerId: 'sam',
      groups: demo.groups,
      activities: demo.activities,
    );
    expect(overview.yourTurns, isEmpty);
    expect(overview.groups, hasLength(2));
    expect(demo.yourTurns, hasLength(2));
  });

  Future<void> openHome(
    WidgetTester tester, {
    TodayRepository repository = const DemoTodayRepository(),
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PassTheSparkApp(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('carousel changes group context and disables its boundaries', (
    tester,
  ) async {
    await openHome(tester);
    expect(find.text('Good afternoon!'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Previous prompt',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Next prompt'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(
      find.text('What is one thing our group should improve together?'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Next prompt',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Previous prompt'));
    await tester.pumpAndSettle();
    expect(
      find.text('What helped your group make progress this week?'),
      findsOneWidget,
    );
  });

  testWidgets('returning from a tab preserves the selected prompt', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('Next prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groups').last);
    await tester.pumpAndSettle();
    expect(find.text('Groups'), findsWidgets);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('no turn offers no answer action while keeping group context', (
    tester,
  ) async {
    await openHome(
      tester,
      repository: TestTodayRepository(
        TodayOverview(
          viewerId: 'another-student',
          groups: demo.groups,
          activities: const [],
        ),
      ),
    );
    expect(find.text('You’re all caught up!'), findsOneWidget);
    expect(find.text('Answer prompt'), findsNothing);
    expect(find.text('Your spark'), findsNothing);
    expect(find.text('Misael holds the spark'), findsNWidgets(2));
  });

  testWidgets('loading failure can be retried', (tester) async {
    final repository = TestTodayRepository(demo, failFirst: true);
    await openHome(tester, repository: repository);
    expect(find.text('Your groups could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('prompt preview does not pretend to save or pass an answer', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.text('Answer prompt'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Answering and passing are coming next. '
        'Your spark stays with you for now.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to Today'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('small screen and large text keep content scrollable', (
    tester,
  ) async {
    await openHome(tester, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Recent activity'), findsOneWidget);
  });
}
