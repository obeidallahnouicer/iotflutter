import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iot/services/ws_client.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({Key? key}) : super(key: key);

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<Map<String, dynamic>>? _destSub;
  StreamSubscription<double>? _speedLimitSub;
  LatLng? _current;
  LatLng? _destination;
  bool _follow = true;
  final List<LatLng> _waypoints = [];
  double? _currentSpeedLimit;
  DateTime? _lastSpeedAlert;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenForDestination();
    _listenForSpeedLimit();
  }
  
  void _listenForSpeedLimit() {
    // Listen for speed limit updates from backend via WebSocket
    _speedLimitSub = wsClient.speedLimitStream.listen((speedLimit) {
      setState(() {
        _currentSpeedLimit = speedLimit;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.speed, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🚦 Speed Limit Set: ${speedLimit.toStringAsFixed(0)} km/h',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade700,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('🚦 Speed limit updated: $speedLimit km/h');
    });
  }
  
  void _checkSpeedLimit(double currentSpeed) {
    if (_currentSpeedLimit == null) return;
    
    // Check if speed exceeds limit
    if (currentSpeed > _currentSpeedLimit!) {
      // Throttle alerts - only show once every 5 seconds
      final now = DateTime.now();
      if (_lastSpeedAlert != null && now.difference(_lastSpeedAlert!).inSeconds < 5) {
        return;
      }
      
      _lastSpeedAlert = now;
      
      // Show alert on mobile
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '⚠️ SPEED LIMIT EXCEEDED!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Current: ${currentSpeed.toStringAsFixed(0)} km/h | Limit: ${_currentSpeedLimit!.toStringAsFixed(0)} km/h',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Send alert to backend with complete information
      try {
        final alertId = 'ALERT-${DateTime.now().millisecondsSinceEpoch}';
        final currentPos = _current;
        
        wsClient.sendAlert({
          'id': alertId,
          'type': 'speedLimit',
          'speed': currentSpeed,
          'currentSpeed': currentSpeed,
          'speedLimit': _currentSpeedLimit,
          'lat': currentPos?.latitude ?? 0.0,
          'lng': currentPos?.longitude ?? 0.0,
          'deviceId': 'MOBILE-001',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'acknowledged': false,
          'message': 'Speed limit exceeded: ${currentSpeed.toStringAsFixed(1)} km/h (limit: ${_currentSpeedLimit!.toStringAsFixed(0)} km/h)',
        });
        print('⚠️ Speed alert sent to backend: $currentSpeed km/h > ${_currentSpeedLimit} km/h at ${currentPos?.latitude.toStringAsFixed(4)}, ${currentPos?.longitude.toStringAsFixed(4)}');
      } catch (e) {
        print('❌ Failed to send speed alert: $e');
      }
    }
  }

  void _listenForDestination() {
    // Listen for destination updates from backend via WebSocket
    _destSub = wsClient.destinationStream.listen((payload) {
      try {
        final lat = payload['lat'];
        final lng = payload['lng'];
        if (lat is num && lng is num) {
          final newDest = LatLng(lat.toDouble(), lng.toDouble());
          setState(() {
            _destination = newDest;
            _waypoints.clear();
            _waypoints.add(newDest);
          });
          
          // Show notification to driver
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎯 New Destination Received!\n${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          
          // Animate camera to show both current and destination
          if (_current != null) {
            _mapController.move(newDest, 10);
          }
          print('✓ Destination updated: ${newDest.latitude}, ${newDest.longitude}');
        }
      } catch (e) {
        print('❌ Error parsing destination: $e');
      }
    });
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
      final speedKmh = pos.speed.isNaN ? 0.0 : pos.speed * 3.6;
      print('📍 GPS Position: ${pos.latitude}, ${pos.longitude} | Accuracy: ${pos.accuracy}m | Speed: ${speedKmh.toStringAsFixed(1)} km/h');
      
      setState(() {
        _current = latlng;
      });
      
      // Check speed limit
      _checkSpeedLimit(speedKmh);
      
      try {
        // Send location envelope to backend via WS client
        wsClient.sendLocation({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'speed': speedKmh,
          'heading': pos.heading ?? 0.0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'accuracy': pos.accuracy,
        });
      } catch (e) {
        print('❌ Failed to send location: $e');
      }
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
    _destSub?.cancel();
    _speedLimitSub?.cancel();
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
      ],
    );
  }
}
