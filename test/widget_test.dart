import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/main.dart';

void main() {
  testWidgets('renders Pass the Spark placeholder text', (tester) async {
    await tester.pumpWidget(const PassTheSparkApp());

    expect(find.text('Pass the Spark'), findsOneWidget);
    expect(find.text('Project setup in progress'), findsOneWidget);
  });
}
