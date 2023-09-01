#!/usr/bin/env python
import argparse
import copy
import json
import sys
import typing as t

from pathlib import Path

MAP_OFFSETS: t.Dict[str, t.Tuple[int, int]] = {
    # Prehistory | Middle Ages | Future
    # Dark Ages  | Present     | End of Time
    'All Eras': {
        'Prehistory': (0, 0),
        'Dark Ages': (0, 1024),
        'Middle Ages': (1536, 0),
        'Present': (1536, 1024),
        'Future': (3072, 0),
        'End Of Time': (3072, 1024),
    },
    # Prehistory  | Dark Ages
    # Middle Ages | Present
    # Future      | End of Time
    'All Eras (Vertical)': {
        'Prehistory': (0, 0),
        'Dark Ages': (1536, 0),
        'Middle Ages': (0, 1024),
        'Present': (1536, 1024),
        'Future': (0, 2048),
        'End Of Time': (1536, 2048),
    },
}


class CLI:
    def __init__(self):
        self.args = self.get_parser().parse_args()

    @staticmethod
    def get_parser():
        parser = argparse.ArgumentParser(
            prog='normalize-locations.py',
            description='Normalize absolute map locations based on era in locations.json',
        )
        parser.add_argument('locations_file')
        parser.add_argument('-i', '--in-place', help='modify file in-place (overwrites file)', action='store_true')
        parser.add_argument('-k', '--check', help='return non-zero exit if needs updates', action='store_true')
        parser.add_argument('-x', '--explain', help='explain updates to be made', action='store_true')
        return parser

    def gen_coordinates(self, location: t.Dict[str, t.Any]) -> t.Dict[str, t.Any]:
        '''Yield era-relative and absolute ('All Eras') locations.'''
        map_locations = location['map_locations']
        eras = [era for era in map_locations if era['map'] not in ['All Eras', 'All Eras (Vertical)']]

        for era in eras:
            yield era

            for absolute_map, era_offsets in MAP_OFFSETS.items():
                offset_x, offset_y = era_offsets[era['map']]
                absolute = {'map': absolute_map, 'x': era['x'] + offset_x, 'y': era['y'] + offset_y}

                if self.args.explain and absolute not in map_locations:
                    print(f"Updating '{location['name']}' -> {absolute}")

                yield absolute

    def update_coordinates(self, location):
        if 'children' in location:
            for child in location['children']:
                self.update_coordinates(child)
        else:
            location.update({'map_locations': [loc for loc in self.gen_coordinates(location)]})

    def update_locations(self, data) -> t.List[t.Dict[str, t.Any]]:
        updated = copy.deepcopy(data)
        for item in updated:
            self.update_coordinates(item)
        return updated


def main(cli: CLI) -> int:
    data = json.loads(Path(cli.args.locations_file).read_text())
    updated = [item for item in cli.update_locations(data)]
    output = json.dumps(updated, indent=2) + '\n'

    if cli.args.in_place:
        if data == updated:
            print(f"No modifications found, not overwriting {cli.args.locations_file}")
        else:
            Path(cli.args.locations_file).write_text(output)
            print(f"Modified {cli.args.locations_file}")
    elif not cli.args.explain:
        print(output)

    if cli.args.check and data != updated:
        print(f"File {cli.args.locations_file} needs updates.")
        return 1
    return 0


if __name__ == '__main__':
    cli = CLI()
    sys.exit(main(cli))
