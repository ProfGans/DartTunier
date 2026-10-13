import 'dart:convert';

import '../domain/tournament_models.dart';

/// Portable, versioned representations for publishing tournament data elsewhere.
class TournamentExport {
  static const schemaVersion = 1;

  static Map<String, dynamic> document(CreatedTournament tournament) => {
    'format': 'dart-tournament-export',
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'tournament': tournament.toJson(),
  };

  static String encode(CreatedTournament tournament) =>
      const JsonEncoder.withIndent('  ').convert(document(tournament));

  static String html(CreatedTournament tournament) =>
      _htmlTemplate.replaceFirst(
        '@@DATA@@',
        jsonEncode(document(tournament)).replaceAll('<', r'\u003c'),
      );

  static const _htmlTemplate = r'''<!doctype html>
<html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Turnierübersicht</title>
<style>:root{font:16px/1.5 system-ui,sans-serif;color-scheme:light dark}body{margin:0;background:#101820;color:#f5f7f8}main{max-width:1100px;margin:auto;padding:clamp(16px,4vw,40px)}h1{line-height:1.15}section{background:#1b2933;border-radius:14px;padding:16px;margin:18px 0;overflow:auto}.meta,.players{display:flex;flex-wrap:wrap;gap:10px}.pill{border:1px solid #456;padding:6px 10px;border-radius:99px}table{width:100%;border-collapse:collapse;min-width:480px}th,td{text-align:left;padding:10px;border-bottom:1px solid #456}th{color:#9ed9d2}.score{text-align:center;font-weight:700}.muted{color:#b6c2c9}</style>
<main><header><p class="muted">Turnierübersicht</p><h1 id="name"></h1><div class="meta" id="meta"></div></header><section><h2>Teilnehmer</h2><div class="players" id="players"></div></section><section><h2>Begegnungen und Ergebnisse</h2><div id="matches"></div></section><p class="muted">Exportiert aus der Turnierverwaltung.</p></main>
<script type="application/json" id="export">@@DATA@@</script><script>
const root=JSON.parse(document.querySelector('#export').textContent),t=root.tournament;const el=id=>document.getElementById(id),text=(tag,value,cls)=>{const n=document.createElement(tag);n.textContent=value??'';if(cls)n.className=cls;return n};
el('name').textContent=t.name||'Turnier';for(const v of [t.createdAt?new Date(t.createdAt).toLocaleDateString('de-DE'):null,t.communityId?'Community-Turnier':null,t.finishedAt?'Abgeschlossen':null])if(v)el('meta').append(text('span',v,'pill'));
const participants=t.importedArchive?.participants||[];if(participants.length){for(const p of [...participants].sort((a,b)=>(a.finalRank||9999)-(b.finalRank||9999)))el('players').append(text('span',`${p.finalRank?`${p.finalRank}. `:''}${p.name}`,'pill'))}else for(const p of t.players||[])el('players').append(text('span',p.name,'pill'));
const rows=[];for(const m of t.importedArchive?.matches||[])rows.push([m.round?`Runde ${Math.abs(m.round)}`:'Challonge',participants.find(p=>String(p.id)===String(m.player1_id))?.name||'Freilos',m.scores_csv||m.state||'—',participants.find(p=>String(p.id)===String(m.player2_id))?.name||'']);
function walk(v,path=[]){if(!v||typeof v!=='object')return;if(Array.isArray(v)){v.forEach((x,i)=>walk(x,[...path,i]));return}if(v.homePlayer||v.awayPlayer){const score=v.homeLegs!=null?`${v.homeLegs}:${v.awayLegs}${v.homeSets!=null?` (${v.homeSets}:${v.awaySets} Sets)`:''}`:v.homeScore!=null?`${v.homeScore}:${v.awayScore}`:'—';rows.push([v.label||path.filter(x=>typeof x==='string').join(' · ')||'Begegnung',v.homePlayer?.name||'—',score,v.awayPlayer?.name||'—'])}for(const[k,x]of Object.entries(v))if(k!=='deviceResult'&&k!=='homePlayer'&&k!=='awayPlayer')walk(x,[...path,k])}walk(t.runStages||[]);
if(rows.length){const table=document.createElement('table'),head=document.createElement('tr');for(const v of ['Runde / Gruppe','Spieler 1','Ergebnis','Spieler 2'])head.append(text('th',v));table.append(head);for(const row of rows){const tr=document.createElement('tr');row.forEach((v,i)=>tr.append(text('td',v,i===2?'score':'')));table.append(tr)}el('matches').append(table)}else el('matches').append(text('p','Noch keine Begegnungen mit Ergebnissen.'));
</script></html>''';
}
