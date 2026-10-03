class RemoteControlSettings {
  const RemoteControlSettings({
    this.enabled = false,
    this.requireConfirmation = false,
  });
  final bool enabled, requireConfirmation;
  RemoteControlSettings copyWith({bool? enabled, bool? requireConfirmation}) =>
      RemoteControlSettings(
        enabled: enabled ?? this.enabled,
        requireConfirmation: requireConfirmation ?? this.requireConfirmation,
      );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'enabled': enabled,
    'requireConfirmation': requireConfirmation,
  };
  factory RemoteControlSettings.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['enabled'] is! bool ||
        json['requireConfirmation'] is! bool) {
      throw const FormatException('Ungültige Fernsteuerungseinstellungen');
    }
    return RemoteControlSettings(
      enabled: json['enabled'] as bool,
      requireConfirmation: json['requireConfirmation'] as bool,
    );
  }
}
