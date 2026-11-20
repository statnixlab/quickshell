#!/usr/bin/python3
"""Wait for a usable Niri output before starting an output-dependent service."""
import argparse
import json
import os
import socket
import sys
import time


def output_available(socket_path):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(2)
        connection.connect(socket_path)
        connection.sendall(b'"Outputs"\n')
        with connection.makefile('rb') as stream:
            result = json.loads(stream.readline(1024 * 1024))
    if 'Err' in result:
        raise RuntimeError(str(result['Err']))
    outputs = result['Ok']['Outputs']
    return any(output.get('current_mode') is not None and output.get('logical')
               for output in outputs.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Check once without waiting')
    args = parser.parse_args()
    socket_path = os.environ.get('NIRI_SOCKET')
    if not socket_path:
        print('NIRI_SOCKET is unavailable', file=sys.stderr)
        return 1
    announced = False
    while True:
        try:
            ready = output_available(socket_path)
        except (OSError, ValueError, KeyError, TypeError, RuntimeError):
            ready = False
        if args.check:
            return 0 if ready else 1
        if ready:
            print('Niri output available; starting remote desktop', flush=True)
            return 0
        if not announced:
            print('Waiting for a Niri output; remote desktop is not being restarted', flush=True)
            announced = True
        time.sleep(5)


if __name__ == '__main__':
    sys.exit(main())
