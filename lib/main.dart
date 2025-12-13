import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iot/screens/biometric_auth.dart';
import 'package:iot/services/ws_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables with fallback defaults
  try {
    await dotenv.load(fileName: '.env');
    print('✓ Environment loaded successfully');
    print('✓ BACKEND_WS_URL: ${dotenv.env['BACKEND_WS_URL']}');
  } catch (e) {
    print('⚠ Failed to load .env file: $e');
    print('⚠ Using default configuration');
    // Set default values if .env fails to load
    dotenv.testLoad(fileInput: '''
ENCRYPTION_KEY_HEX=e2e084c8e4ca8ee09f13e2291fee228379f38652655ed7fcc2cb49ee2c7a58da
ENCRYPTION_IV_HEX=1a25791e410144a95110c4be5141e183
BACKEND_WS_URL=ws://10.0.2.2:3000
''');
    print('✓ Default configuration loaded');
  }
  
  // Start ws client if configured (non-blocking)
  try {
    wsClient.connect();
    print('✓ WebSocket client initialized');
  } catch (e) {
    print('⚠ Failed to initialize WebSocket client: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Vehicle Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BiometricAuth(),
    );
  }
}
