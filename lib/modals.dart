import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

const Curve curve = Curves.easeInOut;
const Duration duration = Duration(milliseconds: 300);

class Modals{
  static Future<T?> showCupertinoModal<T>({
    required BuildContext context,
    required Widget builder,
    bool isDraggable = true,
    bool isDismissible = true,
  }) async {
    final result = await showCupertinoModalBottomSheet<T>(
      context: context,
      enableDrag: isDraggable,
      isDismissible: isDismissible,
      builder: (_) => builder,
      useRootNavigator: false,
      animationCurve: curve,
      duration: duration,
    );
    return result;
  }
}