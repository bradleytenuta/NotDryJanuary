import 'dart:ui';
import 'package:flutter/material.dart';

import '../../user_session_store.dart';

class PubVisitedChip extends StatelessWidget {
  const PubVisitedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<int>(
            valueListenable:
                UserSessionStore.instance.visitedPubsCountListenable,
            builder: (BuildContext context, int visitedCount, Widget? child) {
              return SizedBox(
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Glassmorphic background pill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.fromLTRB(48, 8, 20, 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '$visitedCount pubs visited',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Lager pint glass image spilling out
                    Positioned(
                      left: -20,
                      top: 0,
                      child: Image.asset(
                        'assets/icons/lager-pint.png',
                        height: 68,
                        width: 68,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
