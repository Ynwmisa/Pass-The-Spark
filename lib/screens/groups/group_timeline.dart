import 'package:flutter/material.dart';
import '../../models/group_details.dart';
import '../../models/spark_contribution.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/group_data_view.dart';
import '../../widgets/local_groups_notice.dart';

class GroupTimelineScreen extends StatelessWidget {
  const GroupTimelineScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });
  final GroupRepository repository;
  final String groupId;
  Future<_TimelineData> _load() async {
    final details = await repository.loadGroup(groupId);
    final contributions = await repository.loadContributions(groupId);
    return _TimelineData(details, contributions);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Group timeline')),
    body: GroupDataView<_TimelineData>(
      repository: repository,
      load: _load,
      errorMessage:
          'This timeline could not be loaded. Your membership may have changed. Try again or return to Groups.',
      builder: (context, data, refresh) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              data.details.group.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (repository.isLocalPreview) const LocalGroupsNotice(),
            if (data.contributions.isEmpty)
              const Text(
                'No contributions yet. Answers appear here after a confirmed pass.',
              )
            else ...[
              const Text('Latest contributions · pull to refresh'),
              const SizedBox(height: 16),
              for (final contribution in data.contributions)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${contribution.senderName} → ${contribution.recipientName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _date(context, contribution.createdAt),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'PROMPT',
                        style: TextStyle(
                          color: AppColors.darkTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(contribution.prompt),
                      const SizedBox(height: 16),
                      const Text(
                        'ANSWER',
                        style: TextStyle(
                          color: AppColors.darkTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(contribution.answer),
                    ],
                  ),
                ),
              if (data.contributions.length == 100)
                const Text('Showing the latest 100 contributions.'),
            ],
          ],
        ),
      ),
    ),
  );
  String _date(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final format = MaterialLocalizations.of(context);
    return '${format.formatMediumDate(local)} · ${format.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

class _TimelineData {
  const _TimelineData(this.details, this.contributions);
  final GroupDetails details;
  final List<SparkContribution> contributions;
}
