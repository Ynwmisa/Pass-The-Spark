import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/today_overview.dart';
import '../repositories/today_repository.dart';
import '../widgets/activity_card.dart';
import '../widgets/group_card.dart';

/// Supporting read-only destinations for this first home-screen iteration.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({
    super.key,
    required this.title,
    required this.repository,
    this.groupId,
  });

  final String title;
  final TodayRepository repository;
  final String? groupId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
    body: FutureBuilder<TodayOverview>(
      future: repository.loadToday(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('This preview could not be loaded.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final overview = snapshot.requireData;
        if (title == 'Profile') {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You’re exploring Pass the Spark with sample groups. '
              'Accounts and personal settings are coming later.',
            ),
          );
        }
        if (title == 'Journey') {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Recent moments from your circles.'),
              const SizedBox(height: 16),
              if (overview.activities.isEmpty)
                const Text('No group activity yet.'),
              ...overview.activities.map(
                (activity) => ActivityCard(activity: activity),
              ),
            ],
          );
        }
        final groups = groupId == null
            ? overview.groups
            : overview.groups.where((group) => group.id == groupId).toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (groups.isEmpty) const Text('No groups to show yet.'),
            for (final group in groups) ...[
              GroupCard(
                group: group,
                isYourTurn: group.holderId == overview.viewerId,
                onTap: () => _showGroup(context, group, overview.viewerId),
              ),
              const SizedBox(height: 16),
              if (groupId != null) ...[
                Text(
                  group.prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is a read-only group preview. '
                  'Membership and spark passing are coming in later features.',
                ),
              ],
            ],
          ],
        );
      },
    ),
  );

  void _showGroup(BuildContext context, SparkGroup group, String viewerId) {
    if (groupId == null) {
      context.push('/groups/${group.id}');
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(group.name),
          content: Text(
            '${group.memberCount} members. '
            '${group.holderId == viewerId ? 'You hold' : '${group.holderName} holds'} the spark.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
