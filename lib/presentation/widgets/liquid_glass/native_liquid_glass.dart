import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';

/// Embeds UIKit-native material (Liquid Glass / system blur) on iOS.
class NativeLiquidGlass extends StatelessWidget {
  const NativeLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.style = LiquidGlassStyle.regular,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final LiquidGlassStyle style;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: UiKitView(
              viewType: 'com.wallet/liquid_glass',
              creationParams: {
                'borderRadius': borderRadius,
                'style': style.name,
              },
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

enum LiquidGlassStyle {
  regular,
  thick,
  thin,
}

Future<bool> liquidGlassSupported() =>
    IosNativeBridge.instance.isLiquidGlassSupported();
