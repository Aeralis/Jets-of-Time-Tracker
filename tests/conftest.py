from pathlib import Path
from typing import Dict

import pytest


@pytest.fixture(scope='session')
def paths() -> Dict[str, Path]:
    paths = {'tests': Path(__file__).parent.resolve()}
    paths['root'] = Path(paths['tests'].parent.resolve())
    paths['tools'] = Path(paths['root'], 'tools')

    caches = {'cache': Path(paths['tests'], '.cache')}
    caches.update(
        {
            'poptracker_schemas': Path(caches['cache'], 'poptracker_schemas'),
            'poptracker_schemas_strict': Path(caches['cache'], 'poptracker_schemas_strict'),
        }
    )
    for cache in caches.values():
        if not cache.exists():
            cache.mkdir()

    paths.update(caches)
    return paths
