import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerWidget extends StatefulWidget {
  const AccelerometerWidget({Key? key}) : super(key: key);

  @override
  State<AccelerometerWidget> createState() => _AccelerometerWidgetState();
}

class _AccelerometerWidgetState extends State<AccelerometerWidget> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double x = 0, y = 0, z = 0;
  DateTime? lastUpdate;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        x = event.x;
        y = event.y;
        z = event.z;
        lastUpdate = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get magnitude => sqrt(x * x + y * y + z * z);

  @override
  Widget build(BuildContext context) {
    final moved = magnitude > 1.5; // threshold for noticeable movement
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: moved ? Colors.amber.shade700 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(moved ? Icons.sensors : Icons.sensors_off, color: moved ? Colors.white : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accelerometer', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('x: ${x.toStringAsFixed(2)}    y: ${y.toStringAsFixed(2)}    z: ${z.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('mag: ${magnitude.toStringAsFixed(2)}'),
                      const SizedBox(width: 10),
                      if (lastUpdate != null) Text('last: ${lastUpdate!.toIso8601String().substring(11, 19)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
