// lib/presentation/screens/pin_setup_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../generated/l10n.dart';

import '../providers/app_providers.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _error;

  void _onDigit(String digit) {
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) _isConfirming = true;
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) _confirm();
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _confirm() async {
    final s = S.of(context);
    if (_pin != _confirmPin) {
      setState(() {
        _error = s.pinMismatch;
        _confirmPin = '';
        _isConfirming = false;
        _pin = '';
      });
      return;
    }

    final hash = sha256.convert(utf8.encode(_pin)).toString();
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      await ref
          .read(settingsProvider.notifier)
          .saveSettings(settings.copyWith(pinEnabled: true, pinHash: hash));
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _isConfirming ? s.confirmPin : s.createPin,
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 60,
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            Text(
              _isConfirming ? s.reenterPin : s.enter4Digits,
              style: GoogleFonts.notoSerif(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            if (_error != null)
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                ),
              ).animate().shake(),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < currentPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 48),

            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((d) {
                if (d.isEmpty) return const SizedBox(width: 80, height: 64);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => d == '⌫' ? _onDelete() : _onDigit(d),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d == '⌫'
                            ? Colors.transparent
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        border: d == '⌫'
                            ? null
                            : Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                              ),
                      ),
                      child: Center(
                        child: d == '⌫'
                            ? Icon(
                                Icons.backspace_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : Text(
                                d,
                                style: GoogleFonts.notoSerif(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── PIN Verify Screen ────────────────────────────────────────────────────────

class PinVerifyScreen extends ConsumerStatefulWidget {
  final VoidCallback onVerified;

  const PinVerifyScreen({super.key, required this.onVerified});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen> {
  final _localAuth = LocalAuthentication();
  String _pin = '';
  String? _error;
  int _attempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricIfEnabled();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryBiometricIfEnabled() async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.biometricEnabled) return;
    await _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_lockoutSeconds > 0) return;
    final s = S.of(context);
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) return;

      final authenticated = await _localAuth.authenticate(
        localizedReason: s.biometricReason,
      );
      if (authenticated && mounted) {
        widget.onVerified();
      }
    } catch (_) {}
  }

  void _startLockout() {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSeconds = 30;
      _pin = '';
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds--;
        if (_lockoutSeconds <= 0) {
          _attempts = 0;
          _error = null;
          timer.cancel();
        }
      });
    });
  }

  void _onDigit(String d) {
    if (_lockoutSeconds > 0 || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_lockoutSeconds > 0 || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    final settings = ref.read(settingsProvider).value;
    final s = S.of(context);
    if (settings?.pinHash == null) {
      widget.onVerified();
      return;
    }
    final hash = sha256.convert(utf8.encode(_pin)).toString();
    if (hash == settings!.pinHash) {
      widget.onVerified();
    } else {
      _attempts++;
      if (_attempts >= 3) {
        _startLockout();
      } else {
        setState(() {
          _error = s.incorrectPin(3 - _attempts);
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider).value;
    final biometricEnabled = settings?.biometricEnabled ?? false;
    final displayError = _lockoutSeconds > 0
        ? s.tooManyAttempts(_lockoutSeconds)
        : _error;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💕', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 24),
              Text(
                s.enterPin,
                style: GoogleFonts.notoSerif(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (displayError != null)
                Text(
                  displayError,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().shake(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    [biometricEnabled ? 'BIO' : '', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.map((d) {
                          if (d.isEmpty) {
                            return const SizedBox(width: 80, height: 56);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(36),
                              onTap: _lockoutSeconds > 0
                                  ? null
                                  : () {
                                      if (d == '⌫') {
                                        _onDelete();
                                      } else if (d == 'BIO') {
                                        _authenticateWithBiometrics();
                                      } else {
                                        _onDigit(d);
                                      }
                                    },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (d == '⌫' || d == 'BIO')
                                      ? Colors.transparent
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                ),
                                child: Center(
                                  child: d == '⌫'
                                      ? Icon(
                                          Icons.backspace_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 20,
                                        )
                                      : d == 'BIO'
                                      ? Icon(
                                          Icons.fingerprint_rounded,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 28,
                                        )
                                      : Text(
                                          d,
                                          style: GoogleFonts.notoSerif(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
