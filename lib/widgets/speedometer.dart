import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class Speedometer extends StatefulWidget {
  final double maxSpeed;
  const Speedometer({Key? key, this.maxSpeed = 200}) : super(key: key);

  @override
  State<Speedometer> createState() => _SpeedometerState();
}

class _SpeedometerState extends State<Speedometer> {
  StreamSubscription<Position>? _positionSub;
  double _speedKmh = 0.0;

  @override
  void initState() {
    super.initState();
    _initLocationStream();
  }

  Future<void> _initLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position pos) {
      double speed = pos.speed; // m/s
      if (speed.isNaN) speed = 0.0;
      setState(() {
        _speedKmh = (speed * 3.6);
      });
    }, onError: (err) {
      // ignore stream errors for now
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final accent = Theme.of(context).colorScheme.primary;
    final fraction = (_speedKmh / widget.maxSpeed).clamp(0.0, 1.0);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 18,
                    backgroundColor: accent.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _speedKmh.toStringAsFixed(1),
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text('km/h', style: TextStyle(color: textColor.withOpacity(0.8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Max ${widget.maxSpeed.toInt()} km/h', style: TextStyle(color: textColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}
