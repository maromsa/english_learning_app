import 'dart:math' as math;

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple math gate so young learners cannot open the parent dashboard.
class ParentalGateDialog extends StatefulWidget {
  const ParentalGateDialog({
    super.key,
    this.random,
    this.factorA,
    this.factorB,
  });

  final math.Random? random;

  /// Optional fixed factors (used in tests).
  final int? factorA;
  final int? factorB;

  /// Returns `true` when the adult answered correctly.
  static Future<bool> show(BuildContext context) {
    return showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ParentalGateDialog(),
        ).then((value) => value ?? false);
  }

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog> {
  late final int _factorA;
  late final int _factorB;
  late final int _correctAnswer;
  final TextEditingController _answerController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.factorA != null && widget.factorB != null) {
      _factorA = widget.factorA!;
      _factorB = widget.factorB!;
    } else {
      final random = widget.random ?? math.Random();
      _factorA = 2 + random.nextInt(8);
      _factorB = 2 + random.nextInt(8);
    }
    _correctAnswer = _factorA * _factorB;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_answerController.text.trim());
    if (parsed == _correctAnswer) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errorText = SparkStrings.parentGateWrong;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(SparkStrings.parentGateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            SparkStrings.parentGateQuestion(_factorA, _factorB),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: SparkStrings.parentGateAnswerLabel,
              errorText: _errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(SparkStrings.parentGateCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(SparkStrings.parentGateContinue),
        ),
      ],
    );
  }
}
