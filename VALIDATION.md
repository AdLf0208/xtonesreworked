# Validation

> **Current package (2026-11-21, SDK `0a875da`).** One flat `.hmod`:
> `xtonesreworked.hmod` **1,471,108 B** SHA-256
> `2334f5e41cba8d2eef24d3d70e1696e32761010298cf724c4541a6d366d51ed7`, version
> **1.1.2-1.21.1**, **4,474 entries**, `native-mod` on
> `0a875da…`/`e59da90…`. `cargo test` **4/4**, clippy/fmt clean, two
> `cmp`-identical builds, `check` and both `fits` runs EXIT 0,
> `verify-sdk-package.py` **1/1**, the in-game leg `PASS` + `EXIT:0` on a
> launcher-built game with `SELFTEST=1` and `CONTROL=1` at `EXIT:1`, and
> `check-e2e-logs.py xtonesreworked-e2e --strict` **4/4**. See `notes.md`,
> *Slice 4 — `flat_lamp` placement orientation*.

## Slice 4 ladder (2026-11-21, `0a875da` / `e59da90`)

Every step through `ports/tools/build-slot.sh` with `CARGO_INCREMENTAL=0`; the
package build and the in-game leg at the pin (`launcher-game.sh build
xtonesreworked` → `Compiling xtonesreworked (1 of 1)`).

| Check | Command | Result |
|---|---|---|
| Unit tests | `cargo test --offline` | `test result: ok. 4 passed; 0 failed` (`evidence/xtonesreworked/sdk-test.log`) |
| Lints | `cargo clippy --all-targets --offline -- -D warnings` | `CLIPPY_EXIT:0`, 0 warnings (`sdk-clippy.log`) |
| Formatting | `cargo fmt --check` | `FMT_EXIT:0` (`sdk-fmt.log`) |
| Reproducible | `rm -f Cargo.lock` + `cargo horizon-mod build` twice, `cmp` | the two builds **and** the delivered file are byte-identical (`build-first.log`, `build-second.log`, `cmp.txt`) |
| Package | `cargo horizon-mod check xtonesreworked.hmod` | `xtonesreworked 1.1.2-1.21.1 (native-mod, format native-1/0a875da…/e59da90…, for 26.3)`, 1,471,108 B, SHA-256 `2334f5e4…`, `CHECK_EXIT:0` (`sdk-check.log`) |
| Fits the pin | `cargo horizon-mod fits xtonesreworked.hmod --build 0a875da` | `0a875da  made for`, `FITS_PIN_EXIT:0` (`sdk-fits-0a875da.log`) |
| Fits another build | `cargo horizon-mod fits xtonesreworked.hmod --build 0b14f8a` | `0b14f8a  fits`, `FITS_OTHER_EXIT:0` (`sdk-fits-0b14f8a.log`) |
| Gate | `python3 ports/tools/verify-sdk-package.py xtonesreworked` | **1/1** |
| Content | `python3 tools/verify_content.py . <jar> …/evidence/xtonesreworked/carry/outside` | `PASS: every jar count matches…` (`verify-content.txt`) |
| In game | `tools/e2e.sh` on the launcher build | `PASS` + `EXIT:0` (`evidence/xtonesreworked-e2e/e2e-launcher.log`) |
| Counterfactual (phase) | `SELFTEST=1 tools/e2e.sh` | `FAIL: SELFTEST expected the pre-slice 'north'/'north', read 'south'/'east'`, `EXIT:1` |
| Control (no package) | `CONTROL=1 tools/e2e.sh` | `FAIL: setblock xtonesreworked:agon_block_0 failed`, `EXIT:1` |
| Focused leg | `tools/placement_probe.sh` | PASS on this package, and `EXPECT=north` fails (`EXIT:1`) — the same script that produced `placement-red.log` on the pre-slice package |
| Log gate | `python3 ports/tools/check-e2e-logs.py xtonesreworked-e2e --strict` | `logs=4 ok=4 missing-exit=0 bad-exit=0` |

## 2026-11-20 — content-only package at `0b14f8a` (history)

Content 3,357 files, 546 blocks, 580 recipes; `.hmod` 1,465,028 B SHA-256
`5952a007…`, `check` ok (`mod, API 0.2, both`, no code), `fits` not applicable
(content mod), e2e on the control Nightly `PASS` + `EXIT:0`, `NEGATIVE=1`
`EXIT:1`. Superseded by Slice 4, which adds the lamp's placement rule and moves
the package to `0a875da`.

## 2026-11-07/08 — the content carry (history)

`horizon-port-pack check`/`carry work` on the ATM10 jar, `verify_content.py`
counts, the first `.hmod` build and the shared-game e2e (`e2e-default.log`,
`e2e-negative.log` in `../_shared/evidence/xtonesreworked/`). The carry and its
hand patches are recorded in `notes.md`; nothing in this history was re-run for
Slice 4 because no content byte changed.
