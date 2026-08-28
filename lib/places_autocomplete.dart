import 'dart:async';

import 'package:flutter/material.dart';

import 'location.dart';
import 'places.dart';

class PlacesAutocompleteField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final bool citiesOnly;
  final bool enabled;
  final GooglePlacesClient? client;
  final String initialText;
  final ValueChanged<MatchLocation> onSelected;

  const PlacesAutocompleteField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.onSelected,
    this.citiesOnly = false,
    this.enabled = true,
    this.client,
    this.initialText = '',
  });

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  late final GooglePlacesClient _client;
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlacePrediction> _predictions = const [];
  bool _loading = false;
  String? _error;
  int _requestNumber = 0;
  late String _sessionToken;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? GooglePlacesClient();
    _controller.text = widget.initialText;
    _sessionToken = _newSessionToken();
  }

  @override
  void didUpdateWidget(covariant PlacesAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  String _newSessionToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final request = ++_requestNumber;
    if (value.trim().length < 2) {
      setState(() {
        _predictions = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final results = await _client.autocomplete(
          value,
          sessionToken: _sessionToken,
          citiesOnly: widget.citiesOnly,
        );
        if (!mounted || request != _requestNumber) return;
        setState(() => _predictions = results);
      } on PlacesException catch (error) {
        if (!mounted || request != _requestNumber) return;
        setState(() {
          _predictions = const [];
          _error = error.message;
        });
      } finally {
        if (mounted && request == _requestNumber) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Future<void> _select(PlacePrediction prediction) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _controller.text = prediction.label;
      _predictions = const [];
      _loading = true;
      _error = null;
    });
    try {
      final location = await _client.placeDetails(
        prediction.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      widget.onSelected(location);
      _sessionToken = _newSessionToken();
    } on PlacesException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_client.isConfigured) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('places-autocomplete-field'),
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: const TextStyle(color: Colors.orange)),
          ),
        if (_predictions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: _predictions
                  .map(
                    (prediction) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(prediction.label),
                      onTap: () => _select(prediction),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
