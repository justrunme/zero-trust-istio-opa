# Contributing

## Development setup

Install OPA and Conftest locally (versions pinned in `.github/workflows/ci.yml`).

```bash
# Policy unit tests
opa test opa/ -v
# Manifest policy checks
conftest test manifests/app/ -p policy/conftest
```

Full Kind + Istio + OPA e2e is covered by CI (`zero-trust-e2e` job) and `scripts/deploy_all.sh` / `scripts/test_policy.sh`.

## Branch naming

- `feat/<short-name>`
- `fix/<short-name>`
- `chore/<short-name>`
- `docs/<short-name>`
- `ci/<short-name>`

## Commits

Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`, `ci:`.

## Tests

```bash
opa test opa/ -v
conftest test manifests/app/ -p policy/conftest
bash scripts/test_policy.sh   # when a cluster is available
```

## Pull requests

Open against `main`. `lint-and-unit` must be green; e2e runs on PR as well. Squash merge preferred.

Checklist:

- [ ] `opa test opa/ -v` passes
- [ ] Conftest on `manifests/app/` passes
- [ ] Branch naming follows convention
- [ ] Conventional commits
- [ ] Policy changes include Rego tests
