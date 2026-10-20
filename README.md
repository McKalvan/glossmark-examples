# GlossMark examples

Realistic, multi-language codebases adopted with [GlossMark](https://github.com/McKalvan/GlossMark) **v0.1.0**, plus a lab that probes its modelling.

The small examples and the conformance corpus stay in the main repository, where they gate its CI. Everything here is new material.

| Directory | What |
| --- | --- |
| `showcase/` | Five stable examples, each a different shape. CI-gated by `.github/workflows/showcase.yml` |
| `lab/` | Experiments that may break. Each ends in findings written as GlossMark issues |
| `scripts/` | Install the pinned binary and run the showcase checks locally |

Status: under construction; see [PLAN.md](PLAN.md).

## Install

```sh
sh scripts/install-gloss.sh          # gloss v0.1.0 into .tools/bin, sha256-verified
export GLOSS=$PWD/.tools/bin/gloss
$GLOSS version
scripts/ci-local.sh                  # run every showcase check exactly as CI does
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the showcase and lab contracts.
