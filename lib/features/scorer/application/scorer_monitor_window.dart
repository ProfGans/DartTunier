import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'scorer_controller.dart';
import '../domain/scorer_monitor_format.dart';

/// Read-only loopback display. No commands, account data or LAN access.
class ScorerMonitorWindow {
  HttpServer? _server;
  bool _closed = false;
  final String _token = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<Uri> start(ScorerController controller) async {
    if (_closed) throw StateError('Anzeige geschlossen');
    if (_server == null) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (_closed) {
        await server.close(force: true);
        throw StateError('Anzeige geschlossen');
      }
      _server = server;
      server.listen((request) async {
        request.response.headers.set(
          HttpHeaders.cacheControlHeader,
          'no-store',
        );
        request.response.headers.set('X-Content-Type-Options', 'nosniff');
        if (request.method != 'GET' ||
            !['/$_token/', '/$_token/state'].contains(request.uri.path)) {
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.uri.path.endsWith('/state')) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'format': scorerMonitorFormat(controller.settings),
              'players': [
                for (var i = 0; i < controller.scores.length; i++)
                  {
                    'name': controller.settings.participants[i].name,
                    'legs': controller.legs[i],
                    'sets': controller.sets[i],
                    'score':
                        i == controller.activePlayer && !controller.isComplete
                        ? controller.remaining
                        : controller.scores[i],
                    'active':
                        i == controller.activePlayer && !controller.isComplete,
                  },
              ],
            }),
          );
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_html);
        }
        await request.response.close();
      });
    }
    return Uri.parse('http://127.0.0.1:${_server!.port}/$_token/');
  }

  Future<void> open(ScorerController controller) async {
    final uri = await start(controller);
    // App mode provides a separate movable window, without browser tabs.
    if (Platform.isWindows) {
      for (final root in [
        Platform.environment['ProgramFiles(x86)'],
        Platform.environment['ProgramFiles'],
        Platform.environment['LOCALAPPDATA'],
      ]) {
        if (root == null) continue;
        final executable = File('$root/Microsoft/Edge/Application/msedge.exe');
        if (await executable.exists()) {
          await Process.start(executable.path, [
            '--app=$uri',
            '--new-window',
          ], mode: ProcessStartMode.detached);
          return;
        }
      }
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Anzeigefenster konnte nicht geöffnet werden.');
    }
  }

  Future<void> close() async {
    _closed = true;
    await _server?.close(force: true);
    _server = null;
  }
}

const _html = '''<!doctype html><html lang="de"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dart · Punkteanzeige</title><style>
*{box-sizing:border-box}body{margin:0;background:#101a22;color:white;font-family:system-ui,sans-serif}
header{text-align:center;padding:24px 100px 0 24px;font-size:clamp(18px,2vw,30px)}.totals{font-size:clamp(24px,3vw,48px)}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,400px),1fr));gap:20px;min-height:85vh}
article{display:flex;flex-direction:column;justify-content:center;text-align:center;padding:24px;background:#192b35;border:4px solid transparent;border-radius:24px}
article.active{border-color:#70e0ba}h2{font-size:clamp(24px,4vw,56px);margin:0;overflow-wrap:anywhere;font-weight:500}
strong{font-size:clamp(64px,15vw,220px);color:#70e0ba}button{position:fixed;right:16px;top:12px;min-height:48px;padding:12px;border:0;border-radius:8px;cursor:pointer}
button.hidden{opacity:0;pointer-events:none}button:focus{opacity:1}#status{position:fixed;bottom:0;background:#101a22;width:100%;text-align:center}
</style><header id="format"></header><main></main><button id="full">Vollbild</button><div id="status" role="status"></div>
<script>
const main=document.querySelector('main'),status=document.querySelector('#status'),full=document.querySelector('#full');
let last='',hide;
full.onclick=async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}catch(e){status.textContent='Vollbild über F11 aktivieren';}};
document.onfullscreenchange=()=>{full.textContent=document.fullscreenElement?'Vollbild verlassen':'Vollbild';};
function controls(){full.classList.remove('hidden');clearTimeout(hide);hide=setTimeout(()=>full.classList.add('hidden'),2500);}
document.onpointermove=controls;document.onkeydown=controls;controls();
async function update(){try{const r=await fetch('state',{cache:'no-store'});if(!r.ok)throw Error();const data=await r.json();const encoded=JSON.stringify(data);
if(encoded!==last){document.querySelector('#format').textContent=data.format;main.replaceChildren();for(const p of data.players){const card=document.createElement('article');card.className=p.active?'active':'';const name=document.createElement('h2');name.textContent=p.name;const score=document.createElement('strong');score.textContent=p.score;const totals=document.createElement('div');totals.className='totals';totals.textContent=p.legs+' Legs · '+p.sets+' Sätze';card.append(name,score,totals);main.append(card);}last=encoded;}status.textContent='';
}catch(e){status.textContent='Verbindung zum Scorer unterbrochen · angezeigter Stand ist nicht live';}setTimeout(update,250);}update();
</script></html>''';
