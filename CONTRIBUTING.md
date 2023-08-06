# Contributing to Jets-of-Time Tracker

## Development

### Github Workflow

There are several workflows defined in `.github/workflows`:

* `luacheck.yaml`: runs [`luacheck](https://luacheck.readthedocs.io/en/stable/) against .lua files
* `jsontest.yaml`: runs this repos `tests/checkjson.py` script against .json files

It is intended that Pull Requests pass these checks before being merged and released, to
assure a measure of stability and quality with this repo.

## Releases

The Github Releases mechanism is used to manually create tags/releases for users to download
and use with PopTracker. The Releases archive (via `git archive`) all non-development-only files
into .zip and .tar.gz for download. The intention is to direct users to the Releases page.

It is recommended to create tags (in the form of "vmajor.minor.patch", e.g. v2.1.1) along with
each release, corresponding to bumping the version in `manifest.json` and the `changelog.txt`
file with brief description of updates in this release.
