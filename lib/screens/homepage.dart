import 'package:flutter/material.dart';

import '../widgets/pretty_app_bar.dart';
import '../widgets/accelerometer.dart';
import '../widgets/speedometer.dart';
import '../widgets/map.dart';

/// A blank home page that uses the custom PrettyAppBar.
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PrettyAppBar(),
      body: SafeArea(
        child: Column(
          children: const [
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: AccelerometerWidget(),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Speedometer(),
            ),
            SizedBox(height: 12),
            Expanded(child: DriverMap()),
          ],
        ),
      ),
    );
  }
}
