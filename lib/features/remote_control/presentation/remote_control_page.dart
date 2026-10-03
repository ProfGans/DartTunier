import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import '../application/remote_client_controller.dart';
import '../application/remote_host_controller.dart';
import 'remote_host_surface.dart';
import '../domain/remote_pairing_code.dart';
import 'remote_pairing_scanner.dart';
import '../domain/account_remote_device.dart';
import '../data/remote_account_repository.dart';
import '../../devices/presentation/devices_scope.dart';

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({
    super.key,
    this.address = '',
    this.controller,
    this.accountDevice,
    this.accountRepository,
  });
  final String address;
  final RemoteClientController? controller;
  final AccountRemoteDevice? accountDevice;
  final RemoteAccountRepository? accountRepository;
  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  late final _client = widget.controller ?? RemoteClientController();
  late final _address = TextEditingController(text: widget.address);
  final _key = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _transform = TransformationController();
  bool _zoom = false;
  final _pointers = <int, int>{};
  RemoteAccountRepository? _accountRepository;
  StreamSubscription<String?>? _accountSubscription;
  bool _lookup = false, _restoreHost = false, _initialized = false;
  int _lookupGeneration = 0;
  String? _accountError, _connectionOwner;
  RemoteHostController? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _host = context
        .getInheritedWidgetOfExactType<RemoteHostScope>()
        ?.controller;
    _accountRepository = widget.accountRepository ?? _host?.accountRepository;
    if (widget.accountDevice != null) {
      _accountSubscription = _accountRepository?.accountChanges?.listen((
        owner,
      ) {
        if (_connectionOwner != null && owner != _connectionOwner) {
          _lookupGeneration++;
          unawaited(_client.disconnect());
          if (mounted) {
            setState(() {
              _lookup = false;
              _accountError =
                  'Account wurde gewechselt. Bitte erneut verbinden.';
            });
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connectAccount();
      });
    }
  }

  @override
  void dispose() {
    _lookupGeneration++;
    unawaited(_accountSubscription?.cancel() ?? Future.value());
    if (_restoreHost && _host?.rememberEnabled == true) {
      unawaited(_host!.start());
    }
    if (widget.controller == null) _client.dispose();
    _address.dispose();
    _key.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _prepareConnection() async {
    if (_host?.enabled == true || _host?.starting == true) {
      _restoreHost = true;
      await _host!.stop();
    }
  }

  Future<void> _connectAccount() async {
    final repository = _accountRepository;
    final target = widget.accountDevice;
    if (repository == null || target == null || _lookup || _client.connecting) {
      return;
    }
    final generation = ++_lookupGeneration;
    _connectionOwner = repository.userId;
    setState(() {
      _lookup = true;
      _accountError = null;
    });
    try {
      if (_connectionOwner == null) throw StateError('Anmeldung');
      final device = await repository.find(target.device.id);
      if (!mounted ||
          generation != _lookupGeneration ||
          repository.userId != _connectionOwner) {
        return;
      }
      await _prepareConnection();
      if (!mounted || generation != _lookupGeneration) return;
      _pointers.clear();
      _zoom = false;
      _transform.value = Matrix4.identity();
      final devices = context
          .getInheritedWidgetOfExactType<DevicesScope>()
          ?.notifier;
      final discovered = devices?.discovery.peers
          .where((peer) => peer.device.id == device.device.id)
          .firstOrNull;
      final addresses = {
        if (discovered != null) discovered.address,
        ...device.addresses,
      }.toList();
      unawaited(
        _runAccountConnections(
          device,
          addresses,
          generation,
          devices?.settings?.self.name ?? 'Mein Gerät',
        ),
      );
    } catch (_) {
      if (mounted && generation == _lookupGeneration) {
        _accountError =
            'Account-Verbindung fehlgeschlagen. Gemeinsamen Account, Freigabe und Servereinrichtung prüfen.';
      }
    } finally {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _lookup = false);
      }
    }
  }

  Future<void> _runAccountConnections(
    AccountRemoteDevice device,
    List<String> addresses,
    int generation,
    String name,
  ) async {
    for (final address in addresses) {
      if (!mounted || generation != _lookupGeneration) return;
      var reachedHost = false;
      void changed() {
        reachedHost |= _client.connected || _client.awaitingConfirmation;
      }

      _client.addListener(changed);
      try {
        await _client.connect(address, device.key, mode: 'account', name: name);
      } finally {
        _client.removeListener(changed);
      }
      if (reachedHost) return;
    }
  }

  Future<void> _cancelConnection() async {
    _lookupGeneration++;
    setState(() => _lookup = false);
    await _client.disconnect();
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    await _prepareConnection();
    if (!mounted) return;
    _transform.value = Matrix4.identity();
    _pointers.clear();
    setState(() => _zoom = false);
    unawaited(_client.connect(_address.text.trim(), _key.text.trim()));
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<RemotePairingCode>(
      MaterialPageRoute(builder: (_) => const RemotePairingScanner()),
    );
    if (code == null || !mounted) return;
    _address.text = code.address;
    _key.text = code.key;
    _connect();
  }

  void _send(String type, [Map<String, dynamic> values = const {}]) {
    unawaited(
      _client.send({'type': type, 'viewport': _client.viewport, ...values}),
    );
  }

  Future<void> _text() async {
    final editor = _client.editor;
    final viewport = _client.viewport;
    final input = TextEditingController(text: _client.editingText ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text am Hauptgerät eingeben'),
        content: SingleChildScrollView(
          child: TextField(
            controller: input,
            autofocus: true,
            obscureText: _client.obscureText,
            maxLength: 10000,
            onSubmitted: (text) => Navigator.pop(context, text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      unawaited(
        _client.send({
          'type': 'text',
          'viewport': viewport,
          'editor': editor,
          'text': result,
        }),
      );
    }
    // The dialog finishes its closing animation before releasing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Widget _screen() => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = _client.width / _client.height;
      var w = constraints.maxWidth;
      var h = w / ratio;
      if (h > constraints.maxHeight) {
        h = constraints.maxHeight;
        w = h * ratio;
      }
      final screen = SizedBox(
        width: w,
        height: h,
        child: Listener(
          onPointerDown: _zoom
              ? null
              : (event) {
                  final id = List.generate(10, (i) => i).firstWhere(
                    (i) => !_pointers.containsValue(i),
                    orElse: () => -1,
                  );
                  if (id < 0) return;
                  _pointers[event.pointer] = id;
                  _send('down', {
                    'pointer': id,
                    'x': event.localPosition.dx / w,
                    'y': event.localPosition.dy / h,
                  });
                },
          onPointerMove: _zoom
              ? null
              : (event) {
                  final id = _pointers[event.pointer];
                  if (id == null) return;
                  _send('move', {
                    'pointer': id,
                    'x': (event.localPosition.dx / w).clamp(0, 1),
                    'y': (event.localPosition.dy / h).clamp(0, 1),
                  });
                },
          onPointerUp: (event) {
            final id = _pointers.remove(event.pointer);
            if (id == null) return;
            _send('up', {
              'pointer': id,
              'x': (event.localPosition.dx / w).clamp(0, 1),
              'y': (event.localPosition.dy / h).clamp(0, 1),
            });
          },
          onPointerCancel: (_) {
            _pointers.clear();
            _send('cancel');
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && !_zoom) {
              _send('scroll', {
                'pointer': 0,
                'x': event.localPosition.dx / w,
                'y': event.localPosition.dy / h,
                'dy': event.scrollDelta.dy,
              });
            }
          },
          child: Image.memory(
            _client.image!,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            excludeFromSemantics: false,
            semanticLabel: 'Live-Oberfläche des Hauptgeräts',
          ),
        ),
      );
      return ClipRect(
        child: InteractiveViewer(
          transformationController: _transform,
          panEnabled: _zoom,
          scaleEnabled: _zoom,
          maxScale: 5,
          child: Center(child: screen),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _client,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Fernsteuerung')),
      body: !_client.connected
          ? AdaptiveContentList(
              children: [
                if (widget.accountDevice != null) ...[
                  Text(
                    'Mit ${widget.accountDevice!.device.name} über deinen Account verbinden.',
                  ),
                  const Text(
                    'Auf beiden Geräten muss derselbe Account angemeldet sein. Ein Kopplungscode ist nicht erforderlich.',
                  ),
                  FilledButton(
                    onPressed: _lookup || _client.connecting
                        ? null
                        : _connectAccount,
                    child: const Text('Mit meinem Account verbinden'),
                  ),
                  if (_lookup) const LinearProgressIndicator(),
                  if (_accountError != null) Text(_accountError!),
                  if (_lookup)
                    TextButton(
                      onPressed: _cancelConnection,
                      child: const Text('Abbrechen'),
                    ),
                  const SizedBox(height: 24),
                  const Text('Alternativ mit Kopplungscode verbinden'),
                ],
                const Text(
                  'Beide Geräte müssen im selben WLAN sein. Am Hauptgerät unter Geräte die Fernsteuerung freigeben und den angezeigten Code hier eingeben.',
                ),
                const SizedBox(height: 16),
                if (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.linux ||
                    defaultTargetPlatform == TargetPlatform.windows)
                  OutlinedButton.icon(
                    onPressed: _client.connecting ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR-Code scannen'),
                  ),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'IP-Adresse des Hauptgeräts',
                        ),
                        enabled: !_client.connecting,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Adresse eingeben'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _key,
                        decoration: const InputDecoration(
                          labelText: 'Kopplungscode',
                        ),
                        enabled: !_client.connecting,
                        obscureText: true,
                        autocorrect: false,
                        validator: (value) =>
                            !RegExp(
                              r'^[a-f0-9]{64}$',
                            ).hasMatch(value?.trim() ?? '')
                            ? 'Den vollständigen Kopplungscode eingeben'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _client.connecting ? null : _connect,
                  icon: const Icon(Icons.phonelink),
                  label: const Text('Verbinden'),
                ),
                if (_client.connecting) ...[
                  const LinearProgressIndicator(),
                  if (_client.awaitingConfirmation)
                    const Text('Warte auf Bestätigung am Hauptgerät …'),
                  TextButton(
                    onPressed: _cancelConnection,
                    child: const Text('Abbrechen'),
                  ),
                ],
                if (_client.error != null) Text(_client.error!),
              ],
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * .35,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _send('back'),
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('Zurück am Hauptgerät'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _client.editingText == null
                                        ? null
                                        : _text,
                                    icon: const Icon(Icons.keyboard),
                                    label: const Text('Text eingeben'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _send('submit', {
                                      'editor': _client.editor,
                                    }),
                                    child: const Text('Eingabe bestätigen'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _send('cancel');
                                      _pointers.clear();
                                      setState(() => _zoom = !_zoom);
                                    },
                                    icon: Icon(
                                      _zoom ? Icons.touch_app : Icons.zoom_in,
                                    ),
                                    label: Text(
                                      _zoom ? 'Bedienen' : 'Zoom / Verschieben',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _client.disconnect,
                                    child: const Text('Trennen'),
                                  ),
                                ],
                              ),
                              if (_zoom)
                                const Text(
                                  'Ansicht vergrößern oder verschieben, danach „Bedienen“ wählen.',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _client.image == null
                          ? const Center(child: CircularProgressIndicator())
                          : _screen(),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
