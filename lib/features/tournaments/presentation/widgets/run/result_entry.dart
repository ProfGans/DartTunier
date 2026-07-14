import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import '../../models/match_result.dart';

class MatchResultTile extends StatelessWidget {
  const MatchResultTile({
    super.key,
    required this.match,
    required this.onEditResult,
    required this.canEditResult,
    this.originLabel,
    this.leadingLabel,
  });

  final GroupMatch match;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final String? originLabel;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = canEditResult && match.hasPlayers;
    final roundLabel = leadingLabel ?? 'Runde ${match.round}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      roundLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (originLabel != null)
                      _MatchOriginChip(label: originLabel!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(match.homePlayer?.name ?? 'offen'),
                const SizedBox(height: 4),
                Text(match.awayPlayer?.name ?? 'offen'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ScoreBadge(
                      match: match,
                      onTap: canEdit ? () => onEditResult(match) : null,
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: canEdit ? () => onEditResult(match) : null,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Ergebnis',
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: leadingLabel == null ? 74 : 148,
                child: Text(
                  roundLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              if (originLabel != null) ...[
                _MatchOriginChip(label: originLabel!),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(match.homePlayer?.name ?? 'offen')),
              _ScoreBadge(
                match: match,
                onTap: canEdit ? () => onEditResult(match) : null,
              ),
              Expanded(
                child: Text(
                  match.awayPlayer?.name ?? 'offen',
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: canEdit ? () => onEditResult(match) : null,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Ergebnis',
              ),
            ],
          );
        },
      ),
    );
  }
}

class ResultDialog extends StatefulWidget {
  const ResultDialog({super.key, required this.match});

  final GroupMatch match;

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> {
  late final TextEditingController _homeLegsController;
  late final TextEditingController _awayLegsController;

  @override
  void initState() {
    super.initState();
    _homeLegsController = TextEditingController(
      text: widget.match.homeLegs?.toString() ?? '',
    );
    _awayLegsController = TextEditingController(
      text: widget.match.awayLegs?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeLegsController.dispose();
    _awayLegsController.dispose();
    super.dispose();
  }

  void _save() {
    final homeLegs = int.tryParse(_homeLegsController.text);
    final awayLegs = int.tryParse(_awayLegsController.text);
    if (homeLegs == null || awayLegs == null || homeLegs < 0 || awayLegs < 0) {
      return;
    }
    if (widget.match.isDecider && homeLegs == awayLegs) {
      return;
    }

    Navigator.of(
      context,
    ).pop(MatchResult(homeLegs: homeLegs, awayLegs: awayLegs));
  }

  void _annul() {
    Navigator.of(context).pop(const MatchResult.annulled());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ergebnis eingeben'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.match.homePlayer?.name ?? 'offen'} vs '
            '${widget.match.awayPlayer?.name ?? 'offen'}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('home-legs-field'),
                  controller: _homeLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.homePlayer?.name ?? 'offen',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('away-legs-field'),
                  controller: _awayLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.awayPlayer?.name ?? 'offen',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _annul,
          icon: const Icon(Icons.block_outlined),
          label: const Text('Spiel annullieren'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

class _MatchOriginChip extends StatelessWidget {
  const _MatchOriginChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.match, this.onTap});

  final GroupMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final badge = Container(
      width: match.isAnnulled ? 92 : 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: match.isAnnulled
            ? colorScheme.errorContainer
            : match.hasResult
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        match.isAnnulled
            ? 'annulliert'
            : match.hasResult
            ? '${match.homeLegs}:${match.awayLegs}'
            : '-:-',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Tooltip(
      message: 'Ergebnis eingeben',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}
