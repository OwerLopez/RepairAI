"""Acquire pinned CISUTAC exports into an ignored local directory."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import time
from urllib.request import Request, urlopen


HOST = "https://huggingface.co"
SOURCES = {
    "holes": ("Garment_condition_holes", "3b81cb807188690222ef2a6af9cbfd2271292a32"),
    "spots": ("Garment_condition_spots", "3483dfb0336564b626e811437e802bf56a2dca68"),
}
RESOURCE = re.compile(r"(train|valid)/(images|labels)/[\w.-]+\.(jpg|txt)")


def get(url):
    for attempt in range(4):
        try:
            with urlopen(Request(url, headers={"User-Agent": "ReparaAI-research/0.1"}), timeout=45) as response:
                return response.read(), response.headers.get("Link", "")
        except OSError:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)


def acquire(kind, root, inventory_only):
    name, revision = SOURCES[kind]
    repo = f"wargoninnovation/{name}"
    next_page = f"{HOST}/api/datasets/{repo}/tree/{revision}?recursive=true"
    files = []
    while next_page:
        body, links = get(next_page)
        files.extend(entry for entry in json.loads(body) if RESOURCE.fullmatch(entry["path"]))
        match = re.search(r'<([^>]+)>\s*;\s*rel="next"', links)
        next_page = match.group(1) if match else None
    counts = {
        f"{split}/{category}": sum(entry["path"].startswith(f"{split}/{category}/") for entry in files)
        for split in ("train", "valid")
        for category in ("images", "labels")
    }
    print(kind, revision, counts, flush=True)
    if inventory_only:
        return

    def download(entry):
        relative = entry["path"]
        path = root / kind / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        lfs = entry.get("lfs")
        if path.exists() and path.stat().st_size == entry["size"]:
            local = path.read_bytes()
            if not lfs or hashlib.sha256(local).hexdigest() == lfs["oid"]:
                return
        content, _ = get(f"{HOST}/datasets/{repo}/resolve/{revision}/{relative}")
        if len(content) != entry["size"] or (lfs and hashlib.sha256(content).hexdigest() != lfs["oid"]):
            raise ValueError(f"Source checksum or size mismatch for {relative}")
        path.write_bytes(content)

    with ThreadPoolExecutor(max_workers=12) as pool:
        for index, _ in enumerate(pool.map(download, files), 1):
            if index % 200 == 0:
                print(f"{kind}: {index}/{len(files)} files", flush=True)
    (root / kind / "source.json").write_text(
        json.dumps({"repo": repo, "revision": revision, "license": "CC BY 4.0", "counts": counts}, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(".data"))
    parser.add_argument("--kind", choices=SOURCES, default="holes")
    parser.add_argument("--inventory-only", action="store_true")
    args = parser.parse_args()
    acquire(args.kind, args.root, args.inventory_only)
