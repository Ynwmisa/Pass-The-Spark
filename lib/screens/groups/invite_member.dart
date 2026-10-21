import 'package:flutter/material.dart';
import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });
  final GroupRepository repository;
  final String groupId;
  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _details = widget.repository.loadGroup(widget.groupId);
  bool _saving = false;
  bool _sent = false;
  String? _error;
  Future<void> _send() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.inviteMember(widget.groupId, _email.text);
      if (mounted) {
        setState(() {
          _saving = false;
          _sent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is GroupInputException
              ? e.message
              : 'Could not send the invitation. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_sent ? 'Invitation sent' : 'Invite member')),
      body: FutureBuilder<GroupDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('This group is unavailable. Go back and try again.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final details = snapshot.requireData;
          if (!details.isViewerOrganiser) {
            return const Center(
              child: Text('Only the group organiser can invite members.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check, size: 64, color: AppColors.teal),
                      const SizedBox(height: 16),
                      Text(
                        'Invitation ready for ${_email.text.trim()}',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'They can accept or decline in Groups after signing in with this verified email. No email notification was sent.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _sent = false;
                    _email.clear();
                  }),
                  child: const Text('Invite another member'),
                ),
              ] else
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        details.group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Invite a student using their account email. The invitation appears in their Groups page after they verify that address.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'student@example.com',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: validateInvitationEmail,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Invitations expire after 7 days. They will only gain access if they accept.',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _send,
                        child: Text(_saving ? 'Sending…' : 'Send invitation'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
