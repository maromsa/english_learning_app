import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SparkOverlayController', () {
    test('begin/end suppress toggles isVisible', () {
      final c = SparkOverlayController();
      expect(c.isVisible, isTrue);

      c.beginSparkOverlaySuppress();
      expect(c.isVisible, isFalse);

      c.endSparkOverlaySuppress();
      expect(c.isVisible, isTrue);
    });

    test('nested suppress only shows after outer ends', () {
      final c = SparkOverlayController();
      c.beginSparkOverlaySuppress();
      c.beginSparkOverlaySuppress();
      expect(c.isVisible, isFalse);

      c.endSparkOverlaySuppress();
      expect(c.isVisible, isFalse);

      c.endSparkOverlaySuppress();
      expect(c.isVisible, isTrue);
    });

    test('endSparkOverlaySuppress is safe when depth is zero', () {
      final c = SparkOverlayController();
      c.endSparkOverlaySuppress();
      expect(c.isVisible, isTrue);
    });

    test('hide and suppress combine', () {
      final c = SparkOverlayController();
      c.hide();
      expect(c.isVisible, isFalse);

      c.beginSparkOverlaySuppress();
      expect(c.isVisible, isFalse);

      c.endSparkOverlaySuppress();
      expect(c.isVisible, isFalse);

      c.show();
      expect(c.isVisible, isTrue);
    });
  });
}
