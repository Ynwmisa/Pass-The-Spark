import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../widgets/local_groups_notice.dart';

class GroupFormScreen extends StatefulWidget {
  const GroupFormScreen({
    super.key,
    required this.repository,
    this.join = false,
  });
  final GroupRepository repository;
  final bool join;

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _createdId;
  String? _resultName;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.join) {
        final request = await widget.repository.requestToJoin(_input.text);
        if (!mounted) return;
        setState(() => _resultName = request.groupName);
      } else {
        final details = await widget.repository.createGroup(_input.text);
        if (!mounted) return;
        setState(() {
          _createdId = details.group.id;
          _resultName = details.group.name;
        });
      }
    } on GroupInputException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save this change. Your input is kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.join ? 'Join a group' : 'Create group'),
        automaticallyImplyLeading: !_saving,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (widget.repository.isLocalPreview) const LocalGroupsNotice(),
              if (_resultName != null) ...[
                Icon(
                  widget.join
                      ? Icons.hourglass_top
                      : Icons.check_circle_outline,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.join
                      ? (widget.repository.isLocalPreview
                            ? 'Request saved locally'
                            : 'Request sent')
                      : 'Your circle is ready',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.join
                      ? (widget.repository.isLocalPreview
                            ? 'Your request for $_resultName is pending in this preview. Nothing has been sent to an organiser and you cannot open private content.'
                            : 'Your request for $_resultName is waiting for organiser approval. You are not a member yet.')
                      : (widget.repository.isLocalPreview
                            ? '$_resultName was created for this session. You are the organiser and first spark holder.'
                            : '$_resultName is ready. You are the organiser and first spark holder.'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(
                    widget.join ? '/groups' : '/groups/$_createdId',
                  ),
                  child: Text(widget.join ? 'Back to groups' : 'Open group'),
                ),
              ] else ...[
                Text(
                  widget.join ? 'Find your circle' : 'Start a new circle',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.join
                      ? 'Enter your invitation code to request a place in the group.'
                      : 'Choose a name your group will recognise. You will have the first turn.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _input,
                  enabled: !_saving,
                  maxLength: widget.join ? 12 : 60,
                  textCapitalization: widget.join
                      ? TextCapitalization.characters
                      : TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  autocorrect: !widget.join,
                  decoration: InputDecoration(
                    labelText: widget.join ? 'Invite code' : 'Group name',
                    hintText: widget.join
                        ? 'For example STUDY26'
                        : 'For example Project Circle',
                    border: const OutlineInputBorder(),
                    helperText: widget.join
                        ? (widget.repository.isLocalPreview
                              ? 'Try STUDY26 for a local demo request.'
                              : 'Ask your organiser for the group code.')
                        : 'Up to 60 characters.',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (widget.join) return validateInviteCode(value);
                    final error = validateGroupName(value);
                    if (error != null) return error;
                    if ((value ?? '').trim().characters.length > 60) {
                      return 'Use 60 characters or fewer.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : widget.join
                        ? 'Request to join'
                        : 'Create group',
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.join)
                  const Text(
                    'A request does not give access to members, prompts or shared answers.',
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
