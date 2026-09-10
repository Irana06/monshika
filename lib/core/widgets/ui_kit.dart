import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/kanji_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

// -----------------------------------------------------------------------------
// Kartu & dekorasi
// -----------------------------------------------------------------------------

class WaCard extends StatelessWidget {
  const WaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.pattern = false,
    this.borderColor,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final bool pattern;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? WaColors.keshizumi) : null,
          gradient: gradient,
          borderRadius: br,
          border: Border.all(color: borderColor ?? WaColors.border),
        ),
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: br,
            child: Stack(
              children: [
                if (pattern)
                  Positioned.fill(
                    child: CustomPaint(painter: SeigaihaPainter(color: WaColors.washi.withValues(alpha: 0.035))),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pola ombak seigaiha (青海波).
class SeigaihaPainter extends CustomPainter {
  SeigaihaPainter({required this.color, this.radius = 22});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = radius;
    var row = 0;
    for (var y = -r; y < size.height + r; y += r / 2) {
      final offset = row.isOdd ? r : 0.0;
      for (var x = -2 * r + offset; x < size.width + 2 * r; x += 2 * r) {
        for (var k = 1; k <= 4; k++) {
          final rr = r * k / 4;
          canvas.drawArc(Rect.fromCircle(center: Offset(x, y + r), radius: rr), math.pi, math.pi, false, paint);
        }
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant SeigaihaPainter old) => old.color != color || old.radius != radius;
}

/// Lingkaran kuas ensō (円相) sebagai indikator progres.
class EnsoRing extends StatelessWidget {
  const EnsoRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.stroke = 7,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = progress.isNaN ? 0.0 : progress;
    final c = color ?? (p >= 1 ? WaColors.expense : (p >= 0.8 ? WaColors.yamabuki : WaColors.accent));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: p.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _EnsoPainter(
            progress: value,
            color: c,
            track: trackColor ?? WaColors.border,
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter({required this.progress, required this.color, required this.track, required this.stroke});

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2 + 0.25;
    const fullSweep = 2 * math.pi - 0.5; // celah khas ensō

    canvas.drawArc(
      rect,
      start,
      fullSweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.55
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;
    // Goresan kuas: tebal di awal, meruncing di akhir.
    const segments = 48;
    final sweep = fullSweep * progress;
    for (var i = 0; i < segments; i++) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      final w = stroke * (1.15 - 0.6 * t0);
      canvas.drawArc(
        rect,
        start + sweep * t0,
        sweep * (t1 - t0) + 0.01,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.95 - 0.25 * t0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnsoPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Lencana kanji berwarna untuk kategori/dompet.
class KanjiBadge extends StatelessWidget {
  const KanjiBadge({super.key, required this.glyph, required this.color, this.size = 42, this.radius});

  final String glyph;
  final Color color;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius ?? size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        glyph,
        style: AppTheme.serif(size: size * 0.46, weight: FontWeight.w700, color: color, height: 1.1),
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText(
    this.amount,
    this.currency, {
    super.key,
    this.type,
    this.style,
    this.hidden = false,
    this.compact = false,
    this.signed = false,
  });

  final double amount;
  final String currency;
  final String? type;
  final TextStyle? style;
  final bool hidden;
  final bool compact;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'income' => WaColors.income,
      'expense' => WaColors.expense,
      'transfer' => WaColors.transfer,
      _ => null,
    };
    final value = switch (type) {
      'expense' when signed => -amount.abs(),
      'income' when signed => amount.abs(),
      _ => amount,
    };
    return Text(
      formatMoney(value, currency, hidden: hidden, compact: compact, showSign: signed),
      style: (style ?? AppTheme.sans(size: 15, weight: FontWeight.w700)).copyWith(color: color ?? style?.color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.jp, this.action, this.onAction});

  final String title;
  final String? jp;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (jp != null) ...[
            Text(jp!, style: AppTheme.serif(size: 16, color: WaColors.accent, weight: FontWeight.w700)),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title, style: AppTheme.serif(size: 17, weight: FontWeight.w600))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: AppTheme.sans(size: 13, color: WaColors.accent, weight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.kanji, required this.title, this.subtitle, this.action, this.onAction});

  final String kanji;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnsoRing(
              progress: 0.92,
              size: 96,
              color: WaColors.washiFaint,
              trackColor: Colors.transparent,
              child: Text(kanji, style: AppTheme.serif(size: 36, color: WaColors.washiMuted)),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Garis tipis progres horizontal bergaya kuas.
class InkBar extends StatelessWidget {
  const InkBar({super.key, required this.value, this.color, this.height = 6});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0, 1).toDouble();
    final c = color ?? (v >= 1 ? WaColors.expense : (v >= 0.8 ? WaColors.yamabuki : WaColors.accent));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: WaColors.border),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, x, _) => FractionallySizedBox(
              widthFactor: x,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.65)]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Hanko (判子) — cap stempel saat transaksi disimpan
// -----------------------------------------------------------------------------

Future<void> showHanko(BuildContext context, {String glyph = '済', String? label}) async {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: WaColors.beni, width: 5),
                color: WaColors.beni.withValues(alpha: 0.08),
              ),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: WaColors.beni.withValues(alpha: 0.7), width: 1.5),
                ),
                child: Text(glyph, style: AppTheme.serif(size: 54, weight: FontWeight.w800, color: WaColors.beni)),
              ),
            )
                .animate()
                .scale(begin: const Offset(2.4, 2.4), end: const Offset(1, 1), duration: 260.ms, curve: Curves.easeIn)
                .rotate(begin: -0.08, end: -0.03, duration: 260.ms)
                .fadeIn(duration: 120.ms)
                .then(delay: 520.ms)
                .fadeOut(duration: 260.ms),
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(label, style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: WaColors.washi)),
              ).animate().fadeIn(delay: 200.ms).then(delay: 460.ms).fadeOut(duration: 260.ms),
          ],
        ),
      ),
    ),
  );
  overlay.insert(entry);
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  entry.remove();
}

