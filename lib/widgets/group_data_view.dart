import 'package:flutter/material.dart';

import '../repositories/group_repository.dart';

/// Reloads once per repository change, not once per widget rebuild.
class GroupDataView<T> extends StatefulWidget {
  const GroupDataView({
    super.key,
    required this.repository,
    required this.load,
    required this.builder,
    this.errorMessage = 'Your groups could not be loaded.',
  });
  final GroupRepository repository;
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  final String errorMessage;

  @override
  State<GroupDataView<T>> createState() => _GroupDataViewState<T>();
}

class _GroupDataViewState<T> extends State<GroupDataView<T>> {
  late Future<T> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.load();
    widget.repository.addListener(_changed);
  }

  void _changed() {
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    final next = widget.load();
    setState(() {
      _data = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder provides retry. */
    }
  }

  @override
  void didUpdateWidget(covariant GroupDataView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_changed);
      widget.repository.addListener(_changed);
      _data = widget.load();
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.errorMessage, textAlign: TextAlign.center),
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
      if (snapshot.connectionState != ConnectionState.done ||
          !snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading groups'),
        );
      }
      return widget.builder(context, snapshot.requireData, _refresh);
    },
  );
}
