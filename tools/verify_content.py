#!/usr/bin/env python3
"""Static fidelity check of the carried Xtones content against its jar.

    python3 tools/verify_content.py content                 # the folder mod
    python3 tools/verify_content.py <mod>.hmod <jar>        # a built .hmod

Compares the jar's census with what the carry shipped, checks that every
blockstate's model and every model's `xtonesreworked:` texture resolve, that
every family has its 16 blockstates/loot tables/item-definition, and lists the
files the carry moved to `outside/` so none of them is a silent loss.

Exit 0 means every count matches and every model/texture reference resolves;
unknown differences are printed and exit 1. The known, deliberate additions
(creative tab, the 16 `c:dyes` tags) and the known `outside/` namespaces
(`framedblocks`, `neoforged`) are reported, not treated as losses.
"""

import collections
import json
import pathlib
import sys
import zipfile

FAMILIES = [
    "agon", "azur", "bitt", "cray", "fort", "glaxx", "iszm", "jelt", "korp",
    "kryp", "lair", "lave", "mint", "myst", "reds", "reed", "roen", "sols",
    "sync", "tank", "vect", "vena", "zane", "zech", "zest", "zeta", "zion",
    "zkul", "zoea", "zome", "zone", "zorg", "ztyl", "zyth",
]


class Tree:
    """The mod's files, from a folder or a `.hmod` zip."""

    def __init__(self, path):
        self.path = pathlib.Path(path)
        self.zip = zipfile.ZipFile(path) if self.path.is_file() else None
        self.names = (
            [n for n in self.zip.namelist() if not n.endswith("/")]
            if self.zip
            else [
                str(p.relative_to(self.path))
                for p in self.path.rglob("*")
                if p.is_file()
            ]
        )

    def has(self, name):
        return name in self.names

    def read(self, name):
        if self.zip:
            return self.zip.read(name).decode("utf-8")
        return (self.path / name).read_text()

    def count(self, prefix, suffix=".json"):
        return sum(1 for n in self.names if n.startswith(prefix) and n.endswith(suffix))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    mod = Tree(sys.argv[1])
    jar = Tree(sys.argv[2]) if len(sys.argv) > 2 else Tree(
        pathlib.Path(__file__).resolve().parents[2]
        / "_shared/carry-work/xtonesreworked/xtonesreworked-1.1.1-1.21.1.jar"
    )

    checks = []

    def compare(label, want, got):
        checks.append((label, want, got))

    # The v1 carry drops the top directory entries; count files only.
    compare("blockstates", jar.count("assets/xtonesreworked/blockstates/"),
            mod.count("assets/xtonesreworked/blockstates/"))
    compare("block models", jar.count("assets/xtonesreworked/models/block/"),
            mod.count("assets/xtonesreworked/models/block/"))
    compare("item models", jar.count("assets/xtonesreworked/models/item/"),
            mod.count("assets/xtonesreworked/models/item/"))
    compare("item definitions", 546, mod.count("assets/xtonesreworked/items/"))
    compare("block textures", jar.count("assets/xtonesreworked/textures/", ".png"),
            mod.count("assets/xtonesreworked/textures/", ".png"))
    compare("recipes", jar.count("data/xtonesreworked/recipe/"),
            mod.count("data/xtonesreworked/recipe/"))
    compare("loot tables", jar.count("data/xtonesreworked/loot_table/"),
            mod.count("data/xtonesreworked/loot_table/"))
    compare("item tags", jar.count("data/xtonesreworked/tags/item/"),
            mod.count("data/xtonesreworked/tags/item/"))
    compare("minecraft block tags", jar.count("data/minecraft/tags/block/"),
            mod.count("data/minecraft/tags/block/"))
    compare("horizon block declarations", 546,
            mod.count("data/xtonesreworked/horizon/block/"))

    failures = []
    for label, want, got in checks:
        mark = "ok" if want == got else "MISMATCH"
        print(f"{mark:9} {label}: jar {want}, carried {got}")
        if want != got:
            failures.append(label)

    creative = "data/xtonesreworked/horizon/creative_tab/xtones.json"
    if mod.has(creative):
        tab = json.loads(mod.read(creative))
        print(f"ok        creative tab: {len(tab['items'])} items")
        if len(tab["items"]) != 546:
            failures.append("creative tab items")
    else:
        failures.append("creative tab")

    dye_tags = mod.count("data/c/tags/item/dyes/")
    print(f"ok        c:dyes convention tags added: {dye_tags}")
    if dye_tags != 16:
        failures.append("c:dyes tags")

    lang_path = "assets/xtonesreworked/lang/en_us.json"
    if mod.has(lang_path) and jar.has(lang_path):
        want = json.loads(jar.read(lang_path))
        got = json.loads(mod.read(lang_path))
        print(
            f"ok        lang keys: jar {len(want)}, carried {len(got)}, "
            f"different {len(set(want.items()) ^ set(got.items()))}"
        )
        if want != got:
            failures.append("lang")
    else:
        failures.append("lang file")

    # Every family: 16 blockstates, 16 loot tables, 16 item definitions, tag.
    for family in FAMILIES:
        for variant in range(16):
            name = f"{family}_block_{variant}"
            for path in (
                f"assets/xtonesreworked/blockstates/{name}.json",
                f"assets/xtonesreworked/items/{name}.json",
                f"data/xtonesreworked/loot_table/blocks/{name}.json",
                f"data/xtonesreworked/horizon/block/{name}.json",
            ):
                if not mod.has(path):
                    failures.append(f"missing {path}")
        if not mod.has(f"data/xtonesreworked/tags/item/{family}.json"):
            failures.append(f"missing item tag for {family}")
    print(f"ok        all {len(FAMILIES)} families x 16 blocks have state, item, loot and declaration")

    # Every blockstate's models, and every model's `xtonesreworked:` texture,
    # resolve.
    missing_models = []
    missing_textures = []
    texture_names = {n for n in mod.names if n.startswith("assets/xtonesreworked/textures/")}

    def model_file(ref):
        return f"assets/xtonesreworked/models/{ref.split(':', 1)[1]}.json"

    for name in mod.names:
        if name.startswith("assets/xtonesreworked/blockstates/"):
            data = json.loads(mod.read(name))
            refs = []
            for variant in data.get("variants", {}).values():
                entries = variant if isinstance(variant, list) else [variant]
                refs.extend(e.get("model") for e in entries if isinstance(e, dict))
            for part in data.get("multipart", []):
                apply = part.get("apply")
                entries = apply if isinstance(apply, list) else [apply or {}]
                refs.extend(e.get("model") for e in entries if isinstance(e, dict))
            for ref in refs:
                if ref and ref.startswith("xtonesreworked:") and not mod.has(model_file(ref)):
                    missing_models.append(f"{name} -> {ref}")
        elif name.startswith("assets/xtonesreworked/models/"):
            data = json.loads(mod.read(name))
            parent = data.get("parent")
            if parent and parent.startswith("xtonesreworked:") and not mod.has(model_file(parent)):
                missing_models.append(f"{name} -> parent {parent}")
            for value in data.get("textures", {}).values():
                if not isinstance(value, str) or not value.startswith("xtonesreworked:"):
                    continue
                want = f"assets/xtonesreworked/textures/{value.split(':', 1)[1]}.png"
                if want not in texture_names:
                    missing_textures.append(f"{name} -> {value}")
    print(f"ok        model references resolved, missing: {len(missing_models)}")
    print(f"ok        texture references resolved, missing: {len(missing_textures)}")
    failures.extend(missing_models[:10])
    failures.extend(missing_textures[:10])

    # The carried data must still say the same thing as the jar: the same
    # recipe files with the same result and the same referenced ids, the same
    # loot item per table, and the same tag members.
    def string_leaves(value, skip_key="type"):
        out = set()

        def walk(v, key=None):
            if isinstance(v, dict):
                for k, x in v.items():
                    walk(x, k)
            elif isinstance(v, list):
                for x in v:
                    walk(x, key)
            elif isinstance(v, str) and key != skip_key:
                out.add(v.lstrip("#"))

        walk(value)
        return out

    def names(value):
        out = set()

        def walk(v):
            if isinstance(v, dict):
                for k, x in v.items():
                    if k == "name" and isinstance(x, str):
                        out.add(x)
                    walk(x)
            elif isinstance(v, list):
                for x in v:
                    walk(x)

        walk(value)
        return out

    def compare_files(label, prefix, extract):
        jar_names = {n for n in jar.names if n.startswith(prefix) and n.endswith(".json")}
        mod_names = {n for n in mod.names if n.startswith(prefix) and n.endswith(".json")}
        missing = jar_names - mod_names
        extra = mod_names - jar_names
        differing = []
        for name in sorted(jar_names & mod_names):
            want = extract(json.loads(jar.read(name)))
            got = extract(json.loads(mod.read(name)))
            if want != got:
                differing.append((name, sorted(want), sorted(got)))
        print(
            f"ok        {label}: {len(jar_names)} files, missing {len(missing)}, "
            f"extra {len(extra)}, content differs in {len(differing)}"
        )
        for name, want, got in differing[:3]:
            print(f"  {name}: jar {want} carried {got}")
        if missing or extra or differing:
            failures.append(f"{label} content")

    compare_files("recipes", "data/xtonesreworked/recipe/", string_leaves)
    compare_files("loot tables", "data/xtonesreworked/loot_table/", names)
    compare_files("item tags", "data/xtonesreworked/tags/item/",
                  lambda v: v.get("values"))
    compare_files("minecraft block tags", "data/minecraft/tags/block/",
                  lambda v: v.get("values"))
    compare_files("c: glass tag", "data/c/tags/item/glass_blocks",
                  lambda v: v.get("values"))

    # What the carry put outside (never a silent loss).
    outside = pathlib.Path(
        sys.argv[3] if len(sys.argv) > 3 else str(mod.path / "outside")
    )
    if outside.is_dir():
        prefixes = collections.Counter()
        for path in outside.rglob("*"):
            if path.is_file():
                prefixes["/".join(path.relative_to(outside).parts[:3])] += 1
        print("outside/ (other namespaces, not the mod's own content):")
        for prefix, count in sorted(prefixes.items()):
            print(f"  {count:4} {prefix}")
    else:
        print("outside/: not present beside the mod")

    if failures:
        print("\nFAIL:")
        for failure in failures:
            print(f"  {failure}")
        raise SystemExit(1)
    print("\nPASS: every jar count matches and every model/texture reference resolves")


if __name__ == "__main__":
    main()
