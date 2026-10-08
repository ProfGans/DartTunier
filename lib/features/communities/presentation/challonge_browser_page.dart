import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html;
import 'package:path_provider/path_provider.dart';
import '../data/challonge_public_reader.dart';

/// Uses the ordinary browser engine. Any site challenge stays user-operated.
class ChallongeBrowserPage extends StatefulWidget {
  const ChallongeBrowserPage({super.key, required this.uri});
  final Uri uri;
  @override
  State<ChallongeBrowserPage> createState() => _ChallongeBrowserPageState();
}

class _ChallongeBrowserPageState extends State<ChallongeBrowserPage> {
  static Future<WebViewEnvironment?>? _windowsEnvironment;
  // WebView2 can still deliver native callbacks after a route is removed.
  // Keep one browser alive across the sequential bracket/standings reads.
  static final _windowsBrowser = InAppWebViewKeepAlive();
  late final Future<WebViewEnvironment?> _environment = _prepareEnvironment();
  Future<WebViewEnvironment?> _prepareEnvironment() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;
    return _windowsEnvironment ??= () async {
      final folder = await getApplicationSupportDirectory();
      return WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '${folder.path}/challonge_browser',
        ),
      );
    }();
  }

  InAppWebViewController? _controller;
  String? _error;
  bool _reading = false;
  bool _completed = false;
  bool _ready = false;
  Future<void> _read({bool automatic = false}) async {
    if (automatic && widget.uri.pathSegments.contains('communities')) return;
    if (!mounted || !_ready || _completed || _reading || _controller == null) {
      return;
    }
    _reading = true;
    try {
      final source = await _controller!.evaluateJavascript(
        source: 'document.documentElement.outerHTML',
      );
      if (source is String &&
          (source.contains("['TournamentStore']") ||
              source.contains('["TournamentStore"]') ||
              html.parse(source).querySelector('table.standings tbody tr') !=
                  null ||
              (!automatic &&
                  widget.uri.pathSegments.contains('communities')))) {
        if (mounted && !_completed) {
          _completed = true;
          await _controller!.stopLoading();
          if (mounted) Navigator.pop(context, source);
        }
      } else if (!automatic && mounted) {
        setState(
          () => _error =
              'Die Turnierdaten sind noch nicht sichtbar. Bitte die Seite vollständig laden lassen und gegebenenfalls die Browserprüfung selbst abschließen.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Die Browserseite konnte nicht gelesen werden.',
        );
      }
    } finally {
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Öffentlicher Challonge-Import')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .4,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.uri.toString()),
                      const Text(
                        'Die öffentliche Seite wird im Browser geladen. Eine eventuell angezeigte Browserprüfung bitte selbst abschließen.',
                      ),
                      if (widget.uri.pathSegments.contains('communities'))
                        const Text(
                          'Für alte Turniere PAST auswählen. Danach „Seite erneut prüfen“ drücken. Bei mehreren Seiten die gewünschten Turnierlinks einzeln übernehmen.',
                        ),
                      if (_error != null) Text(_error!),
                      TextButton(
                        onPressed: () => _read(),
                        child: const Text('Seite erneut prüfen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<WebViewEnvironment?>(
                future: _environment,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Der Browser konnte nicht gestartet werden. Unter Windows wird Microsoft Edge WebView2 benötigt.',
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return InAppWebView(
                    keepAlive:
                        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
                        ? _windowsBrowser
                        : null,
                    webViewEnvironment: snapshot.data,
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                    ),
                    onWebViewCreated: (controller) async {
                      if (!mounted || _completed) return;
                      _controller = controller;
                      // A kept-alive browser ignores initialUrlRequest on reuse.
                      _ready = true;
                      try {
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri.uri(widget.uri)),
                        );
                      } catch (_) {
                        _ready = false;
                        if (mounted) {
                          setState(() => _error =
                              'Die Browserseite konnte nicht geladen werden.');
                        }
                      }
                    },
                    onLoadStop: (controller, url) {
                      if (url?.host == widget.uri.host &&
                          url?.path == widget.uri.path) {
                        _read(automatic: true);
                      }
                    },
                    shouldOverrideUrlLoading: (controller, action) async {
                      if (action.isForMainFrame != true) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      try {
                        ChallongePublicReader.validateUrl(
                          action.request.url.toString(),
                        );
                        return NavigationActionPolicy.ALLOW;
                      } on FormatException {
                        return NavigationActionPolicy.CANCEL;
                      }
                    },
                    onPermissionRequest: (controller, request) async =>
                        PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.DENY,
                        ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
