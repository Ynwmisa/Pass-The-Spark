import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/answer_draft.dart';

abstract interface class DraftStore {
  Future<AnswerDraft?> read(DraftKey key);
  Future<void> write(AnswerDraft draft);
}

/// Drafts stay in app-private support storage, outside the downloaded cache.
/// A successful write means flushed local data, not a published contribution.
class FileDraftStore implements DraftStore {
  FileDraftStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  final Map<String, Future<void>> _writes = {};

  String _name(DraftKey key) =>
      sha256.convert(utf8.encode(jsonEncode(key.parts))).toString();

  Future<File> _file(DraftKey key) async {
    final root = await _directoryProvider();
    final directory = Directory('${root.path}/answer_drafts');
    await directory.create(recursive: true);
    return File('${directory.path}/${_name(key)}.json');
  }

  @override
  Future<AnswerDraft?> read(DraftKey key) async {
    final pending = _writes[_name(key)];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        /* Read the last completed version. */
      }
    }
    final file = await _file(key);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid draft');
    }
    final draft = AnswerDraft.fromJson(decoded);
    if (jsonEncode(draft.key.parts) != jsonEncode(key.parts)) {
      throw const FormatException('Draft identity does not match');
    }
    return draft;
  }

  @override
  Future<void> write(AnswerDraft draft) async {
    final name = _name(draft.key);
    final previous = _writes[name] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      final file = await _file(draft.key);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(draft.toJson()), flush: true);
      await temporary.rename(file.path);
    });
    _writes[name] = next;
    try {
      await next;
    } finally {
      if (identical(_writes[name], next)) _writes.remove(name);
    }
  }
}
