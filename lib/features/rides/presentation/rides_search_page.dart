// lib/features/rides/presentation/rides_search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/places_service.dart';
import '../state/ride_search_state.dart';

class RidesSearchPage extends ConsumerStatefulWidget {
  const RidesSearchPage({super.key});

  @override
  ConsumerState<RidesSearchPage> createState() => _RidesSearchPageState();
}

class _RidesSearchPageState extends ConsumerState<RidesSearchPage> {
  late final PlacesService _places;
  late String _placesSession;
  String _newSession() => 'sess_${DateTime.now().microsecondsSinceEpoch}';

  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();

  List<PlaceSuggestion> _pickupSuggestions = const [];
  List<PlaceSuggestion> _dropSuggestions = const [];
  bool _selectingPickup = true;
  bool _loadingPickup = false;
  bool _loadingDrop = false;

  @override
  void initState() {
    super.initState();
    _placesSession = _newSession(); // one token per search flow
    _places = PlacesService();

    // Pre-fill text fields from state if user navigated back
    final s = ref.read(rideSearchProvider);
    _pickupCtrl.text = s.pickupAddress;
    _dropCtrl.text = s.dropoffAddress;
  }

  void _resetSession() {
    _placesSession = _newSession();
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  Future<void> _onPickupChanged(String v) async {
    setState(() {
      _selectingPickup = true;
      _loadingPickup = v.trim().length >= 2;
    });
    if (v.trim().length < 2) {
      setState(() => _pickupSuggestions = const []);
      return;
    }

    try {
      // 👇 Pass the shared Places session token
      final res = await _places.autocomplete(
        v,
        language: 'pt',
        country: 'pt',
        sessionToken: _placesSession,
      );
      if (!mounted) return;
      setState(() => _pickupSuggestions = res);
    } finally {
      if (mounted) setState(() => _loadingPickup = false);
    }
  }

  Future<void> _onDropChanged(String v) async {
    setState(() {
      _selectingPickup = false;
      _loadingDrop = v.trim().length >= 2;
    });
    if (v.trim().length < 2) {
      setState(() => _dropSuggestions = const []);
      return;
    }

    try {
      // 👇 Pass the shared Places session token
      final res = await _places.autocomplete(
        v,
        language: 'pt',
        country: 'pt',
        sessionToken: _placesSession,
      );
      if (!mounted) return;
      setState(() => _dropSuggestions = res);
    } finally {
      if (mounted) setState(() => _loadingDrop = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    // 👇 Pass the same token for details to tie it to the autocomplete session
    final details = await _places.details(
      s.placeId,
      language: 'pt',
      sessionToken: _placesSession,
    );
    if (!mounted || details == null) return;

    final notifier = ref.read(rideSearchProvider.notifier);

    if (_selectingPickup) {
      _pickupCtrl.text = details.address.isNotEmpty ? details.address : s.description;
      notifier.setPickup(_pickupCtrl.text, details.lat, details.lng);
      setState(() => _pickupSuggestions = const []);
      _dropFocus.requestFocus();
    } else {
      _dropCtrl.text = details.address.isNotEmpty ? details.address : s.description;
      notifier.setDropoff(_dropCtrl.text, details.lat, details.lng);
      setState(() => _dropSuggestions = const []);
      _dropFocus.unfocus();
    }
  }

  Future<void> _pickDateTime() async {
    final state = ref.read(rideSearchProvider);
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: state.when.isAfter(now) ? state.when : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(state.when),
    );
    if (!mounted || pickedTime == null) return;

    ref.read(rideSearchProvider.notifier).setWhen(
      DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(rideSearchProvider);

    final canSearch = s.pickupLat != null && s.dropoffLat != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Rides')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pickup
          TextField(
            controller: _pickupCtrl,
            focusNode: _pickupFocus,
            decoration: InputDecoration(
              labelText: 'Pickup',
              prefixIcon: const Icon(Icons.my_location),
              suffixIcon: _loadingPickup
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
                  : (s.pickupLat != null ? const Icon(Icons.check_circle, color: Colors.green) : null),
            ),
            textInputAction: TextInputAction.next,
            onChanged: _onPickupChanged,
          ),
          if (_pickupSuggestions.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              child: Column(
                children: _pickupSuggestions
                    .map((p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectSuggestion(p),
                ))
                    .toList(),
              ),
            ),

          // Drop-off
          TextField(
            controller: _dropCtrl,
            focusNode: _dropFocus,
            decoration: InputDecoration(
              labelText: 'Drop-off',
              prefixIcon: const Icon(Icons.flag_outlined),
              suffixIcon: _loadingDrop
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
                  : (s.dropoffLat != null ? const Icon(Icons.check_circle, color: Colors.green) : null),
            ),
            textInputAction: TextInputAction.done,
            onChanged: _onDropChanged,
          ),
          if (_dropSuggestions.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              child: Column(
                children: _dropSuggestions
                    .map((p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectSuggestion(p),
                ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 12),

          // When + Pax + Luggage
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    'When: ${TimeOfDay.fromDateTime(s.when).format(context)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: s.pax,
                  decoration: const InputDecoration(
                    labelText: 'Passengers',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                  items: [1, 2, 3, 4, 5, 6, 7, 8].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) => ref.read(rideSearchProvider.notifier).setPax(v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: s.luggage,
                  decoration: const InputDecoration(
                    labelText: 'Bags',
                    prefixIcon: Icon(Icons.luggage_outlined),
                  ),
                  items: [0, 1, 2, 3, 4, 5, 6].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) => ref.read(rideSearchProvider.notifier).setLuggage(v ?? 0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // CTA
          FilledButton.icon(
            onPressed: canSearch ? () => context.go('/rides/results') : null,
            icon: const Icon(Icons.search),
            label: const Text('See vehicles & estimates'),
          ),
        ],
      ),
    );
  }
}
