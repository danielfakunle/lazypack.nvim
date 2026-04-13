# Contributing

Thanks for contributing to LazyPack.

## Running tests

Run the test suite with:

```sh
./scripts/test.sh
```

The script bootstraps `plenary.nvim` into `.deps/plenary.nvim` and runs
`tests/lazypack_spec.lua` through Plenary's busted harness.

## Commit message format

This repository uses Conventional Commits.

Examples:

- `feat: add support for dependencies`
- `fix: avoid running config twice`
- `docs: clarify usage example`
- `refactor(core): simplify command forwarding`

On pull requests, commit messages are linted by CI.

You can run commitlint locally for a range:

```sh
npm ci
npm run commitlint -- "origin/main..HEAD"
```

## Releases and changelog

Releases are automated with Release Please.

- Merged commits on `main` are analyzed.
- Release Please opens or updates a release PR with version and changelog
  updates.
- Merging that release PR creates the Git tag and GitHub Release.

To make release notes useful, prefer meaningful Conventional Commit messages.
