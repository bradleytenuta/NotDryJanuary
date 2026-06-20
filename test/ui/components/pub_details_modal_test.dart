import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notdryjanuary/domain/pub_feature.dart';
import 'package:notdryjanuary/ui/components/pub_details_modal.dart';

void main() {
  testWidgets('Pub details modal shows address when all fields are present', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '1',
      name: 'The Golden Lion',
      city: 'London',
      street: 'Dean Street',
      houseNumber: '51',
      postcode: 'W1D 5PL',
      wheelchair: 'yes',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('The Golden Lion'), findsOneWidget);
    expect(find.text('Dean Street 51, London - W1D 5PL'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('Pub details modal shows partial address when city is missing', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '2',
      name: 'The Silver Lion',
      city: 'Unknown',
      street: 'Dean Street',
      houseNumber: '51',
      postcode: 'W1D 5PL',
      wheelchair: 'yes',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('The Silver Lion'), findsOneWidget);
    expect(find.text('Dean Street 51 - W1D 5PL'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('Pub details modal shows partial address when postcode is missing', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '3',
      name: 'The Bronze Lion',
      city: 'London',
      street: 'Dean Street',
      houseNumber: '51',
      postcode: 'Unknown',
      wheelchair: 'yes',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('The Bronze Lion'), findsOneWidget);
    expect(find.text('Dean Street 51, London'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('Pub details modal shows only city when other components are missing/empty', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '4',
      name: 'City Pub',
      city: 'London',
      street: '   ',
      houseNumber: 'Unknown',
      postcode: 'Unknown',
      wheelchair: 'yes',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('City Pub'), findsOneWidget);
    expect(find.text('London'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('Pub details modal hides location row entirely if all fields are missing', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '5',
      name: 'No Address Pub',
      city: 'Unknown',
      street: 'Unknown',
      houseNumber: 'Unknown',
      postcode: 'Unknown',
      wheelchair: 'yes',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('No Address Pub'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('Pub details modal hides wheelchair access row if wheelchair is "Unknown"', (WidgetTester tester) async {
    const PubFeature feature = PubFeature(
      id: '6',
      name: 'No Wheelchair Info Pub',
      city: 'London',
      street: 'Dean Street',
      houseNumber: '51',
      postcode: 'W1D 5PL',
      wheelchair: 'Unknown',
      coordinates: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () => showPubDetailsModal(
                  context: context,
                  featureDetails: feature,
                ),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    expect(find.text('No Wheelchair Info Pub'), findsOneWidget);
    expect(find.textContaining('Wheelchair Access:'), findsNothing);
    expect(find.byIcon(Icons.accessible), findsNothing);
    expect(find.byIcon(Icons.not_accessible), findsNothing);
  });
}
