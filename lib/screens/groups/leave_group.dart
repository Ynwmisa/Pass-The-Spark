import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';

class LeaveGroupAction extends StatelessWidget {
  const LeaveGroupAction({
    super.key,
    required this.repository,
    required this.details,
  });
  final GroupRepository repository;
  final GroupDetails details;

  @override
  Widget build(BuildContext context) {
    final reason = details.isViewerOrganiser
        ? 'Organiser handover is needed before you can leave. Handover is not available yet.'
        : details.group.holderId == details.viewerId
        ? 'Pass the spark to another member before leaving.'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: reason != null
              ? null
              : () async {
                  final router = GoRouter.of(context);
                  final left = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        _LeaveDialog(repository: repository, details: details),
                  );
                  if (left == true) router.go('/groups');
                },
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave group'),
        ),
        if (reason != null) ...[const SizedBox(height: 8), Text(reason)],
      ],
    );
  }
}

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({required this.repository, required this.details});
  final GroupRepository repository;
  final GroupDetails details;
  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _leave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.leaveGroup(widget.details.group.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is GroupInputException
            ? error.message
            : 'Could not leave the group. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text('Leave ${widget.details.group.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You will lose access to this private group. To return, you will need an invite code and organiser approval again.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _leave,
          child: Text(_saving ? 'Leaving…' : 'Leave'),
        ),
      ],
    ),
  );
}
