import '../models/today_overview.dart';
import 'today_repository.dart';

/// Local preview data only. No account, database or transfer is created.
class DemoTodayRepository implements TodayRepository {
  const DemoTodayRepository();

  static const overview = TodayOverview(
    viewerId: 'preview-student',
    groups: [
      SparkGroup(
        id: 'mobile-dev',
        name: 'Mobile Dev',
        memberCount: 4,
        holderId: 'preview-student',
        holderName: 'Misael',
        prompt: 'What helped your group make progress this week?',
      ),
      SparkGroup(
        id: 'ux-design',
        name: 'UX Design',
        memberCount: 5,
        holderId: 'preview-student',
        holderName: 'Misael',
        prompt: 'What is one thing our group should improve together?',
      ),
    ],
    activities: [
      SparkActivity(
        title: 'Sam passed the spark to you',
        groupName: 'Mobile Dev',
        when: '2 hours ago',
        detail: 'You now hold the spark in Mobile Dev.',
      ),
    ],
  );

  @override
  Future<TodayOverview> loadToday() async => overview;
}
