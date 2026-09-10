import 'package:flutter/material.dart';

import 'location.dart';
import 'places.dart';
import 'places_autocomplete.dart';

class AreaSelectorField extends StatelessWidget {
  final String value;
  final DiscoveryLocation location;
  final ValueChanged<String> onChanged;
  final GooglePlacesClient? placesClient;
  final bool enabled;
  final String? helperText;
  final String labelText;

  const AreaSelectorField({
    super.key,
    required this.value,
    required this.location,
    required this.onChanged,
    this.placesClient,
    this.enabled = true,
    this.helperText,
    this.labelText = 'Area',
  });

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AreaPicker(
        currentValue: value,
        location: location,
        placesClient: placesClient,
      ),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final label = value.trim().isEmpty ? 'Any area' : value.trim();
    return Semantics(
      button: true,
      label: '$labelText, $label',
      child: InkWell(
        key: const Key('area-selector-field'),
        onTap: enabled && location.isConfigured ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            helperText: helperText,
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: const Icon(Icons.chevron_right),
            border: const OutlineInputBorder(),
            enabled: enabled && location.isConfigured,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Align(alignment: Alignment.centerLeft, child: Text(label)),
          ),
        ),
      ),
    );
  }
}

class _AreaPicker extends StatelessWidget {
  final String currentValue;
  final DiscoveryLocation location;
  final GooglePlacesClient? placesClient;

  const _AreaPicker({
    required this.currentValue,
    required this.location,
    this.placesClient,
  });

  @override
  Widget build(BuildContext context) {
    final client = placesClient ?? GooglePlacesClient();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('area-selector-cancel'),
                tooltip: 'Close area selector',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Choose an area in ${location.city}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          ListTile(
            key: const Key('area-selector-any'),
            leading: const Icon(Icons.public_outlined),
            title: const Text('Any area'),
            trailing: currentValue.trim().isEmpty
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          const SizedBox(height: 8),
          if (client.isConfigured)
            PlacesAutocompleteField(
              key: const Key('area-places-autocomplete'),
              labelText: 'Search areas',
              hintText: 'Neighborhood or area',
              client: client,
              areasOnly: true,
              countryCode: location.countryCode,
              biasLatitude: location.latitude,
              biasLongitude: location.longitude,
              emptyMessage: 'No areas found.',
              onSelected: (candidate) {
                if (!isAreaInDiscoveryLocation(candidate, location)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Choose an area in ${location.city}, ${location.countryCode.toUpperCase()}.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, candidate.area.trim());
              },
            )
          else
            Semantics(
              liveRegion: true,
              child: const Text(
                'Area suggestions are unavailable. You can choose Any area.',
                key: Key('area-selector-unavailable'),
              ),
            ),
          if (currentValue.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Current area: ${currentValue.trim()}',
              key: const Key('area-selector-current'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
