import 'package:flutter/material.dart';

import '../../domain/pub_feature.dart';

Future<void> showPubDetailsModal({
  required BuildContext context,
  required PubFeature featureDetails,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return _PubDetailsBottomSheet(featureDetails: featureDetails);
    },
  );
}

class _PubDetailsBottomSheet extends StatelessWidget {
  const _PubDetailsBottomSheet({required this.featureDetails});

  final PubFeature featureDetails;

  @override
  Widget build(BuildContext context) {
    final String address =
        '${featureDetails.city}, ${featureDetails.street}, ${featureDetails.houseNumber} - ${featureDetails.postcode}';

    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (featureDetails.brand != null && featureDetails.brand!.isNotEmpty)
                Text('Brand: ${featureDetails.brand}'),
              Text('Name: ${featureDetails.name}'),
              Text('Address: $address'),
              Text('Wheelchair access: ${featureDetails.wheelchair}'),
            ],
          ),
        ),
      ),
    );
  }
}