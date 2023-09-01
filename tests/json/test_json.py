import json

from pathlib import Path
from urllib.parse import urljoin
from typing import Any, Dict, List

import pytest
import requests

from jsonschema import validate

JSONSchema = Dict[str, Any]

POPTRACKER_PACK_TYPES = ['items', 'layouts', 'locations', 'manifest', 'maps']
POPTRACKER_PACK_STRICT_TYPES = ['manifest', 'maps']

# FIXTURES ###################################################################


@pytest.fixture(scope='session')
def remote_paths() -> Dict[str, str]:
    poptracker_remote_path = 'https://poptracker.github.io/schema/packs/'

    return {
        'poptracker_schema': poptracker_remote_path,
        'poptracker_schema_strict': urljoin(poptracker_remote_path, 'strict/'),
    }


@pytest.fixture(scope='session')
def jsonfiles(paths) -> List[Path]:
    return [path for path in paths['root'].rglob('*.json') if path.parts[0] not in ['.venv', 'tests']]


@pytest.fixture(scope='session')
def formatted_jsonfiles(paths, jsonfiles) -> List[Path]:
    # exclude older paths and gradually update to new formatting
    # to avoid having large git diffs
    excluded_paths = ['items/', 'tests/']
    return [p for p in jsonfiles if not any(str(p.relative_to(paths['root'])).startswith(ep) for ep in excluded_paths)]


@pytest.fixture(scope='session')
def pack_files(paths) -> Dict[str, List[Path]]:
    files_map: Dict[str, List[Path]] = {}
    all_dirs = [p for p in paths['root'].rglob('*') if p.is_dir()]
    for pack_type in POPTRACKER_PACK_TYPES:
        jsonfiles = []
        pack_type_dirs = [p for p in all_dirs if str(p) == pack_type]
        for path in pack_type_dirs:
            jsonfiles.extend([f for f in path.rglob('*.json')])
        files_map[pack_type] = jsonfiles
    return files_map


def get_or_download_schemas(cache: Path, remote_path: str) -> Dict[str, JSONSchema]:
    # local schema file cache
    cached_files = {schema: Path(cache, f'{schema}.json') for schema in POPTRACKER_PACK_TYPES}
    schemas: Dict[str, Dict[str, Any]] = {}
    for schema in POPTRACKER_PACK_TYPES:
        try:
            schemas[schema] = json.load(cached_files[schema].open())
        except IOError:
            url = urljoin(remote_path, f'{schema}.json')
            try:
                remote_schema = requests.get(url).json()
            except Exception as ex:
                err = f'Unable to download poptracker schema ({schema}): {url}'
                raise ValueError(err) from ex
            cached_files[schema].write_text(json.dumps(remote_schema))
            schemas[schema] = remote_schema
    return schemas


@pytest.fixture(scope='session')
def poptracker_schemas(paths, remote_paths) -> Dict[str, JSONSchema]:
    '''PopTracker JSON schemas downloaded from remote.'''
    return get_or_download_schemas(paths['poptracker_schemas'], remote_paths['poptracker_schema'])


@pytest.fixture(scope='session')
def poptracker_strict_schemas(paths) -> Dict[str, JSONSchema]:
    return get_or_download_schemas(paths['poptracker_schemas_strict'], remote_paths['poptracker_schema_strict'])


# TESTS ######################################################################


def test_all_jsonfiles_loadable(jsonfiles):
    '''Check all files are loadable as JSON.'''
    assert jsonfiles, 'Failed to find any JSON files.'

    for jsonfile in jsonfiles:
        assert json.load(jsonfile.open())


@pytest.mark.parametrize('pack_type', POPTRACKER_PACK_TYPES)
def test_pack_schema_validation(pack_type, poptracker_schemas, pack_files):
    schema = poptracker_schemas[pack_type]
    for jsonfile in pack_files[pack_type]:
        try:
            validate(json.load(jsonfile.open()), schema)
        except Exception as ex:
            err = f'Failed to JSON schema validate file: {jsonfile}'
            raise ValueError(err) from ex


@pytest.mark.parametrize('pack_type', POPTRACKER_PACK_STRICT_TYPES)
def test_pack_strict_schema_validation(pack_type, poptracker_schemas, pack_files):
    schema = poptracker_schemas[pack_type]
    for jsonfile in pack_files[pack_type]:
        try:
            validate(json.load(jsonfile.open()), schema)
        except Exception as ex:
            err = f'Failed to strict JSON schema validate file: {jsonfile}'
            raise ValueError(err) from ex


def test_json_file_style(paths, formatted_jsonfiles):
    '''Check all formatted json files are formatted per json.tool.'''
    assert formatted_jsonfiles, 'Failed to find any formatted json files.'

    for jsonfile in formatted_jsonfiles:
        text = jsonfile.read_text()
        loaded_json = json.loads(text)
        formatted_output = json.dumps(loaded_json, indent=2) + '\n'
        try:
            assert text == formatted_output
        except AssertionError as ex:
            rel_jsonfile = jsonfile.relative_to(paths['root'])
            err = (
                f"JSON file {jsonfile} is not formatted correctly.\n"
                f"Fix by formatting with:\n"
                f"  python -m json.tool --indent=2 {rel_jsonfile} {rel_jsonfile}\n\n"
            )
            raise ValueError(err) from ex
