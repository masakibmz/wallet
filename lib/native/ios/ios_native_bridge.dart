import 'dart:io';

import 'package:flutter/services.dart';

/// Single entry for iOS native capabilities (haptics, biometrics, glass, etc.).
class IosNativeBridge {
  IosNativeBridge._();

  static final IosNativeBridge instance = IosNativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.wallet/ios_native');

  bool get isAvailable => Platform.isIOS;

  Future<void> hapticLight() async {
    if (!isAvailable) {
      return;
    }
    await _channel.invokeMethod<void>('hapticLight');
  }

  Future<void> hapticSelection() async {
    if (!isAvailable) {
      return;
    }
    await _channel.invokeMethod<void>('hapticSelection');
  }

  Future<bool> authenticateWithBiometrics({String? reason}) async {
    if (!isAvailable) {
      return false;
    }
    final result = await _channel.invokeMethod<bool>(
      'authenticateWithBiometrics',
      {'reason': reason ?? '验证身份以继续'},
    );
    return result ?? false;
  }

  Future<bool> isLiquidGlassSupported() async {
    if (!isAvailable) {
      return false;
    }
    final result = await _channel.invokeMethod<bool>('isLiquidGlassSupported');
    return result ?? false;
  }
}
