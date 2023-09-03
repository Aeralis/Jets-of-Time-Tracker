import json

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Type
from urllib.parse import urljoin, urlsplit

import jsonschema
import pytest
import requests

from referencing import Registry, Resource

JSONSchema = Dict[str, Any]


# FIXTURES ###################################################################


@dataclass
class TrackerClient:
    cache: str
    remote_path: str
    pack_types: List[str]


class PopTracker(TrackerClient):
    cache = 'poptracker'
    remote_path = 'https://poptracker.github.io/schema/packs/'
    pack_types = ['items', 'layouts', 'locations', 'manifest', 'maps']


class PopTrackerStrict(TrackerClient):
    cache = 'poptracker'
    remote_path = 'https://poptracker.github.io/schema/packs/strict/'
    pack_types = ['manifest', 'maps']


class EmoTracker(TrackerClient):
    cache = 'emotracker'
    remote_path = 'https://emotracker.net/developers/schemas/'
    pack_types = ['all', 'items', 'layouts', 'locations']


def get_or_download(cache: Path, uri: str) -> JSONSchema:
    '''Get schema from cache file or download and write.'''
    cached_file = Path(cache / urlsplit(uri).path.lstrip('/')).resolve()
    try:
        contents = json.load(cached_file.open())
    except IOError:
        try:
            contents = requests.get(uri).json()
        except Exception as ex:
            err = f"Unable to download tracker schema: {uri}"
            raise ValueError(err) from ex
        cached_file.parent.mkdir(parents=True, exist_ok=True)
        cached_file.write_text(json.dumps(contents))
    return contents


def get_pack_files(root: Path) -> Dict[str, List[Path]]:
    # get all directories that don't start with '.' and aren't in tests
    all_dirs = [path for path in [p for p in root.rglob('*') if p.is_dir()] if is_pack_file(path, root)]

    # group files in directories based on pack_type
    files_map: Dict[str, List[Path]] = {}
    for pack_type in PopTracker.pack_types:
        jsonfiles: List[Path] = []
        pack_type_dirs = [p.relative_to(root) for p in all_dirs if pack_type in p.relative_to(root).parts]
        for path in pack_type_dirs:
            jsonfiles.extend([f for f in path.glob('*.json') if not f.is_symlink()])
        files_map[pack_type] = jsonfiles
    files_map['manifest'] = [Path('manifest.json')]

    return files_map


def is_pack_file(path: Path, root: Path):
    part = path.relative_to(root).parts[0]
    return not part.startswith('.') and part not in ['tests', 'tools']


@pytest.fixture(scope='session')
def jsonfiles(paths) -> List[Path]:
    return [path for path in paths['root'].rglob('*.json') if is_pack_file(path, paths['root'])]


@pytest.fixture(scope='session')
def pack_files(paths) -> Dict[str, List[Path]]:
    return get_pack_files(paths['root'])


@pytest.fixture(
    scope='session',
    params=[PopTracker, PopTrackerStrict, EmoTracker],
    ids=['PopTracker', 'PopTracker[strict]', 'EmoTracker'],
)
def tracker(request) -> Type[TrackerClient]:
    return request.param


@pytest.fixture(scope='session')
def registry(paths, tracker) -> Registry:
    '''JSONSchema registry using locally cached test files.'''

    def retrieve(uri: str):
        return Resource.opaque(get_or_download(paths[tracker.cache], uri))

    return Registry(retrieve=retrieve)


@pytest.fixture(scope='session')
def schemas(paths, tracker) -> Dict[str, JSONSchema]:
    '''Schemas for pack files using locally cached schema files.'''
    jsonschemas: Dict[str, JSONSchema] = {}
    for schema in tracker.pack_types:
        uri = urljoin(tracker.remote_path, f"{schema}.json")
        jsonschemas[schema] = get_or_download(paths[tracker.cache], uri)
    return jsonschemas


@pytest.fixture(scope='session')
def validators(tracker, registry, schemas) -> Dict[str, jsonschema.validators.Validator]:
    '''JSONSchema validators for pack files using locally cached schema files.'''
    vmap: Dict[str, jsonschema.validators.Validator] = {}
    for pack_type in tracker.pack_types:
        schema = schemas.get('all', schemas[pack_type])
        validator_cls = jsonschema.validators.validator_for(schema)
        vmap[pack_type] = validator_cls(schema, registry=registry)
    return vmap


# TESTS ######################################################################


def test_all_jsonfiles_loadable(jsonfiles):
    '''Check all files are loadable as JSON.'''
    assert jsonfiles, 'Failed to find any JSON files.'

    for jsonfile in jsonfiles:
        assert json.load(jsonfile.open())


def test_expected_pack_files(paths, jsonfiles, pack_files):
    '''Coherence check between jsonfiles and pack_files to assure not missing files in tests.

    This test is to assure that if updates in jsonfiles or pack_files fixtures are made,
    that the expected files for testing are not silently missed. All files in jsonfiles
    should be in pack_files fixture (except for expected exceptions, like settings.json).
    '''
    all_pack_files = {file for files in pack_files.values() for file in files}

    # "settings.json" files are in jsonfiles but not pack_files
    expected_differences = ['settings.json']

    expected_pack_files = set()
    for jsonfile in jsonfiles:
        file = jsonfile.relative_to(paths['root'])
        if file.parts[-1] not in expected_differences:
            expected_pack_files.add(file)

    assert all_pack_files == expected_pack_files


@pytest.mark.parametrize('pack_type', PopTracker.pack_types)
def test_pack_schema_validation(pack_type, tracker, validators, pack_files, print_debug):
    '''Check pack files pass JSONSchema validation.'''
    assert pack_files[pack_type], f'Missing {pack_type} pack files!'

    if pack_type not in tracker.pack_types:
        pytest.skip(f"no schema for {pack_type}")

    validator = validators[pack_type]
    print_debug(f"\nUsing {type(validator).__name__} for '{pack_type}' schema...")

    for jsonfile in pack_files[pack_type]:
        print_debug(f"* Validating {jsonfile}")
        try:
            validator.validate(json.load(jsonfile.open()))
        except Exception as ex:
            err = f'Failed to JSON schema validate file: {jsonfile}'
            raise ValueError(err) from ex


def test_json_file_style(paths, jsonfiles):
    '''Check all formatted json files are formatted per json.tool.'''
    for jsonfile in jsonfiles:
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
