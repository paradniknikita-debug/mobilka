import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Поле марки с выпадающим списком: открывается явно (tap/ввод), закрывается по tap снаружи.
class FilterableMarkField extends StatefulWidget {
  const FilterableMarkField({
    super.key,
    required this.controller,
    required this.options,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.helperText,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final List<String> options;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final Widget? prefixIcon;

  @override
  State<FilterableMarkField> createState() => _FilterableMarkFieldState();
}

class _FilterableMarkFieldState extends State<FilterableMarkField> {
  FocusNode? _focusNode;
  bool _showOptions = false;
  bool _focusListenerAttached = false;

  Iterable<String> _filteredOptions(TextEditingValue textEditingValue) {
    if (!_showOptions) {
      return const Iterable<String>.empty();
    }
    final q = textEditingValue.text.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.options;
    }
    return widget.options.where((s) => s.toLowerCase().contains(q));
  }

  void _attachFocusListener(FocusNode node) {
    if (_focusListenerAttached) {
      return;
    }
    _focusNode = node;
    _focusListenerAttached = true;
    node.addListener(() {
      if (!node.hasFocus && mounted) {
        setState(() => _showOptions = false);
      }
    });
  }

  void _selectOption(String value) {
    widget.controller.text = value;
    widget.onChanged(value);
    setState(() => _showOptions = false);
    _focusNode?.unfocus();
  }

  void _toggleOptions(FocusNode focusNode) {
    setState(() {
      _showOptions = !_showOptions;
    });
    if (_showOptions) {
      focusNode.requestFocus();
    } else {
      focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      key: ValueKey('mark-${widget.labelText}'),
      optionsBuilder: _filteredOptions,
      displayStringForOption: (o) => o,
      onSelected: _selectOption,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        _attachFocusListener(focusNode);

        if (textEditingController.text != widget.controller.text && !focusNode.hasFocus) {
          textEditingController.text = widget.controller.text;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (v) => onFieldSubmitted(),
          onTap: () => setState(() => _showOptions = true),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText ?? 'Нажмите стрелку или начните ввод',
            helperMaxLines: 2,
            helperStyle: widget.helperText != null
                ? const TextStyle(fontSize: 11, color: PatrolColors.textSecondary)
                : null,
            prefixIcon: widget.prefixIcon,
            filled: true,
            fillColor: PatrolColors.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              tooltip: _showOptions ? 'Скрыть список' : 'Показать список',
              icon: Icon(
                _showOptions ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: PatrolColors.textSecondary,
              ),
              onPressed: () => _toggleOptions(focusNode),
            ),
          ),
          style: const TextStyle(color: PatrolColors.textPrimary),
          onChanged: (v) {
            widget.controller.text = v;
            widget.onChanged(v);
            if (!_showOptions) {
              setState(() => _showOptions = true);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, optionItems) {
        if (optionItems.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: PatrolColors.surfaceCard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionItems.length,
                itemBuilder: (context, index) {
                  final option = optionItems.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PatrolColors.textPrimary),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
