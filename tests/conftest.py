from pathlib import Path
from typing import Dict

import pytest


def pytest_addoption(parser):
    parser.addoption('--debug-tests', help='print debugging info inline with tests', action='store_true')


@pytest.fixture
def print_debug(capsys, request):
    '''Prints test debugging info inline with tests when --debug-tests passed to pytest.'''
    if request.config.getoption('--debug-tests'):

        def _print(*args, **kwargs):
            with capsys.disabled():
                print(*args, **kwargs)

        return _print
    return print


@pytest.fixture(scope='session')
def paths() -> Dict[str, Path]:
    paths = {'tests': Path(__file__).parent.resolve()}
    paths['root'] = Path(paths['tests'].parent.resolve())
    paths['tools'] = Path(paths['root'], 'tools')

    caches = {'cache': Path(paths['tests'], '.cache')}
    caches.update(
        {
            'emotracker': Path(caches['cache'], 'emotracker_schemas'),
            'poptracker': Path(caches['cache'], 'poptracker_schemas'),
        }
    )
    for cache in caches.values():
        if not cache.exists():
            cache.mkdir()

    paths.update(caches)
    return paths
