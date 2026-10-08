import copy
import unittest
from train_contact_model import validate_dataset


def dataset():
    return {'schemaVersion': 1, 'samples': [
        {'input': [[0.0] * 1024, [0.0] * 1024], 'split': split,
         'eventId': f'{split}:{i}', 'camera': 1, 'sessionId': split,
         'referenceGroup': split, 'predictionCentred': True,
         'labelReviewId': f'review:{split}:{i}', 'occluded': i % 2 == 0,
         'targetImagePointInPatch': None if i % 2 == 0 else [15.0, 16.0]}
        for split in ('train', 'validation', 'test') for i in range(20)]}


class DatasetValidation(unittest.TestCase):
    def test_valid_independent_groups(self):
        self.assertEqual(validate_dataset(dataset()), {'train': 20, 'validation': 20, 'test': 20})

    def test_no_labels_blocks_training(self):
        with self.assertRaises(ValueError):
            validate_dataset({'schemaVersion': 1, 'samples': []})

    def test_reference_leakage_blocks_training(self):
        data = dataset()
        data['samples'][20]['referenceGroup'] = 'train'
        with self.assertRaises(ValueError):
            validate_dataset(data)

    def test_non_finite_input_blocks_training(self):
        data = copy.deepcopy(dataset())
        data['samples'][0]['input'][0][0] = float('nan')
        with self.assertRaises(ValueError):
            validate_dataset(data)

    def test_duplicates_block_training(self):
        data = dataset()
        data['samples'].append(copy.deepcopy(data['samples'][0]))
        with self.assertRaises(ValueError):
            validate_dataset(data)


if __name__ == '__main__':
    unittest.main()
