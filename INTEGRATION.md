Integration notes — Flutter mobile app

This document explains how the Flutter app must format messages and how to configure AES keys for compatibility with the Node backend.

Message envelope

All outbound messages from the mobile app should use the unified envelope:

{
  "type": "location" | "alert" | "destination" | "speedLimit" | "handshake",
  "timestamp": <unix_ms>,
  "payload": { ... }
}

Encryption

- The project provides `lib/services/crypto.dart` which implements AES-256-CBC (via the `encrypt` package) and produces hex strings compatible with the backend's `ENCRYPTION_KEY`/`ENCRYPTION_IV`.
- For secure setups, load keys from a secure store at runtime and set the constants in `lib/config.dart` during build time using environment-specific build scripts. Do NOT check secrets into source control.

SSH

- The mobile-side SSH client is not implemented in this repository. The backend (`NODE_IOT`) acts as the SSH bridge and will attempt to connect to an SSH endpoint (this could be the mobile device when set up). On the mobile side, you would usually run an SSH server or persistent channel to exchange messages.

Testing locally

- To test encrypted messages end-to-end, ensure the same AES key/IV hex values are used in the backend (ENCRYPTION_KEY/ENCRYPTION_IV) and in the mobile `lib/config.dart`.
- Use the admin dashboard to send destinations/speed limits and observe WebSocket events in the dashboard after the backend publishes them.
