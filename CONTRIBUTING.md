# Contributing to Jets-of-Time Tracker

## Tools

The `tools` directory has tools for building/modifying/verifying pack assets.

### Map Location Normalization

The `tools/normalize-locations.py` tool can be used to normalize all map locations (e.g. in
`locations/locations.json`). This makes sure that each era-relative map location has
corresponding absolute coordinates which are offset relative to that era (e.g. a map
location for "Future" has a corresponding coordinate for "All Eras" with (x, y)
coordinates offset the appropriate amount).

Usage details can be found by running `./tools/normalize-locations.py --help`.

A typical use-case is updating locations (adding new spots), then running the tool to
automatically add the "All Eras" coordinates, overwriting the locations file:

```bash
./tools/normalize-locations.py -xi locations/locations.json
```

## Development

For development, it is recommended to install python (3.11+) and lua with your system package manager.

Development is most easily done in a [python3 virtualenv](https://docs.python.org/3/library/venv.html)
with test dependencies installed via:

```bash
pip install -r tests/requirements.txt
```

Changes should be verified on both PopTracker and EmoTracker.

### Github Workflow

There are several workflows defined in `.github/workflows`:

* `luacheck.yaml`: runs [`luacheck`](https://luacheck.readthedocs.io/en/stable/) against .lua files
* `jsontest.yaml`: runs [`pytest`](https://pytest.org) on tests in `tests/json/` against .json files

It is intended that Pull Requests pass these checks before being merged and released, to
assure a measure of stability and quality with this repo.

#### `jsontest.yaml`

This workflow uses [`pytest`](https://pytest.org) to validate all .json files in this repo
by running the tests in `tests/json/`.

These tests can be run in a python3 virtualenv via:

```bash
pytest -vv tests/json
```

Tests in `tests/json/test_json.py` check that all .json files are loadable as valid JSON and also
performs [JSON Schema validation](https://json-schema.org) against the PopTracker
pack files using upstream [PopTracker JSON Schema](https://poptracker.github.io/schema/packs/).

The schema validation is intended to quickly catch errors which could cause changes to break
integration with PopTracker (or EmoTracker).

Currently, strict validation is only used on items.json, manifest.json, and maps.json. Layouts
and locations are using non-strict validation.

Additionally, `tests/json/test_locations.py` makes sure all locations (in `locations.json`)
have correct absolute map locations (e.g. for the "All Eras" map) based on each era-relative
coordinate. The `tools/normalize-locations.py` tool can produce a file which should pass
these tests (the tests actually invoke this tools `--check` mode).

## Releases

The Github Releases mechanism is used to manually create tags/releases for users to download
and use with PopTracker. The Releases archives all non-development-only files into .zip and
.tar.gz for download using `git archive` (files can be excluded in `.gitattributes`).
The intention is to direct users to the Releases page.

It is recommended to create tags (in the form of "vmajor.minor.patch", e.g. v2.1.1) along with
each release, corresponding to bumping the version in `manifest.json` and the `changelog.txt`
file with brief description of updates in this release. Test versions can use a "release candidate"
suffix (e.g. v.2.1.1-rc0). Releases/tags are intended to be immutable (not overwritten).

### Local Release Artifacts

A local release artifact can be created via [`git archive`](https://git-scm.com/docs/git-archive):

```bash
git archive HEAD --format=zip CT_JoT_Tracker.zip
```

This zip file should be usable by both PopTracker and EmoTracker. (NOTE: `git archive` only
includes committed files, so any non-commited changes will not be included).
