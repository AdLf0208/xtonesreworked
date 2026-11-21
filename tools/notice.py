#!/usr/bin/env python3
"""Put the upstream licence notice inside a built `.hmod`.

`cargo-horizon-mod build` packs the manifest, `assets/`, `data/` and `src/` only,
and the loader ignores a root `LICENSE*` at runtime — but MIT requires the
copyright and permission notice to be included in all copies or substantial
portions of the software, and this package carries the mod's artwork. So the
notice files are added to the archive after the build.

The rewrite is deterministic: entries keep their order and metadata, the notice
files are appended with a fixed 1980-01-01 timestamp and deflate, so two runs on
the same build produce byte-identical archives (the ladder compares them with
`cmp`).

    python3 tools/notice.py xtonesreworked.hmod
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
#: Files shipped at the archive root, in this order.
NOTICE_FILES = ("LICENSE", "LICENSE-NOTICE.md")
#: Where the canonical copies live (outside the build's input, so a re-carry of
#: `assets/`/`data/` cannot delete them): the package root.
SOURCE = ROOT


def inject(hmod: pathlib.Path, source: pathlib.Path = SOURCE) -> dict[str, int]:
    """Rewrite `hmod` with the notice files appended; return the entry count."""
    existing: list[tuple[zipfile.ZipInfo, bytes]] = []
    with zipfile.ZipFile(hmod) as archive:
        for info in archive.infolist():
            existing.append((info, archive.read(info.filename)))
    names = {info.filename for info, _ in existing}
    added = 0
    for name in NOTICE_FILES:
        path = source / name
        if not path.is_file():
            raise SystemExit(f"{path}: missing (the notice must ship with the package)")
        if name in names:
            continue
        added += 1
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        info.create_system = 3
        existing.append((info, path.read_bytes()))
    tmp = hmod.with_suffix(".hmod.tmp")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as archive:
        for info, data in existing:
            archive.writestr(info, data)
    tmp.replace(hmod)
    return {"entries": len(existing), "added": added}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("hmod", type=pathlib.Path, nargs="?",
                        default=ROOT / "xtonesreworked.hmod")
    parser.add_argument("--source", type=pathlib.Path, default=SOURCE,
                        help="folder holding LICENSE / LICENSE-NOTICE.md")
    args = parser.parse_args(argv)
    result = inject(args.hmod, args.source)
    print(f"{args.hmod}: {result['entries']} entries, {result['added']} notice file(s) added")
    return 0


if __name__ == "__main__":
    sys.exit(main())
