import 'dart:convert';
import 'package:flutter/material.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, this.base64Image, this.radius = 24});
  final String? base64Image;
  final double radius;
  @override
  Widget build(BuildContext context) {
    Widget content = Icon(Icons.hub_outlined, size: radius);
    try {
      if (base64Image != null) {
        content = Image.memory(
          base64Decode(base64Image!),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              Icon(Icons.hub_outlined, size: radius),
        );
      }
    } catch (_) {
      /* Keep a readable fallback for old or invalid cached images. */
    }
    return CircleAvatar(
      radius: radius,
      child: ClipOval(child: content),
    );
  }
}
