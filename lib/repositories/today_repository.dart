import '../models/today_overview.dart';

abstract interface class TodayRepository {
  Future<TodayOverview> loadToday();
}
