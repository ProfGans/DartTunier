"""Offline prototype. No automatic deployment; requires independently reviewed
train/validation/test groups. Run with contact_model_dataset.json and output dir.
Dependencies for actual training: PyTorch. Preparation validation uses stdlib.
"""
import argparse
import json
import math
from pathlib import Path


def validate_dataset(document):
    if document.get('schemaVersion') != 1:
        raise ValueError('Unsupported dataset schema')
    groups = {}
    events = {}
    sessions = {}
    seen = set()
    counts = {s: 0 for s in ('train', 'validation', 'test')}
    for sample in document.get('samples', []):
        split = sample.get('split')
        if split not in counts or not sample.get('referenceGroup') or not sample.get('sessionId'):
            raise ValueError('Every sample needs an explicit split, session and reference group')
        for mapping, key in ((groups, sample['referenceGroup']), (events, sample['eventId']), (sessions, sample['sessionId'])):
            if key in mapping and mapping[key] != split:
                raise ValueError('Capture or empty-reference leakage between splits')
            mapping[key] = split
        key = (sample['eventId'], sample['camera'])
        if key in seen:
            raise ValueError('Duplicate camera sample from same capture')
        seen.add(key)
        inputs = sample.get('input', [])
        if len(inputs) != 2 or any(len(channel) != 1024 for channel in inputs):
            raise ValueError('Expected two 32x32 channels')
        if any(not isinstance(v, (int, float)) or not math.isfinite(v) or abs(v) > 1
               for channel in inputs for v in channel):
            raise ValueError('Non-finite or invalid image tensor')
        if not isinstance(sample.get('occluded'), bool):
            raise ValueError('Explicit reviewed visibility required')
        target = sample.get('targetImagePointInPatch')
        if not sample['occluded'] and (not isinstance(target, list) or len(target) != 2 or
                                      any(not math.isfinite(v) or not 0 <= v <= 31 for v in target)):
            raise ValueError('Visible endpoint target missing or outside patch')
        if not sample.get('predictionCentred') or not sample.get('labelReviewId'):
            raise ValueError('Missing independent review or prediction-centred crop')
        counts[split] += 1
    if any(count < 20 for count in counts.values()):
        raise ValueError('At least 20 reviewed camera samples per split required; collect more independent sessions')
    for split in counts:
        flags = {s['occluded'] for s in document['samples'] if s['split'] == split}
        if flags != {False, True}:
            raise ValueError('Every split needs visible and occluded examples')
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('dataset', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--validate-only', action='store_true')
    parser.add_argument('--epochs', type=int, default=40)
    args = parser.parse_args()
    document = json.loads(args.dataset.read_text(encoding='utf-8'))
    counts = validate_dataset(document)
    if args.validate_only:
        print(json.dumps({'counts': counts, 'modelActivated': False}))
        return
    import torch
    from torch import nn
    torch.manual_seed(20261005)
    torch.set_num_threads(2)

    class ContactNet(nn.Module):
        def __init__(self):
            super().__init__()
            self.features = nn.Sequential(nn.Conv2d(2, 16, 3, padding=1), nn.ReLU(),
                                          nn.Conv2d(16, 32, 3, padding=1), nn.ReLU())
            self.contact = nn.Conv2d(32, 1, 1)
            self.occlusion = nn.Sequential(nn.AdaptiveAvgPool2d(1), nn.Flatten(), nn.Linear(32, 1))

        def forward(self, inputs):
            features = self.features(inputs)
            return self.contact(features).flatten(1), self.occlusion(features).flatten()

    def batch(rows):
        inputs = torch.tensor([s['input'] for s in rows], dtype=torch.float32).reshape(-1, 2, 32, 32)
        occluded = torch.tensor([s['occluded'] for s in rows], dtype=torch.float32)
        visible = occluded == 0
        targets = torch.tensor([int(round(s['targetImagePointInPatch'][1])) * 32 +
                                int(round(s['targetImagePointInPatch'][0])) if not s['occluded'] else 0
                                for s in rows], dtype=torch.long)
        return inputs, occluded, visible, targets

    partitions = {p: [s for s in document['samples'] if s['split'] == p] for p in counts}
    model = ContactNet()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    best = float('inf')
    args.output.mkdir(parents=True, exist_ok=True)
    for epoch in range(args.epochs):
        model.train()
        rows = partitions['train']
        order = torch.randperm(len(rows)).tolist()
        for start in range(0, len(rows), 32):
            inputs, occluded, visible, targets = batch([rows[i] for i in order[start:start+32]])
            heatmap, visibility = model(inputs)
            loss = nn.functional.binary_cross_entropy_with_logits(visibility, occluded)
            if visible.any():
                loss = loss + nn.functional.cross_entropy(heatmap[visible], targets[visible])
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
        model.eval()
        with torch.no_grad():
            inputs, occluded, visible, targets = batch(partitions['validation'])
            heatmap, visibility = model(inputs)
            loss = nn.functional.binary_cross_entropy_with_logits(visibility, occluded)
            if visible.any():
                loss += nn.functional.cross_entropy(heatmap[visible], targets[visible])
            if loss.item() < best:
                best = loss.item()
                torch.save(model.state_dict(), args.output / 'contact_candidate.pt')
    model.load_state_dict(torch.load(args.output / 'contact_candidate.pt', weights_only=True))
    model.eval()
    with torch.no_grad():
        inputs, occluded, visible, targets = batch(partitions['test'])
        heatmap, visibility = model(inputs)
        predicted = heatmap.argmax(1)
        errors = ((predicted % 32 - targets % 32).float().square() +
                  (predicted // 32 - targets // 32).float().square()).sqrt()[visible]
        report = {'schemaVersion': 1, 'counts': counts, 'validationLoss': best,
                  'meanVisibleEndpointErrorPatchPixels': errors.mean().item() if errors.numel() else None,
                  'occlusionAccuracy': ((visibility >= 0) == (occluded >= 0.5)).float().mean().item(),
                  'scoringAccuracy': None, 'modelActivated': False,
                  'note': 'Pixel error and occlusion metrics do not establish 99.5% scoring accuracy.'}
        (args.output / 'evaluation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        traced = torch.jit.trace(model, torch.zeros(1, 2, 32, 32))
        traced.save(str(args.output / 'contact_candidate_torchscript.pt'))
    print(json.dumps(report))


if __name__ == '__main__':
    main()
