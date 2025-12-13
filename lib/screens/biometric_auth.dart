import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:iot/screens/homepage.dart';

class BiometricAuth extends StatefulWidget {
  const BiometricAuth({Key? key}) : super(key: key);

  @override
  State<BiometricAuth> createState() => _BiometricAuthState();
}

class _BiometricAuthState extends State<BiometricAuth> with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isAuthenticated = false;
  String _statusMessage = 'Secure your app with biometric authentication';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isAuthenticated) {
      // Re-authenticate when app comes back from background
      _authenticate();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      print('🔐 Checking biometrics...');
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      print('🔐 canCheckBiometrics: $canCheckBiometrics');
      print('🔐 isDeviceSupported: $isDeviceSupported');

      if (!canCheckBiometrics || !isDeviceSupported) {
        setState(() {
          _statusMessage = 'Biometrics not available. Tap button below to continue.';
        });
        print('⚠️ Biometrics not available');
        return;
      }

      // Check available biometrics
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      
      print('🔐 Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        setState(() {
          _statusMessage = 'No biometrics enrolled. Tap button below to continue.';
        });
        print('⚠️ No biometrics enrolled');
        return;
      }

      // Auto-trigger authentication
      print('🔐 Auto-triggering authentication...');
      await Future.delayed(const Duration(milliseconds: 500));
      _authenticate();
    } catch (e) {
      print('❌ Error checking biometrics: $e');
      setState(() {
        _statusMessage = 'Error: $e\nTap button below to continue anyway.';
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Authenticating...';
    });

    try {
      print('🔐 Starting authentication...');
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the IoT Tracker',
      );

      print('🔐 Authentication result: $authenticated');

      if (authenticated) {
        setState(() {
          _isAuthenticated = true;
          _statusMessage = 'Authentication successful!';
        });

        // Navigate to home page
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        print('⚠️ Authentication failed');
        setState(() {
          _statusMessage = 'Authentication failed. Tap to try again or skip below.';
        });
      }
    } catch (e) {
      print('❌ Authentication error: $e');
      setState(() {
        _statusMessage = 'Error: $e\nTap to try again or skip below.';
      });
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  void _skipAuthentication() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.purple.shade900,
              Colors.indigo.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock Icon with animation
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _isAuthenticated
                                ? Icons.lock_open
                                : Icons.fingerprint,
                            size: 80,
                            color: _isAuthenticated
                                ? Colors.greenAccent
                                : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // App Title
                  const Text(
                    'IoT Vehicle Tracker',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Security Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security,
                          size: 16,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🔐 AES-256 Encrypted',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Status Message
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Authenticate Button
                  if (!_isAuthenticating && !_isAuthenticated)
                    ElevatedButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Authenticate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo.shade900,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                    ),

                  // Loading Indicator
                  if (_isAuthenticating)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),

                  const SizedBox(height: 16),
                  
                  // Skip Button (always available as fallback)
                  if (!_isAuthenticating && !_isAuthenticated)
                    TextButton(
                      onPressed: _skipAuthentication,
                      child: Text(
                        'Skip Authentication',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
