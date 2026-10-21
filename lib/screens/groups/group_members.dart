import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });
  final GroupRepository repository;
  final String groupId;
  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _MembersData {
  const _MembersData(this.details, this.requests);
  final GroupDetails details;
  final List<GroupMembershipRequest> requests;
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  late Future<_MembersData> _data = _load();
  String? _approving;
  String? _actionError;
  String? _message;

  Future<_MembersData> _load() async {
    final details = await widget.repository.loadGroup(widget.groupId);
    final requests =
        details.isViewerOrganiser && !widget.repository.isLocalPreview
        ? await widget.repository.loadMembershipRequests(widget.groupId)
        : <GroupMembershipRequest>[];
    return _MembersData(details, requests);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    try {
      await next;
    } catch (_) {
      /* The snapshot provides retry. */
    }
  }

  Future<void> _approve(GroupMembershipRequest request) async {
    if (_approving != null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('Approve ${request.displayName}?'),
        content: const Text(
          'They will be able to open this group and read its shared content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _approving != null) return;
    setState(() {
      _approving = request.id;
      _actionError = null;
      _message = null;
    });
    try {
      await widget.repository.approveMembershipRequest(request.id);
      if (!mounted) return;
      setState(() => _message = '${request.displayName} was approved.');
      await _refresh();
    } on GroupInputException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Approval could not be confirmed. Try again or refresh the list.',
        );
      }
    } finally {
      if (mounted) setState(() => _approving = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Members and requests')),
    body: FutureBuilder<_MembersData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Members could not be loaded. Your access may have changed.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading members'),
          );
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: PageStorageKey('members-${widget.groupId}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                data.details.group.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${data.details.members.length} accepted ${data.details.members.length == 1 ? 'member' : 'members'}',
              ),
              const SizedBox(height: 20),
              if (data.details.isViewerOrganiser &&
                  !widget.repository.isLocalPreview) ...[
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/groups/${widget.groupId}/invite'),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Invite member'),
                ),
                const SizedBox(height: 20),
              ],
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
              if (_message != null) ...[
                Semantics(liveRegion: true, child: Text(_message!)),
                const SizedBox(height: 16),
              ],
              if (_actionError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _actionError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.details.isViewerOrganiser &&
                  !widget.repository.isLocalPreview) ...[
                Semantics(
                  header: true,
                  child: Text(
                    'Join requests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                if (data.requests.isEmpty)
                  const Text('No pending requests.')
                else ...[
                  const Text(
                    'Only you, as organiser, can review these requests.',
                  ),
                  const SizedBox(height: 12),
                  for (final request in data.requests)
                    Card(
                      key: ValueKey(request.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              request.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text('Waiting for your approval'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _approving != null
                                  ? null
                                  : () => _approve(request),
                              child: Text(
                                _approving == request.id
                                    ? 'Approving…'
                                    : 'Review request',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
              ],
              Semantics(
                header: true,
                child: Text(
                  'Members',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              for (final member in data.details.members)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.id == data.details.viewerId
                              ? '${member.name} (you)'
                              : member.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            member.isOrganiser ? 'Organiser' : 'Member',
                            if (member.id == data.details.group.holderId)
                              'Current spark holder',
                          ].join(' · '),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Pull to refresh after a membership change.'),
            ],
          ),
        );
      },
    ),
  );
}
