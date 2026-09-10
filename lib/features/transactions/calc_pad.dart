import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Kalkulator nominal sederhana: angka, desimal, 000, + − × ÷.
class CalcController extends ChangeNotifier {
  CalcController({double? initial}) {
    if (initial != null && initial > 0) {
      _expr = initial == initial.roundToDouble() ? initial.toStringAsFixed(0) : initial.toString();
    }
  }

  String _expr = '';

  String get expression => _expr.replaceAll('*', '×').replaceAll('/', '÷').replaceAll('-', '−');

  bool get hasOperator => RegExp(r'[+\-*/]').hasMatch(_expr);

  double get value => _evaluate(_expr);

  static bool _isOp(String c) => '+-*/'.contains(c);

  void input(String key) {
    switch (key) {
      case 'C':
        _expr = '';
      case '⌫':
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      case '=':
        final v = value;
        _expr = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
      case '+' || '-' || '*' || '/':
        if (_expr.isEmpty) return;
        if (_isOp(_expr[_expr.length - 1])) _expr = _expr.substring(0, _expr.length - 1);
        _expr += key;
      case '.':
        final lastNum = _expr.split(RegExp(r'[+\-*/]')).last;
        if (lastNum.contains('.')) return;
        _expr += lastNum.isEmpty ? '0.' : '.';
      default:
        final lastNum = _expr.split(RegExp(r'[+\-*/]')).last;
        if (lastNum.replaceAll('.', '').length >= 13) return;
        if (lastNum == '0' && key != '000') _expr = _expr.substring(0, _expr.length - 1);
        if (lastNum.isEmpty && key == '000') return;
        _expr += key;
    }
    notifyListeners();
  }

  static double _evaluate(String expr) {
    if (expr.isEmpty) return 0;
    var e = expr;
    while (e.isNotEmpty && _isOp(e[e.length - 1])) {
      e = e.substring(0, e.length - 1);
    }
    final tokens = RegExp(r'(\d+\.?\d*|[+\-*/])').allMatches(e).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return 0;
    // Tahap 1: × dan ÷
    final stack = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      if ((t == '*' || t == '/') && stack.isNotEmpty && i + 1 < tokens.length) {
        final a = double.tryParse(stack.removeLast()) ?? 0;
        final b = double.tryParse(tokens[i + 1]) ?? 0;
        stack.add((t == '*' ? a * b : (b == 0 ? 0 : a / b)).toString());
        i += 2;
      } else {
        stack.add(t);
        i++;
      }
    }
    // Tahap 2: + dan −
    var result = double.tryParse(stack.first) ?? 0;
    for (var j = 1; j + 1 < stack.length; j += 2) {
      final b = double.tryParse(stack[j + 1]) ?? 0;
      result = stack[j] == '+' ? result + b : result - b;
    }
    return result < 0 ? 0 : double.parse(result.toStringAsFixed(8));
  }
}

class CalcPad extends StatelessWidget {
  const CalcPad({super.key, required this.controller, required this.accent, this.onDone});

  final CalcController controller;
  final Color accent;
  final VoidCallback? onDone;

  static const _rows = [
    ['7', '8', '9', '/'],
    ['4', '5', '6', '*'],
    ['1', '2', '3', '-'],
    ['000', '0', '.', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WaColors.keshizumi,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _key('C', flex: 1, color: WaColors.washiMuted),
              _key('⌫', flex: 1, color: WaColors.washiMuted),
              _key('=', flex: 1, color: accent),
              Expanded(
                child: TextButton(
                  onPressed: onDone,
                  child: const Icon(Icons.keyboard_arrow_down, color: WaColors.washiMuted),
                ),
              ),
            ],
          ),
          for (final row in _rows)
            Row(
              children: [
                for (final k in row)
                  _key(k, color: '+-*/'.contains(k) ? accent : WaColors.washi),
              ],
            ),
        ],
      ),
    );
  }

  Widget _key(String k, {int flex = 1, Color color = WaColors.washi}) {
    final label = switch (k) { '*' => '×', '/' => '÷', '-' => '−', _ => k };
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 50,
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.input(k);
          },
          child: Text(label, style: AppTheme.serif(size: k == '000' ? 18 : 24, weight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }
}
