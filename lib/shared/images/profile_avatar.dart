import 'dart:convert';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.picture,
    this.radius = 24,
    this.icon = Icons.person,
  });
  final String? picture;
  final double radius;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Icon(icon, size: radius);
    Widget content = fallback();
    try {
      if (picture != null) {
        content = Image.memory(
          base64Decode(picture!),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          cacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context))
              .ceil(),
          errorBuilder: (context, error, stack) => fallback(),
        );
      }
    } on FormatException {
      // Invalid legacy/cache data must not break the profile page.
    }
    return CircleAvatar(
      radius: radius,
      child: ClipOval(child: content),
    );
  }
}
