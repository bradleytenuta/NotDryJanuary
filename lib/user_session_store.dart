import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class UserSessionData {
  const UserSessionData({
    required this.character,
    required this.visitedPubs,
  });

  final String character;
  final List<String> visitedPubs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'character': character,
      'visited_pubs': visitedPubs,
    };
  }

  factory UserSessionData.fromJson(Map<String, dynamic> json) {
    final String character = (json['character'] as String?)?.trim() ?? '';
    final List<String> visitedPubs = ((json['visited_pubs'] as List<dynamic>?) ??
            const <dynamic>[])
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);

    if (character.isEmpty) {
      return UserSessionData(
        character: UserSessionStore.defaultSession.character,
        visitedPubs: visitedPubs,
      );
    }

    return UserSessionData(
      character: character,
      visitedPubs: visitedPubs,
    );
  }
}

class UserSessionStore {
  UserSessionStore._();

  static final UserSessionStore instance = UserSessionStore._();

  static const String _sessionFileName = 'user_session.json';
  static const UserSessionData defaultSession = UserSessionData(
    character: 'casual_character',
    visitedPubs: <String>[],
  );
  final ValueNotifier<int> _visitedPubsCountNotifier = ValueNotifier<int>(0);

  ValueListenable<int> get visitedPubsCountListenable =>
      _visitedPubsCountNotifier;

  Future<UserSessionData> loadOrCreate() async {
    final File file = await _sessionFile();

    if (!await file.exists()) {
      await _writeSession(file, defaultSession);
      _visitedPubsCountNotifier.value = defaultSession.visitedPubs.length;
      return defaultSession;
    }

    try {
      final String raw = await file.readAsString();
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      final UserSessionData session = UserSessionData.fromJson(decoded);

      // Ensure the file is normalized with expected keys and defaults.
      await _writeSession(file, session);
      _visitedPubsCountNotifier.value = session.visitedPubs.length;
      return session;
    } catch (_) {
      await _writeSession(file, defaultSession);
      _visitedPubsCountNotifier.value = defaultSession.visitedPubs.length;
      return defaultSession;
    }
  }

  Future<File> _sessionFile() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_sessionFileName');
  }

  Future<void> _writeSession(File file, UserSessionData session) async {
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<void> addVisitedPubs(Iterable<String> pubIds) async {
    final List<String> normalizedIds = pubIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }

    final UserSessionData session = await loadOrCreate();
    final Set<String> mergedVisitedIds = session.visitedPubs.toSet();
    mergedVisitedIds.addAll(normalizedIds);

    if (mergedVisitedIds.length == session.visitedPubs.length) {
      return;
    }

    final UserSessionData updatedSession = UserSessionData(
      character: session.character,
      visitedPubs: mergedVisitedIds.toList(growable: false),
    );

    final File file = await _sessionFile();
    await _writeSession(file, updatedSession);
    _visitedPubsCountNotifier.value = updatedSession.visitedPubs.length;
  }

  Future<void> updateCharacter(String character) async {
    final String normalizedCharacter = character.trim();
    if (normalizedCharacter.isEmpty) {
      return;
    }

    final UserSessionData session = await loadOrCreate();
    if (session.character == normalizedCharacter) {
      return;
    }

    final UserSessionData updatedSession = UserSessionData(
      character: normalizedCharacter,
      visitedPubs: session.visitedPubs,
    );

    final File file = await _sessionFile();
    await _writeSession(file, updatedSession);
  }
}