// -----------------------------------------------------------------------------
// Pickers & dialogs
// -----------------------------------------------------------------------------

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Hapus',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: AppTheme.sans(size: 14, color: WaColors.washiMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: WaColors.expense) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in WaColors.palette)
          GestureDetector(
            onTap: () => onChanged(c.toARGB32()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: c.toARGB32() == value ? WaColors.washi : Colors.transparent, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

Future<String?> pickKanji(BuildContext context, {String? current, Color color = WaColors.accent}) {
  final custom = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text('Pilih Ikon Kanji', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: custom,
              maxLength: 2,
              decoration: InputDecoration(
                hintText: 'Atau ketik sendiri (kanji / emoji)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => custom.text.trim().isEmpty ? null : Navigator.pop(ctx, custom.text.trim()),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scroll,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 76,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: kKanjiIcons.length,
                itemBuilder: (_, i) {
                  final k = kKanjiIcons[i];
                  final selected = k.glyph == current;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(ctx, k.glyph),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? WaColors.accent : WaColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(k.glyph, style: AppTheme.serif(size: 26, color: color, weight: FontWeight.w700)),
                          Text(
                            k.meaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(size: 10, color: WaColors.washiMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> pickCurrency(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Pilih Mata Uang', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
          ),
          for (final c in kCurrencies)
            ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
              title: Text('${c.code} · ${c.symbol}'),
              subtitle: Text(c.name, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              trailing: c.code == current ? const Icon(Icons.check, color: WaColors.accent) : null,
              onTap: () => Navigator.pop(ctx, c.code),
            ),
        ],
      ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label, style: AppTheme.sans(size: 12, color: WaColors.washiMuted, weight: FontWeight.w600)),
          ),
          child,
        ],
      ),
    );
  }
}

class PickerTile extends StatelessWidget {
  const PickerTile({super.key, required this.leading, required this.title, this.subtitle, this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return WaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      radius: 14,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              ],
            ),
          ),
          const Icon(Icons.expand_more, color: WaColors.washiMuted),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
