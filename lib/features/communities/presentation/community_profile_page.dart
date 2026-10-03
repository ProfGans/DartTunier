import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../../shared/images/profile_image_picker.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import 'widgets/community_avatar.dart';

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.community,
    required this.repository,
    this.imagePicker = const ProfileImagePicker(),
  });
  final Community community;
  final SupabaseCommunityRepository repository;
  final ProfileImagePicker imagePicker;
  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.community.name);
  late final _bio = TextEditingController(text: widget.community.description);
  late String? _avatar = widget.community.avatarBase64;
  late bool _rankingEnabled = widget.community.rankingEnabled;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final encoded = await widget.imagePicker.pick();
      if (encoded == null) return;
      if (mounted) setState(() => _avatar = encoded);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Bildauswahl fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateProfile(
        widget.community,
        name: _name.text,
        bio: _bio.text,
        avatarBase64: _avatar,
        rankingEnabled: _rankingEnabled,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Speichern fehlgeschlagen. Bitte Verbindung und das Recht „Community bearbeiten“ prüfen. Deine Eingaben bleiben erhalten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community bearbeiten')),
    body: Form(
      key: _form,
      child: AdaptiveContentList(
        children: [
          Center(child: CommunityAvatar(base64Image: _avatar, radius: 56)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Profilbild auswählen'),
              ),
              if (_avatar != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _avatar = null),
                  child: const Text('Bild entfernen'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rangliste aktivieren'),
            subtitle: const Text(
              'Elo-Rangliste anzeigen. Beim Aktivieren zählen auch bereits gespeicherte, ranglistenrelevante Spiele. Ergebnisse bleiben beim Ausschalten erhalten.',
            ),
            value: _rankingEnabled,
            onChanged: _busy
                ? null
                : (value) => setState(() => _rankingEnabled = value),
          ),
          TextFormField(
            key: const ValueKey('community-name'),
            controller: _name,
            enabled: !_busy,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Community-Name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte einen Namen eingeben.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('community-bio'),
            controller: _bio,
            enabled: !_busy,
            maxLength: 1000,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText: 'Was macht eure Community aus?',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Änderungen speichern'),
          ),
        ],
      ),
    ),
  );
}
