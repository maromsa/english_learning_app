import 'dart:math' as math;

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
    if (kIsWeb) {
      return showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        // Barrier is drawn inside [_ParentalGateDialogShell] under [PointerInterceptor].
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ParentalGateDialogShell(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: const ParentalGateDialog(),
            ),
          );
        },
      ).then((value) => value ?? false);
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParentalGateDialog(),
    ).then((value) => value ?? false);
  }

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

/// Full-screen shell so the modal barrier and dialog sit above the 3D map iframe.
class _ParentalGateDialogShell extends StatelessWidget {
  const _ParentalGateDialogShell({required this.child});

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

class _ParentalGateDialogState extends State<ParentalGateDialog> {
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
      final random = widget.random ?? math.Random();
      _factorA = 2 + random.nextInt(8);
      _factorB = 2 + random.nextInt(8);
    }
    _correctAnswer = _factorA * _factorB;

    WidgetsBinding.instance.addPostFrameCallback((_) => _stealFocusFromPlatformView());
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialog = AlertDialog(
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
