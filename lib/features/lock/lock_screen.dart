import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/security_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (!ref.read(settingsProvider).biometric) return;
    if (await SecurityService.instance.authenticateBiometric()) widget.onUnlocked();
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length >= 4) {
      final ok = await SecurityService.instance.verifyPin(_pin);
      if (ok) {
        widget.onUnlocked();
      } else if (_pin.length == 6) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = true;
          _pin = '';
          _attempts++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            EnsoRing(
              progress: 0.9,
              size: 110,
              color: WaColors.beni,
              trackColor: Colors.transparent,
              child: const GlyphIcon('鍵', color: WaColors.washi, size: 44),
            ),
            const SizedBox(height: 20),
            Text(s.t('Masukkan PIN', 'Enter your PIN'), style: AppTheme.serif(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              _error
                  ? (_attempts > 2 ? s.t('PIN salah ($_attempts kali)', 'Wrong PIN ($_attempts tries)') : s.t('PIN salah', 'Wrong PIN'))
                  : s.t('Monshika terkunci', 'Monshika is locked'),
              style: AppTheme.sans(size: 13, color: _error ? WaColors.expense : WaColors.washiMuted),
            ),
            const SizedBox(height: 24),
            PinDots(length: _pin.length, error: _error),
            const Spacer(),
            PinPad(
              onDigit: _onDigit,
              onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
              extra: ref.watch(settingsProvider).biometric
                  ? IconButton(
                      iconSize: 30,
                      onPressed: _tryBiometric,
                      icon: const Icon(Icons.fingerprint, color: WaColors.accent),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.max = 6, this.error = false});

  final int length;
  final int max;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < max; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? (error ? WaColors.expense : WaColors.accent) : Colors.transparent,
              border: Border.all(color: error ? WaColors.expense : WaColors.washiFaint, width: 1.5),
            ),
          ),
      ],
    );
    return error ? row.animate().shakeX(hz: 6, amount: 6, duration: 400.ms) : row;
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.extra});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => SizedBox(
          width: 80,
          height: 68,
          child: TextButton(
            style: TextButton.styleFrom(shape: const CircleBorder(), foregroundColor: WaColors.washi),
            onPressed: () => onDigit(d),
            child: Text(d, style: AppTheme.serif(size: 28, weight: FontWeight.w500)),
          ),
        );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map(key).toList()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 80, height: 68, child: Center(child: extra)),
            key('0'),
            SizedBox(
              width: 80,
              height: 68,
              child: IconButton(onPressed: onBackspace, icon: const Icon(Icons.backspace_outlined)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Buat atau ganti PIN (dimasukkan dua kali). Mengembalikan true bila tersimpan.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _error = false;

  void _onDigit(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = false;
    });
  }

  Future<void> _next() async {
    if (_pin.length < 4) return;
    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _pin = '';
      });
      return;
    }
    await SecurityService.instance.setPin(_pin);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Atur PIN', 'Set PIN'))),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              _confirming ? s.t('Ketik ulang PIN', 'Enter PIN again') : s.t('Buat PIN 4 sampai 6 angka', 'Create a 4 to 6 digit PIN'),
              style: AppTheme.serif(size: 22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ? s.t('PIN tidak sama. Coba lagi.', "PINs don't match. Try again.") : s.t('PIN ini dipakai untuk membuka Monshika.', 'You will use this PIN to open Monshika.'),
              style: AppTheme.sans(size: 13, color: _error ? WaColors.expense : WaColors.washiMuted),
            ),
            const SizedBox(height: 28),
            PinDots(length: _pin.length, error: _error),
            const Spacer(),
            PinPad(
              onDigit: _onDigit,
              onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _pin.length >= 4 ? _next : null,
                  child: Text(_confirming ? s.t('Simpan PIN', 'Save PIN') : s.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
