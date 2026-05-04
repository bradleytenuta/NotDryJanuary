import 'package:flutter/material.dart';

import '../../user_session_store.dart';

class PubVisitedChip extends StatelessWidget {
  const PubVisitedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<int>(
            valueListenable: UserSessionStore.instance.visitedPubsCountListenable,
            builder: (BuildContext context, int visitedCount, Widget? child) {
              return Chip(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                avatar: const Icon(
                  Icons.sports_bar,
                  color: Colors.black87,
                ),
                label: Text('$visitedCount pubs visited'),
              );
            },
          ),
        ),
      ),
    );
  }
}
