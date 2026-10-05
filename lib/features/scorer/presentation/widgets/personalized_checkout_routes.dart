import 'package:flutter/material.dart';
import '../../../personal_profile/data/personal_profile_repository.dart';
import '../../domain/x01/x01_models.dart';
import '../checkout_page.dart';

class PersonalizedCheckoutRoutes extends StatefulWidget {
  const PersonalizedCheckoutRoutes({
    super.key,
    required this.score,
    required this.dartsLeft,
    required this.requirement,
    this.accountId,
    this.enabled = true,
    this.repository,
  });
  final int score, dartsLeft;
  final CheckoutRequirement requirement;
  final String? accountId;
  final bool enabled;
  final PersonalProfileRepository? repository;
  @override
  State<PersonalizedCheckoutRoutes> createState() => _RoutesState();
}

class _RoutesState extends State<PersonalizedCheckoutRoutes> {
  String favorite = '';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PersonalizedCheckoutRoutes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = ++generation;
    favorite = '';
    final id = widget.accountId;
    if (id == null) return;
    try {
      final profile = await (widget.repository ?? PersonalProfileRepository())
          .load(id, '');
      if (mounted && token == generation) {
        setState(() => favorite = profile.favoriteDouble);
      }
    } catch (_) {
      // Profile/network failures must not interrupt a running scorer.
    }
  }

  @override
  Widget build(BuildContext context) => CheckoutRoutes(
    score: widget.score,
    dartsLeft: widget.dartsLeft,
    requirement: widget.requirement,
    favoriteDouble: widget.enabled ? favorite : '',
  );
}
