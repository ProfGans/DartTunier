import 'package:flutter/widgets.dart';
import '../application/devices_controller.dart';

class DevicesScope extends InheritedNotifier<DevicesController> {
  const DevicesScope({
    super.key,
    required DevicesController controller,
    required super.child,
  }) : super(notifier: controller);
  static DevicesController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevicesScope>()!.notifier!;
  static DevicesController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevicesScope>()?.notifier;
}
