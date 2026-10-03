import importlib.util
import pathlib
import sys
import types
import unittest
from unittest.mock import patch
sys.dont_write_bytecode = True

# fcntl is native on Linux; this test checks delivery/HTTP contracts on Windows.
if sys.platform != 'linux':
    sys.modules['fcntl'] = types.SimpleNamespace()
spec = importlib.util.spec_from_file_location('worker', 'assets/linux/notification_worker.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)

class WorkerTest(unittest.TestCase):
    def test_notify_arguments_are_literal_and_markup_escaped(self):
        with patch.object(worker.subprocess, 'run') as run:
            worker.deliver({'title': '--help', 'body': '<b>test</b> $(command)'})
        args = run.call_args.args[0]
        self.assertEqual(args[-3:], ['--', '--help', '&lt;b&gt;test&lt;/b&gt; $(command)'])
        self.assertNotIn('shell', run.call_args.kwargs)
        self.assertTrue(run.call_args.kwargs['check'])

    def test_non_https_backend_is_rejected(self):
        with self.assertRaises(ValueError):
            worker.poll({'url':'http://example.test'}, [])

    def test_python_entrypoints_compile(self):
        for path in ['assets/linux/notification_worker.py', 'linux/install-desktop.py']:
            compile(pathlib.Path(path).read_text(), path, 'exec')

unittest.main()
