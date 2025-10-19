import 'package:flutter_riverpod/flutter_riverpod.dart';

class RideSearchState {
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final DateTime when;
  final int pax;
  final int luggage;

  RideSearchState({
    this.pickupAddress = '',
    this.pickupLat,
    this.pickupLng,
    this.dropoffAddress = '',
    this.dropoffLat,
    this.dropoffLng,
    DateTime? when,
    this.pax = 1,
    this.luggage = 0,
  }) : when = when ?? DateTime.now().add(const Duration(hours: 2));

  RideSearchState copyWith({
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
    DateTime? when,
    int? pax,
    int? luggage,
  }) {
    return RideSearchState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      when: when ?? this.when,
      pax: pax ?? this.pax,
      luggage: luggage ?? this.luggage,
    );
  }
}

// Riverpod v3: use Notifier/NotifierProvider
class RideSearchNotifier extends Notifier<RideSearchState> {
  @override
  RideSearchState build() => RideSearchState();

  void setPickup(String addr, double lat, double lng) => state = state.copyWith(
    pickupAddress: addr,
    pickupLat: lat,
    pickupLng: lng,
  );

  void setDropoff(String addr, double lat, double lng) => state = state
      .copyWith(dropoffAddress: addr, dropoffLat: lat, dropoffLng: lng);

  void setWhen(DateTime when) => state = state.copyWith(when: when);
  void setPax(int pax) => state = state.copyWith(pax: pax);
  void setLuggage(int l) => state = state.copyWith(luggage: l);
}

final rideSearchProvider =
    NotifierProvider<RideSearchNotifier, RideSearchState>(
        RideSearchNotifier.new,
    );