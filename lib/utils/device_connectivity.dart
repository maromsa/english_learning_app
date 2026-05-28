import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Lightweight connectivity probe without extra packages.
abstract class DeviceConnectivity {
  const DeviceConnectivity();

  Future<bool> isOnline({Duration timeout = const Duration(seconds: 3)});

  static DeviceConnectivity get instance => _DefaultDeviceConnectivity();

  @visibleForTesting
  static DeviceConnectivity? testOverride;

  static DeviceConnectivity get current =>
      testOverride ?? instance;
}

class _DefaultDeviceConnectivity extends DeviceConnectivity {
  @override
  Future<bool> isOnline({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
