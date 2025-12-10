import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({Key? key}) : super(key: key);

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  LatLng? _current;
  LatLng? _destination;
  bool _follow = true;
  final List<LatLng> _waypoints = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    final settings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _current = latlng;
      });
      // keep map centered on user
      try {
        if (_follow) {
          _mapController.move(latlng, _mapController.zoom);
        }
      } catch (_) {}
    });
  }

  double _distanceKm() {
    // Sum distances from current through waypoints to final destination
    if (_current == null) return 0.0;
    final d = Distance();
    double total = 0.0;
    LatLng last = _current!;
    final targets = <LatLng>[];
    if (_waypoints.isNotEmpty) {
      targets.addAll(_waypoints);
    } else if (_destination != null) {
      targets.add(_destination!);
    }
    for (final t in targets) {
      total += d.as(LengthUnit.Kilometer, last, t);
      last = t;
    }
    return total;
  }

  double _bearing() {
    if (_current == null || _destination == null) return 0.0;
    final lat1 = _current!.latitude * math.pi / 180.0;
    final lon1 = _current!.longitude * math.pi / 180.0;
    final lat2 = _destination!.latitude * math.pi / 180.0;
    final lon2 = _destination!.longitude * math.pi / 180.0;
    final y = math.sin(lon2 - lon1) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
    final brng = (math.atan2(y, x) * 180.0 / math.pi + 360) % 360;
    return brng;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_current != null) {
      // Start / current position marker
      markers.add(Marker(
        width: 40,
        height: 40,
        point: _current!,
        builder: (ctx) => Container(
          decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
        ),
      ));
    }
    if (_destination != null) {
      markers.add(Marker(
        width: 36,
        height: 36,
        point: _destination!,
        builder: (ctx) => Container(
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: const Icon(Icons.flag, color: Colors.white, size: 18),
        ),
      ));
    }

    // Build route polyline: start from current (if available) then all waypoints
    final polylines = <Polyline>[];
    final routePoints = <LatLng>[];
    if (_current != null) routePoints.add(_current!);
    if (_waypoints.isNotEmpty) routePoints.addAll(_waypoints);
    // If no waypoints but a single destination exists, include it
    if (_waypoints.isEmpty && _destination != null) routePoints.add(_destination!);
    if (routePoints.length >= 2) {
      polylines.add(Polyline(points: routePoints, color: Colors.orange, strokeWidth: 4.0));
    }

    // Tunisia bounding box (approx): south-west to north-east
    final tunisiaBounds = LatLngBounds(LatLng(30.0, 7.5), LatLng(37.6, 11.8));

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _current ?? LatLng(34.0, 9.0),
                      zoom: 7.5,
                      minZoom: 6,
                      maxZoom: 16,
                      maxBounds: tunisiaBounds,
                      onLongPress: (tapPos, latlng) {
                        // only allow waypoints inside Tunisia bounds
                        if (tunisiaBounds.contains(latlng)) {
                          setState(() {
                            _waypoints.add(latlng);
                            _destination = _waypoints.isNotEmpty ? _waypoints.last : null;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  // Overlay buttons in top-right area of the card
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'follow',
                          onPressed: () => setState(() => _follow = !_follow),
                          backgroundColor: _follow ? Theme.of(context).colorScheme.primary : Colors.white,
                          foregroundColor: _follow ? Colors.white : Colors.black87,
                          child: const Icon(Icons.my_location),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'clear',
                          onPressed: () => setState(() {
                            _waypoints.clear();
                            _destination = null;
                          }),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          child: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destination', style: Theme.of(context).textTheme.bodySmall),
                    Text(_destination != null ? '${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}' : 'Long-press map to set (inside Tunisia)', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (_current != null && _destination != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_distanceKm().toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Transform.rotate(
                          angle: _bearing() * math.pi / 180.0,
                          child: const Icon(Icons.navigation, size: 18, color: Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text('${_bearing().toStringAsFixed(0)}°', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Itinerary / waypoints list
        if (_waypoints.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Itinerary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _waypoints.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final w = _waypoints[i];
                      return Chip(
                        backgroundColor: Colors.grey.shade100,
                        label: Text('${i + 1}: ${w.latitude.toStringAsFixed(4)}, ${w.longitude.toStringAsFixed(4)}'),
                        onDeleted: () {
                          setState(() {
                            _waypoints.removeAt(i);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        // Follow & clear buttons overlay
        PositionedButtons(
          follow: _follow,
          onToggleFollow: () => setState(() => _follow = !_follow),
          onClear: () => setState(() {
            _waypoints.clear();
            _destination = null;
          }),
        ),
      ],
    );
  }
}

class PositionedButtons extends StatelessWidget {
  final bool follow;
  final VoidCallback onToggleFollow;
  final VoidCallback onClear;

  const PositionedButtons({Key? key, required this.follow, required this.onToggleFollow, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 140,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'follow',
            onPressed: onToggleFollow,
            backgroundColor: follow ? Theme.of(context).colorScheme.primary : Colors.white,
            foregroundColor: follow ? Colors.white : Colors.black87,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'clear',
            onPressed: onClear,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }
}
