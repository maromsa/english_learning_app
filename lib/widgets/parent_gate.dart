import 'dart:math' as math;

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Multiplication challenge used by [ParentGateDialog].
///
/// Factors are inclusive in [[minFactor], [maxFactor]] so the question is
/// easy for an adult and awkward for a pre-reader.
class ParentGateMath {
  static const int minFactor = 5;
  static const int maxFactor = 12;

  /// Two random factors in [[minFactor], [maxFactor]].
  static (int, int) generateFactors(math.Random random) {
    const span = maxFactor - minFactor + 1;
    return (
      minFactor + random.nextInt(span),
      minFactor + random.nextInt(span),
    );
  }
}

/// Math gate so young learners cannot open the parent dashboard.
///
/// A correct answer pops `true`. A wrong answer clears the field, shows a
/// subtle error, and stays open. Cancel pops `false`.
class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({
    super.key,
    this.random,
    this.factorA,
    this.factorB,
  });

  final math.Random? random;

  /// Optional fixed factors (used in tests).
  final int? factorA;
  final int? factorB;

  static const Key dialogKey = ValueKey<String>('parent_gate_dialog');
  static const Key answerFieldKey = ValueKey<String>('parent_gate_answer');

  /// Returns `true` when the adult answered correctly.
  static Future<bool> show(BuildContext context) {
    if (kIsWeb) {
      return showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        // Barrier is drawn inside [_ParentGateDialogShell] under [PointerInterceptor].
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ParentGateDialogShell(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: const ParentGateDialog(),
            ),
          );
        },
      ).then((value) => value ?? false);
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParentGateDialog(),
    ).then((value) => value ?? false);
  }

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

/// Full-screen shell so the modal barrier and dialog sit above the 3D map iframe.
class _ParentGateDialogShell extends StatelessWidget {
  const _ParentGateDialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(
              dismissible: false,
              color: Colors.black54,
            ),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  late final int _factorA;
  late final int _factorB;
  late final int _correctAnswer;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.factorA != null && widget.factorB != null) {
      _factorA = widget.factorA!;
      _factorB = widget.factorB!;
    } else {
      final pair = ParentGateMath.generateFactors(
        widget.random ?? math.Random(),
      );
      _factorA = pair.$1;
      _factorB = pair.$2;
    }
    _correctAnswer = _factorA * _factorB;

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _stealFocusFromPlatformView());
    if (kIsWeb) {
      Future<void>.delayed(
        const Duration(milliseconds: 80),
        _stealFocusFromPlatformView,
      );
    }
  }

  void _stealFocusFromPlatformView() {
    if (!mounted) return;
    _answerFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocusNode.dispose();
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
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialog = AlertDialog(
      key: ParentGateDialog.dialogKey,
      title: const Text(SparkStrings.parentGateTitle),
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
            key: ParentGateDialog.answerFieldKey,
            controller: _answerController,
            focusNode: _answerFocusNode,
            autofocus: true,
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
          child: const Text(SparkStrings.parentGateCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(SparkStrings.parentGateContinue),
        ),
      ],
    );

    if (kIsWeb) {
      return PointerInterceptor(child: dialog);
    }
    return dialog;
  }
}
