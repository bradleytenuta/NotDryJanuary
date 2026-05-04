import 'package:flutter/material.dart';

import '../../features/pub_cache.dart';
import '../../user_session_store.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  static const String _defaultCharacter = 'casual_character';
  static const List<String> _characterOptions = <String>[
    'adventurer',
    'astronaut',
    'beach_character',
    'business_man',
    'casual_character',
    'farmer',
    'hoodie_character',
    'king',
    'punk',
    'swat',
    'worker',
  ];

  late final List<String> _deduplicatedCharacterOptions =
      _characterOptions.toSet().toList(growable: false);
  late final Future<_VisitedPubsViewData> _visitedPubsViewDataFuture =
      _loadVisitedPubsViewData();
  String? _selectedCharacter;
  Future<void>? _pendingCharacterSave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () async {
            final NavigatorState navigator = Navigator.of(context);
            final Future<void>? pendingSave = _pendingCharacterSave;
            if (pendingSave != null) {
              await pendingSave;
            }

            if (!mounted) {
              return;
            }
            navigator.pop();
          },
        ),
        title: const Text('My Account'),
      ),
      body: FutureBuilder<_VisitedPubsViewData>(
        future: _visitedPubsViewDataFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_VisitedPubsViewData> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load visited pubs.'),
            );
          }

          final _VisitedPubsViewData viewData = snapshot.data ??
              _VisitedPubsViewData(
                visitedPubNames: <String>[],
                character: _defaultCharacter,
              );
          final List<String> visitedPubNames = viewData.visitedPubNames;
          final String selectedCharacter = _deduplicatedCharacterOptions.contains(
                  _selectedCharacter ?? viewData.character)
              ? (_selectedCharacter ?? viewData.character)
              : _defaultCharacter;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Number of pubs visited: ${visitedPubNames.length}'),
                const SizedBox(height: 20),
                Text(
                  'My Character',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCharacter,
                      isExpanded: true,
                      items: _deduplicatedCharacterOptions
                          .map(
                            (String character) => DropdownMenuItem<String>(
                              value: character,
                              child: Text(character),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedCharacter = value;
                        });
                        _pendingCharacterSave =
                            UserSessionStore.instance.updateCharacter(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'My visited pubs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visitedPubNames.isEmpty
                      ? const Center(
                          child: Text('No pubs visited yet.'),
                        )
                      : ListView.separated(
                          itemCount: visitedPubNames.length,
                          separatorBuilder:
                              (BuildContext context, int index) =>
                                  const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(visitedPubNames[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_VisitedPubsViewData> _loadVisitedPubsViewData() async {
    final UserSessionData session = await UserSessionStore.instance.loadOrCreate();
    if (session.visitedPubs.isEmpty) {
      return _VisitedPubsViewData(
        visitedPubNames: const <String>[],
        character: session.character,
      );
    }

    final Set<String> visitedIds = session.visitedPubs.toSet();
    final Map<String, String> nameById = <String, String>{};
    final List<({String id, String name})> allFeatures =
        (await PubsGeoJsonCache.instance.loadFeatures())
            .map((feature) => (id: feature.id, name: feature.name))
            .toList(growable: false);

    for (final ({String id, String name}) feature in allFeatures) {
      if (visitedIds.contains(feature.id)) {
        nameById[feature.id] = feature.name;
      }
    }

    final List<String> visitedPubNames = session.visitedPubs
        .map((String id) => nameById[id] ?? id)
        .toList(growable: false);

    return _VisitedPubsViewData(
      visitedPubNames: visitedPubNames,
      character: session.character,
    );
  }
}

class _VisitedPubsViewData {
  const _VisitedPubsViewData({
    required this.visitedPubNames,
    required this.character,
  });

  final List<String> visitedPubNames;
  final String character;
}