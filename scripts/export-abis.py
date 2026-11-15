#!/usr/bin/env python3
"""Export reproducible application ABIs after `forge build`; no network or third-party Python packages."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if committed ABIs differ from build artifacts")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    names = ("WishGardenBurnSink", "WishGardenTreasury", "WishGarden")
    for name in names:
        artifact = root / "out" / f"{name}.sol" / f"{name}.json"
        if not artifact.is_file():
            raise SystemExit(f"Missing {artifact.relative_to(root)}; run forge build first.")
        data = json.loads(artifact.read_text())
        bytecode = data["bytecode"]["object"]
        if "__" in bytecode or data["bytecode"].get("linkReferences"):
            raise SystemExit(f"{name}: unexpected external library linkage")
        encoded = json.dumps(data["abi"], indent=2) + "\n"
        target = root / "docs" / "abi" / f"{name}.json"
        if args.check:
            if not target.is_file() or target.read_text() != encoded:
                raise SystemExit(f"ABI differs: {target.relative_to(root)}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(encoded)
        print(f"{'Checked' if args.check else 'Exported'} {target.relative_to(root)}")


if __name__ == "__main__":
    main()
