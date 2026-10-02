import 'dart:io';
import '../domain/android_release.dart';

abstract class AppUpdateService {
  bool get supported;
  bool get isDesktop => false;
  String get platformLabel => 'Android';
  Future<({String version, int build})> installed();
  Future<AndroidRelease?> check(
    int installedBuild, {
    bool includePrereleases = false,
  });
  Future<File> download(AndroidRelease release, void Function(double) progress);
  Future<bool> install();
}
