import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../application/remote_host_controller.dart';
import 'remote_confirmation_view.dart';

class RemoteHostScope extends InheritedWidget {
  const RemoteHostScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final RemoteHostController controller;
  static RemoteHostController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemoteHostScope>()!.controller;
  @override
  bool updateShouldNotify(RemoteHostScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Captures the entire Flutter navigator, including dialogs and overlays.
class RemoteHostSurface extends StatefulWidget {
  const RemoteHostSurface({
    super.key,
    required this.controller,
    required this.child,
    required this.onBack,
  });
  final RemoteHostController controller;
  final Widget child;
  final VoidCallback onBack;
  @override
  State<RemoteHostSurface> createState() => _RemoteHostSurfaceState();
}

class _RemoteHostSurfaceState extends State<RemoteHostSurface> {
  final _boundary = GlobalKey();
  final _pointers = <int, Offset>{};
  Size? _lastSize;
  int _viewport = 0;
  EditableTextState? _lastEditor;
  int _editorGeneration = 0;
  final _clock = Stopwatch()..start();
  @override
  void initState() {
    super.initState();
    widget.controller.capture = _capture;
    widget.controller.onInput = _input;
  }

  EditableTextState? get _editor {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorStateOfType<EditableTextState>();
  }

  Future<Map<String, dynamic>?> _capture() async {
    final render = _boundary.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary ||
        render.debugNeedsPaint ||
        render.size.isEmpty) {
      return null;
    }
    if (_lastSize != render.size) {
      _cancel();
      _lastSize = render.size;
      _viewport++;
    }
    final image = await render.toImage(
      pixelRatio: (1200 / render.size.width).clamp(.3, 1.5),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final editor = _editor;
      if (!identical(editor, _lastEditor)) {
        _lastEditor = editor;
        _editorGeneration++;
      }
      return {
        'type': 'frame',
        'width': render.size.width,
        'height': render.size.height,
        'viewport': _viewport,
        'image': base64Encode(bytes.buffer.asUint8List()),
        'editingText': editor?.widget.obscureText == true
            ? ''
            : editor?.widget.controller.text,
        'editor': _editorGeneration,
        'obscureText': editor?.widget.obscureText == true,
      };
    } finally {
      image.dispose();
    }
  }

  void _cancel() {
    for (final entry in _pointers.entries) {
      GestureBinding.instance.handlePointerEvent(
        PointerCancelEvent(
          pointer: entry.key,
          position: entry.value,
          timeStamp: _clock.elapsed,
        ),
      );
    }
    _pointers.clear();
  }

  void _input(Map<String, dynamic> message) {
    if (!mounted) return;
    final type = message['type'];
    if (type == 'cancel') {
      _cancel();
      return;
    }
    if (message['viewport'] != _viewport) return;
    final render = _boundary.currentContext?.findRenderObject();
    if (render is! RenderBox || render.size != _lastSize) return;
    if (type == 'text') {
      final text = message['text'];
      final editor = _editor;
      if (message['editor'] == _editorGeneration &&
          identical(editor, _lastEditor) &&
          text is String &&
          text.length <= 10000 &&
          editor != null &&
          !editor.widget.readOnly) {
        editor.userUpdateTextEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
          SelectionChangedCause.keyboard,
        );
      }
      return;
    }
    if (type == 'submit') {
      if (message['editor'] == _editorGeneration &&
          identical(_editor, _lastEditor)) {
        _editor?.performAction(TextInputAction.done);
      }
      return;
    }
    if (type == 'back') {
      widget.onBack();
      return;
    }
    final x = message['x'], y = message['y'];
    if (x is! num ||
        y is! num ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        y < 0 ||
        x > 1 ||
        y > 1) {
      return;
    }
    final position = render.localToGlobal(
      Offset(x * render.size.width, y * render.size.height),
    );
    final id = message['pointer'];
    if (id is! int || id < 0 || id > 100) return;
    final pointer = 100000 + id;
    switch (type) {
      case 'down':
        if (_pointers.containsKey(pointer) || _pointers.length >= 10) return;
        _pointers[pointer] = position;
        GestureBinding.instance.handlePointerEvent(
          PointerDownEvent(
            pointer: pointer,
            position: position,
            timeStamp: _clock.elapsed,
          ),
        );
      case 'move':
        final previous = _pointers[pointer];
        if (previous == null) return;
        _pointers[pointer] = position;
        GestureBinding.instance.handlePointerEvent(
          PointerMoveEvent(
            pointer: pointer,
            position: position,
            delta: position - previous,
            timeStamp: _clock.elapsed,
          ),
        );
      case 'up':
        if (_pointers.remove(pointer) == null) return;
        GestureBinding.instance.handlePointerEvent(
          PointerUpEvent(
            pointer: pointer,
            position: position,
            timeStamp: _clock.elapsed,
          ),
        );
      case 'scroll':
        final dy = message['dy'];
        if (dy is! num || !dy.isFinite) return;
        GestureBinding.instance.handlePointerEvent(
          PointerScrollEvent(
            position: position,
            scrollDelta: Offset(0, dy.clamp(-1000, 1000).toDouble()),
          ),
        );
    }
  }

  @override
  void dispose() {
    _cancel();
    widget.controller.capture = null;
    widget.controller.onInput = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _boundary,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Column(
        children: [
          if (widget.controller.enabled)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        widget.controller.connected
                            ? 'Fernbedienung verbunden'
                            : 'Fernsteuerung freigegeben',
                      ),
                      TextButton(
                        onPressed: () => widget.controller.setEnabled(false),
                        child: const Text('Freigabe beenden'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                widget.child,
                if (widget.controller.pendingName != null)
                  Positioned.fill(
                    child: RemoteConfirmationView(
                      controller: widget.controller,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
