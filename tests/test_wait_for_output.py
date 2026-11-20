#!/usr/bin/env python3
"""Exercise the startup guard against Niri-compatible socket replies."""
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import unittest
import os
import sys

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/system/wait_for_output.py'


class OutputGuardContracts(unittest.TestCase):
    def run_guard(self, replies, check):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / 'niri.sock')
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(path)
                server.listen()
                server.settimeout(10)
                received = []
                def serve():
                    for reply in replies:
                        connection, _ = server.accept()
                        with connection:
                            received.append(connection.recv(1024))
                            connection.sendall(json.dumps(reply).encode() + b'\n')
                thread = threading.Thread(target=serve, daemon=True)
                thread.start()
                result = subprocess.run([sys.executable, str(SCRIPT)] + (['--check'] if check else []),
                                        env={**os.environ, 'NIRI_SOCKET': path},
                                        capture_output=True, text=True, timeout=9)
                thread.join(timeout=1)
                self.assertEqual(received, [b'"Outputs"\n'] * len(replies))
                return result

    def test_check_only_accepts_an_active_output(self):
        for outputs, expected in [({}, 1),
                                  ({'DP-1': {'current_mode': None, 'logical': None}}, 1),
                                  ({'DP-1': {'current_mode': 0, 'logical': {'scale': 2}}}, 0)]:
            with self.subTest(outputs=outputs):
                self.assertEqual(self.run_guard([{'Ok': {'Outputs': outputs}}], True).returncode, expected)

    def test_waits_until_output_returns_without_restarting(self):
        result = self.run_guard([{'Ok': {'Outputs': {}}},
                                {'Ok': {'Outputs': {'DP-1': {'current_mode': 0, 'logical': {'scale': 2}}}}}], False)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count('Waiting for a Niri output'), 1)
        self.assertIn('Niri output available', result.stdout)


if __name__ == '__main__':
    unittest.main()
