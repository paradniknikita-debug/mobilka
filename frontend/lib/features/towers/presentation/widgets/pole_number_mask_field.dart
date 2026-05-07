import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pole_number_mask.dart';

/// Редактор маски номера опоры под подписью «Название опоры *» (как одно поле с рамкой).
/// Структура: [цифры][буква] / [цифры][буква] / [цифры]
class PoleNumberMaskField extends StatefulWidget {
  final PoleNumberMask initial;
  final ValueChanged<PoleNumberMask> onChanged;
  final PoleNumberMask? suggestion;
  final VoidCallback? onApplySuggestion;

  const PoleNumberMaskField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.suggestion,
    this.onApplySuggestion,
  });

  @override
  State<PoleNumberMaskField> createState() => _PoleNumberMaskFieldState();
}

class _PoleNumberMaskFieldState extends State<PoleNumberMaskField> {
  late final TextEditingController _cMain;
  late final TextEditingController _cL1;
  late final TextEditingController _cMid;
  late final TextEditingController _cL2;
  late final TextEditingController _cTail;

  /// Не вызывать [widget.onChanged] при программной подстановке текста (избегаем setState во время build).
  bool _suppressEmit = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _cMain = TextEditingController(text: m.mainDigits);
    _cL1 = TextEditingController(text: m.letterAfterMain);
    _cMid = TextEditingController(text: m.midDigits);
    _cL2 = TextEditingController(text: m.letterAfterMid);
    _cTail = TextEditingController(text: m.tailDigits);
    for (final c in [_cMain, _cL1, _cMid, _cL2, _cTail]) {
      c.addListener(_emit);
    }
  }

  void _emit() {
    if (_suppressEmit || !mounted) return;
    final mask = _currentMask();
    // Уведомление родителя после завершения кадра — иначе onChanged → setState во время build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _suppressEmit) return;
      widget.onChanged(mask);
    });
  }

  PoleNumberMask _currentMask() {
    return PoleNumberMask(
      mainDigits: _cMain.text,
      letterAfterMain: _cL1.text,
      midDigits: _cMid.text,
      letterAfterMid: _cL2.text,
      tailDigits: _cTail.text,
    );
  }

  @override
  void didUpdateWidget(covariant PoleNumberMaskField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldApi = oldWidget.initial.apiString;
    final newApi = widget.initial.apiString;
    final currentApi = _currentMask().apiString;
    // Не перезаписываем ввод пользователя на каждом onChanged/setState родителя.
    // Обновляем контроллеры только при внешнем изменении initial.
    if (oldApi != newApi && currentApi != newApi) {
      _suppressEmit = true;
      try {
        final m = widget.initial;
        _cMain.text = m.mainDigits;
        _cL1.text = m.letterAfterMain;
        _cMid.text = m.midDigits;
        _cL2.text = m.letterAfterMid;
        _cTail.text = m.tailDigits;
      } finally {
        _suppressEmit = false;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_cMain, _cL1, _cMid, _cL2, _cTail]) {
      c.removeListener(_emit);
      c.dispose();
    }
    super.dispose();
  }

  static const _digitBoxWidth = 68.0;
  static const _letterBoxWidth = 40.0;
  static const _cellRadius = 10.0;

  static InputDecoration _cellDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      border: InputBorder.none,
      filled: false,
      hintText: hint,
      hintStyle: TextStyle(
        color: PatrolColors.textSecondary.withValues(alpha: 0.45),
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      counterText: '',
    );
  }

  static Widget _cell({
    required Widget child,
    double width = _digitBoxWidth,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF1A212E),
        borderRadius: BorderRadius.circular(_cellRadius),
        border: Border.all(
          color: PatrolColors.textSecondary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final digitFmt = <TextInputFormatter>[PoleDigitsFormatter()];
    final letterFmt = <TextInputFormatter>[PoleSingleLetterFormatter()];

    final borderColor = PatrolColors.textSecondary.withValues(alpha: 0.35);
    const focusBlue = PatrolColors.accentBlue;

    Widget digitBox(TextEditingController c) {
      return _cell(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: digitFmt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PatrolColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          cursorColor: focusBlue,
          decoration: _cellDecoration(),
        ),
      );
    }

    Widget letterBox(TextEditingController c) {
      return _cell(
        width: _letterBoxWidth,
        child: TextField(
          controller: c,
          inputFormatters: letterFmt,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            color: PatrolColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          cursorColor: focusBlue,
          decoration: _cellDecoration(hint: '·'),
        ),
      );
    }

    final maskRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          digitBox(_cMain),
          const SizedBox(width: 8),
          letterBox(_cL1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: PatrolColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
          digitBox(_cMid),
          const SizedBox(width: 8),
          letterBox(_cL2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: PatrolColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
          digitBox(_cTail),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Название опоры *',
            labelStyle: const TextStyle(
              color: PatrolColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: const TextStyle(
              color: PatrolColors.textSecondary,
              fontSize: 14,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            filled: true,
            fillColor: PatrolColors.surfaceCard,
            contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            isDense: false,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: focusBlue, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: maskRow,
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: Listenable.merge([_cMain, _cL1, _cMid, _cL2, _cTail]),
          builder: (context, _) {
            final m = _currentMask();
            return Text(
              m.apiString.isEmpty
                  ? 'Итог: Опора …'
                  : 'Итог: ${m.displayTitle}',
              style: TextStyle(
                fontSize: 12,
                color: PatrolColors.textSecondary.withValues(alpha: 0.95),
              ),
            );
          },
        ),
        if (widget.suggestion != null && widget.suggestion!.isValidForSave) ...[
          const SizedBox(height: 8),
          Material(
            color: PatrolColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.onApplySuggestion,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: PatrolColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Подсказка: ${widget.suggestion!.displayTitle}',
                        style: const TextStyle(fontSize: 13, color: PatrolColors.textPrimary),
                      ),
                    ),
                    const Text(
                      'Применить',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PatrolColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
