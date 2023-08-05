#!/usr/bin/env python3
import json

from collections import defaultdict
from pathlib import Path

def main():
    jsonfiles = Path(".").rglob("*.json")

    badfiles = defaultdict(list)
    for jsonfile in jsonfiles:
        # check file is loadable as JSON
        try:
            json.load(jsonfile.open())
        except Exception as ex:
            badfiles[str(jsonfile)].append(ex)

    if badfiles:
        err = (
            'Found problems with JSON files:\n' +
            '---------------------------------\n' +
            '\n\n'.join(
                f'{filename}:\n' + '\n'.join(f'* {ex}' for ex in excs)
                for filename, excs in sorted(badfiles.items())
            )
        )
        raise SystemExit(err)


if __name__ == '__main__':
    main()
