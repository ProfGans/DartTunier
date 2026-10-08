import 'community.dart';

/// Inhaber zuerst, danach Namen nach deutscher Grundbuchstaben-Sortierung.
/// Account-Status und Beitrittsdatum beeinflussen die Namensreihenfolge nicht.
List<CommunityMember> sortedCommunityMembers(
  List<CommunityMember> members, {
  required String ownerUserId,
}) {
  String nameKey(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss');

  final entries = members.indexed.toList();
  entries.sort((a, b) {
    final owner = (a.$2.userId == ownerUserId ? 0 : 1).compareTo(
      b.$2.userId == ownerUserId ? 0 : 1,
    );
    if (owner != 0) return owner;
    final name = nameKey(a.$2.displayName).compareTo(nameKey(b.$2.displayName));
    if (name != 0) return name;
    final identity = (a.$2.playerProfileId ?? a.$2.userId ?? '').compareTo(
      b.$2.playerProfileId ?? b.$2.userId ?? '',
    );
    return identity != 0 ? identity : a.$1.compareTo(b.$1);
  });
  return [for (final entry in entries) entry.$2];
}
