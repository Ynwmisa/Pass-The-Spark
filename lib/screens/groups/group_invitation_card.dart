import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';

class GroupInvitationCard extends StatelessWidget {
  const GroupInvitationCard({
    super.key,
    required this.repository,
    required this.invitation,
  });
  final GroupRepository repository;
  final GroupInvitation invitation;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final router = GoRouter.of(context);
          final accepted = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _InvitationDialog(
              repository: repository,
              invitation: invitation,
            ),
          );
          if (accepted == true) router.go('/groups/${invitation.groupId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invitation.groupName} invited you',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Accept or decline invitation',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InvitationDialog extends StatefulWidget {
  const _InvitationDialog({required this.repository, required this.invitation});
  final GroupRepository repository;
  final GroupInvitation invitation;
  @override
  State<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<_InvitationDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _respond(bool accept) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.respondToInvitation(
        widget.invitation.id,
        accept: accept,
      );
      if (mounted) Navigator.of(context).pop(accept);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is GroupInputException
              ? e.message
              : 'Could not answer the invitation. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text('Join ${widget.invitation.groupName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accept to become a member and access this private group. Decline to dismiss the invitation without joining.',
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(
                semanticsLabel: 'Saving invitation response',
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : () => _respond(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _respond(true),
          child: const Text('Accept invitation'),
        ),
      ],
    ),
  );
}
