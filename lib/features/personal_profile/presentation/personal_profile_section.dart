import '../../../shared/widgets/sport_menu.dart';
import 'dart_setup_widgets.dart';
import '../../../shared/images/profile_avatar.dart';
import '../../../shared/images/profile_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../data/personal_profile_repository.dart';
import '../domain/personal_profile.dart';

class PersonalProfileSection extends StatefulWidget {
  const PersonalProfileSection({
    super.key,
    required this.accountId,
    required this.defaultName,
  });
  final String accountId, defaultName;
  @override
  State<PersonalProfileSection> createState() => _PersonalProfileSectionState();
}

class _PersonalProfileSectionState extends State<PersonalProfileSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final repository = PersonalProfileRepository();
  PersonalProfile? profile;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await repository.load(widget.accountId, widget.defaultName);
      if (mounted) {
        setState(() {
          profile = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Profil konnte nicht geladen werden.');
      }
    }
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> edit() async {
    final result = await Navigator.of(context).push<PersonalProfile>(
      MaterialPageRoute(
        builder: (_) => PersonalProfileEditor(
          profile: profile!,
          onSave: (value) => repository.save(widget.accountId, value),
        ),
      ),
    );
    if (mounted && result != null) setState(() => profile = result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final value = profile;
    if (value == null) {
      return error == null
          ? const LinearProgressIndicator()
          : Column(
              children: [
                Text(error!),
                TextButton(
                  onPressed: load,
                  child: const Text('Profil erneut laden'),
                ),
              ],
            );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ProfileAvatar(radius: 40, picture: value.picture),
                Text(
                  value.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DartSetupSummary(setup: value.dartSetup),
            const SizedBox(height: 16),
            Text(repository.status),
            const SizedBox(height: 12),
            SportMenuGroup(
              title: 'Profil verwalten',
              actions: [
                SportMenuAction(
                  label: 'Profil bearbeiten',
                  icon: Icons.edit_outlined,
                  onTap: edit,
                ),
                SportMenuAction(
                  label: 'Profil synchronisieren',
                  icon: Icons.sync,
                  onTap: load,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Nationalität: ${value.nationality.isEmpty ? 'Noch nicht angegeben' : value.nationality}',
            ),
            Text(
              'Walk-on-Song: ${value.song.isEmpty ? 'Noch nicht angegeben' : value.song}',
            ),
            if (value.spotify.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  try {
                    if (!await launchUrl(
                      Uri.parse(value.spotify),
                      mode: LaunchMode.externalApplication,
                    )) {
                      message('Spotify-Link konnte nicht geöffnet werden.');
                    }
                  } catch (_) {
                    message('Spotify-Link konnte nicht geöffnet werden.');
                  }
                },
                icon: const Icon(Icons.music_note),
                label: const Text('Auf Spotify öffnen'),
              ),
            Text(
              'Lieblingsspieler: ${value.favoritePlayer.isEmpty ? 'Noch nicht angegeben' : value.favoritePlayer}',
            ),
            Text(
              'Lieblingsdoppel: ${value.favoriteDouble.isEmpty ? 'Noch nicht angegeben' : value.favoriteDouble}',
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalProfileEditor extends StatefulWidget {
  const PersonalProfileEditor({
    super.key,
    required this.profile,
    required this.onSave,
    this.imagePicker = const ProfileImagePicker(),
  });
  final PersonalProfile profile;
  final Future<void> Function(PersonalProfile) onSave;
  final ProfileImagePicker imagePicker;
  @override
  State<PersonalProfileEditor> createState() => _PersonalProfileEditorState();
}

class _PersonalProfileEditorState extends State<PersonalProfileEditor> {
  final form = GlobalKey<FormState>();
  late final controllers = [
    widget.profile.name,
    widget.profile.nationality,
    widget.profile.song,
    widget.profile.spotify,
    widget.profile.favoritePlayer,
    widget.profile.favoriteDouble,
  ].map((v) => TextEditingController(text: v)).toList();
  late String? picture = widget.profile.picture;
  late var dartSetup = widget.profile.dartSetup;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> selectPicture() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await widget.imagePicker.pick();
      if (selected == null) return;
      if (mounted) {
        setState(() {
          picture = selected;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is FormatException
              ? failure.message
              : 'Bildauswahl fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final v = controllers.map((c) => c.text.trim()).toList();
      final result = PersonalProfile(
        name: v[0],
        nationality: v[1],
        song: v[2],
        spotify: v[3],
        favoritePlayer: v[4],
        favoriteDouble: v[5],
        picture: picture,
        dartSetup: dartSetup,
      );
      await widget.onSave(result);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Speichern fehlgeschlagen. Bitte erneut versuchen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Profil bearbeiten')),
      body: Form(
        key: form,
        child: AdaptiveContentList(
          maxWidth: 900,
          children: [
            const Text(
              'Mit einem Online-Konto werden deine Profilangaben inklusive Bild online gespeichert. Offline bleiben Änderungen lokal erhalten und werden beim nächsten Profil-Abgleich übertragen.',
            ),
            const SizedBox(height: 16),
            Center(child: ProfileAvatar(radius: 48, picture: picture)),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : selectPicture,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Profilbild auswählen'),
                ),
                if (picture != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => picture = null),
                    child: const Text('Bild entfernen'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AdaptiveTileLayout(
              minTileWidth: 350,
              children: [
                for (var i = 0; i < controllers.length; i++)
                  TextFormField(
                    key: ValueKey('personal-profile-field-$i'),
                    controller: controllers[i],
                    enabled: !busy,
                    maxLength: i == 3 ? 500 : 100,
                    keyboardType: i == 3
                        ? TextInputType.url
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: [
                        'Name',
                        'Nationalität',
                        'Walk-on-Song',
                        'Spotify-Link zum Song',
                        'Lieblingsspieler',
                        'Lieblingsdoppel',
                      ][i],
                      hintText: i == 5
                          ? 'z. B. D20 oder Bull'
                          : i == 3
                          ? 'https://open.spotify.com/track/…'
                          : null,
                    ),
                    validator: (v) => i == 0 && (v ?? '').trim().isEmpty
                        ? 'Bitte einen Namen eingeben.'
                        : i == 3 && !PersonalProfile.validSpotify(v ?? '')
                        ? 'Bitte einen Spotify-Song-Link eingeben.'
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            DartSetupFields(
              initialValue: dartSetup,
              enabled: !busy,
              onChanged: (value) => dartSetup = value,
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save),
              label: Text(busy ? 'Wird gespeichert …' : 'Profil speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}
