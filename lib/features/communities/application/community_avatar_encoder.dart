import 'package:flutter/foundation.dart';
import '../../../shared/images/profile_image_encoder.dart';

Future<String> encodeCommunityAvatar(Uint8List bytes) =>
    encodeProfileImage(bytes);
