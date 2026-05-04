import 'package:flutter/material.dart';

class Credits extends StatelessWidget {
  const Credits({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Credits'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1.4),
          },
          children: const <TableRow>[
            TableRow(
              children: <Widget>[
                _CreditsHeaderCell(text: 'Components'),
                _CreditsHeaderCell(text: 'Credit'),
              ],
            ),
            TableRow(
              children: <Widget>[
                _CreditsCell(text: 'Models'),
                _CreditsCell(text: 'Poly Pizza (Quaternius)'),
              ],
            ),
            TableRow(
              children: <Widget>[
                _CreditsCell(text: 'Animations'),
                _CreditsCell(text: 'Lottie (Theophile Menard)'),
              ],
            ),
            TableRow(
              children: <Widget>[
                _CreditsCell(text: 'Places'),
                _CreditsCell(text: 'Overpass Turbo'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsHeaderCell extends StatelessWidget {
  const _CreditsHeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreditsCell extends StatelessWidget {
  const _CreditsCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text),
    );
  }
}