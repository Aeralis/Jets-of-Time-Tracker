import subprocess

from pathlib import Path

import pytest


@pytest.fixture(params=['locations/locations.json'])
def locations_json(paths, request):
    return Path(paths['root'], request.param)


# TESTS ######################################################################


def test_normalize_locations(paths, locations_json):
    """Test all locations era-relative coordinates have matching absolute coords."""
    tool = Path(paths['tools'], 'normalize-locations.py')
    args = [tool, '-xk', str(locations_json)]
    sp = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout = sp.stdout.decode('utf-8')
    err = (
        f"normalize-locations.py indicates updates are required\n"
        f"Fix by updating with:\n"
        f"  ./tools/normalize-locations.py -xi {locations_json.relative_to(paths['root'])}\n\n"
    )
    assert sp.returncode == 0, f'{err}\n{stdout}'
