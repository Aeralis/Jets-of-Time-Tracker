import json
import os

from collections import defaultdict
from pathlib import Path
from urllib.parse import urljoin
from typing import Any, Dict, List

import pytest
import requests

from jsonschema import validate

POPTRACKER_PACK_TYPES = ['items', 'layouts', 'locations', 'manifest', 'maps']
POPTRACKER_PACK_STRICT_TYPES = ['items', 'manifest', 'maps']
SCHEMA_CACHE_DIR = Path(Path(__file__).parent.resolve(), '.poptracker_schemas')
STRICT_SCHEMA_CACHE_DIR = Path(SCHEMA_CACHE_DIR, 'strict')
POPTRACKER_REMOTE_PATH = 'https://poptracker.github.io/schema/packs/'
POPTRACTER_REMOTE_STRICT_PATH = urljoin(POPTRACKER_REMOTE_PATH, 'strict/')

@pytest.fixture(scope='session')
def jsonfiles() -> List[Path]:
    return [path for path in Path('.').rglob('*.json')]

@pytest.fixture(scope='session')
def pack_files() -> Dict[str, List[Path]]:
    files_map: Dict[str, List[Path]] = {}
    all_dirs = [p for p in Path('.').rglob('*') if p.is_dir()]
    for pack_type in POPTRACKER_PACK_TYPES:
        jsonfiles = []
        pack_type_dirs = [p for p in all_dirs if str(p) == pack_type]
        for path in pack_type_dirs:
            jsonfiles.extend([f for f in path.rglob('*.json')])
        files_map[pack_type] = jsonfiles
    return files_map

def get_or_download_schemas(
    cache_dir: Path, remote_path: str
) -> Dict[str, Dict[str, Any]]:
    # local schema file cache
    cached_files = {
        schema: Path(cache_dir, f'{schema}.json')
        for schema in POPTRACKER_PACK_TYPES
    }
    urls = {
        schema: urljoin(remote_path, f'{schema}.json')
        for schema in POPTRACKER_PACK_TYPES
    }
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
def poptracker_schemas() -> Dict[str, Dict[str, Any]]:
    '''PopTracker JSON schemas downloaded from remote.'''
    if not SCHEMA_CACHE_DIR.exists():
        SCHEMA_CACHE_DIR.mkdir()

    cache_dir = SCHEMA_CACHE_DIR
    remote_path = POPTRACKER_REMOTE_PATH
    return get_or_download_schemas(cache_dir, remote_path)

@pytest.fixture(scope='session')
def poptracker_strict_schemas() -> Dict[str, Dict[str, Any]]:
    if not SCHEMA_CACHE_DIR.exists():
        SCHEMA_CACHE_DIR.mkdir()
    if not STRICT_SCHEMA_CACHE_DIR.exists():
        STRICT_SCHEMA_CACHE_DIR.mkdir()

    cache_dir = STRICT_SCHEMA_CACHE_DIR
    remote_path = POPTRACKER_REMOTE_STRICT_PATH
    return get_or_download_schemas(cache_dir, remote_path)

def test_all_jsonfiles_loadable(jsonfiles):
    '''Check all files are loadable as JSON.'''
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
