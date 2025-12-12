// Runtime configuration accessor. Reads from environment (.env) using flutter_dotenv.
// Do NOT commit real secrets. Populate .env or use secure build-time injection.

import 'package:flutter_dotenv/flutter_dotenv.dart';

String get encryptionKeyHex => dotenv.env['ENCRYPTION_KEY_HEX'] ?? '';
String get encryptionIvHex => dotenv.env['ENCRYPTION_IV_HEX'] ?? '';
String get backendWsUrl => dotenv.env['BACKEND_WS_URL'] ?? '';

// Example usage: ensure you call `await dotenv.load()` in main() before accessing these.
