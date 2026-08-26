#!/usr/bin/env python3
"""Build the photo-library pack a camera roll of real photographs, from Pexels.

    PEXELS_API_KEY=… python3 libraryfetch.py [out-dir]

Default out-dir is the stage's fixture folder:
    ~/Library/Application Support/LFMTools/toolbench-fixtures/photo-library
Push the same folder to a phone with `devicectl device copy to`; the pack
reads it from Documents/toolbench-fixtures/photo-library on either machine.

**What is invented here and what is measured.** Everything in SHOTS below —
dates, places, albums, favourites, and which photos a person is tagged in — is
metadata, and metadata is invented by definition: no pixel carries the day it
was taken or the name of the woman in it. Everything *about the picture* is
left blank on purpose and filled at index time by the OS
(`PhotoLibraryBox.indexFixtures()`): what it shows, the words written in it,
whether a face is there, how much edge detail it has, and which photos are the
same shot twice. Do not write `looks` into this file. The whole point of the
rung is that nobody did.

**Choosing the photos.** They were looked at, not picked off a search result:
`shop.py`-style contact sheets, then chosen for what each rung needs —

  faces        four portraits of one woman from a single shoot (Pexels IDs
               within one upload batch is a reliable "same model" signal), plus
               two of a second woman by the sea. Vision detects the face; the
               name is this file's.
  OCR          a COFFEE sign and a chalkboard menu, where a viewer can read the
               words off the screen and check the tool against their own eyes.
  the index    beaches, temples, ramen, neon streets — the scene nouns
               VNClassify actually produces.
  the embedding a dog on sand, for the query whose words the label shelf has no
               token for ("a puppy running on the sand" — the shelf holds
               `dog`).
  duplicates   two frames from one portrait shoot, which is what a burst is.
  softness     one deliberately motion-blurred street.
  the empty answer **no cat anywhere**, so "any photos of a cat?" has an honest
               no to give. Keep it that way.

Licence: Pexels, free to use, attribution not required — the credits printed at
the end exist because a fixture nobody can trace is a fixture nobody should
publish. Photos are not committed; this script and the IDs are the record.
"""
import json
import os
import subprocess
import sys
import urllib.request

KEY = os.environ.get("PEXELS_API_KEY")
OUT = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.expanduser(
        "~/Library/Application Support/LFMTools/toolbench-fixtures/photo-library")
)

# id, pexels id, date, place, album, favourite, people
SHOTS = [
    # Last summer at the sea — the composition case's other half ("the beach
    # photos from last summer" is neither clause alone; there are beaches in
    # 2026 too).
    # Cast against the shelf, not against a human eye: of the first six beach
    # photos chosen by looking, exactly one produced a `beach` or `ocean`
    # label, and "the beach photos" would have found one picture out of five.
    # These were scouted before they were kept.
    (1, 2877819, "2025-07-21", "Kamakura", None, False, []),
    (2, 4603232, "2025-07-21", "Kamakura", None, True, []),
    (3, 6773781, "2025-08-02", "Kamakura", None, False, []),
    (4, 14958840, "2025-08-02", "Kamakura", None, True, []),
    (5, 18254571, "2025-08-03", "Kamakura", None, False, []),
    (28, 30310146, "2025-08-16", "Kamakura", None, False, []),
    # The Kyoto trip, in an album.
    (6, 33229939, "2025-11-23", "Kyoto", "Kyoto trip", True, []),
    (7, 6249542, "2025-11-23", "Kyoto", "Kyoto trip", False, []),
    (8, 35323182, "2025-11-24", "Kyoto", "Kyoto trip", False, []),
    (9, 37989665, "2025-11-24", "Kyoto", "Kyoto trip", False, []),
    (10, 5745777, "2025-11-25", "Kyoto", "Kyoto trip", False, []),
    # Winter, and the one city that is not Tokyo.
    (11, 15819943, "2026-01-11", "Sapporo", None, False, []),
    (12, 20002959, "2026-01-12", "Sapporo", None, False, []),
    # Tokyo nights — and the signage the OCR rung reads.
    (13, 30780336, "2026-02-14", "Tokyo", None, False, []),
    (14, 18867525, "2026-02-14", "Tokyo", None, True, []),
    (15, 30933060, "2026-02-15", "Tokyo", None, False, []),
    # A second person, by the sea, out of season: the face rung has to be more
    # than one name or it is a lookup table with one row.
    (16, 23643801, "2026-03-08", "Kamakura", None, False, ["Aoi"]),
    (17, 23643824, "2026-03-08", "Kamakura", None, False, ["Aoi"]),
    # Ramen, twice, months apart.
    (18, 31393431, "2026-04-05", "Tokyo", None, False, []),
    (19, 29536737, "2026-05-16", "Tokyo", None, False, []),
    (20, 12984982, "2026-05-16", "Tokyo", None, False, []),
    # One shoot, one person, four frames — the face rung, and the burst the
    # duplicate rung is for.
    (21, 35555178, "2026-06-06", "Tokyo", "Family", False, ["Mei"]),
    (22, 35555194, "2026-06-06", "Tokyo", "Family", False, ["Mei"]),
    (23, 35555299, "2026-06-06", "Tokyo", "Family", True, ["Mei"]),
    (24, 35555305, "2026-06-06", "Tokyo", "Family", False, ["Mei"]),
    # Words a viewer can read off the screen and check by eye.
    (25, 175711, "2026-07-04", "Tokyo", None, False, []),
    (26, 34164441, "2026-07-04", "Tokyo", None, False, []),
    # The one that came out badly. Every camera roll has one.
    (27, 4954, "2026-07-19", "Tokyo", None, False, []),
]


def photo(pexels_id):
    request = urllib.request.Request(
        f"https://api.pexels.com/v1/photos/{pexels_id}",
        headers={"Authorization": KEY, "User-Agent": "edge-agent-lab/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    if not KEY:
        sys.exit("PEXELS_API_KEY is not set")
    os.makedirs(OUT, exist_ok=True)
    manifest, credits = [], []
    for number, pexels_id, date, place, album, favorite, people in SHOTS:
        meta = photo(pexels_id)
        name = f"{number:02d}.jpg"
        path = os.path.join(OUT, name)
        if not os.path.exists(path):
            # large2x, not original: ~1900 px is past what any rung needs and
            # keeps a 27-photo library inside ten megabytes, which is what a
            # phone push is measured in.
            subprocess.run(["curl", "-sL", "-o", path, meta["src"]["large2x"]], check=True)
        row = {
            "id": number, "file": name, "date": date, "place": place,
            "favorite": favorite, "people": people,
            "source": f"pexels:{pexels_id} by {meta['photographer']}",
        }
        if album:
            row["album"] = album
        manifest.append(row)
        credits.append(f"  #{number:02d} pexels {pexels_id} — {meta['photographer']} — {meta['url']}")
    with open(os.path.join(OUT, "library.json"), "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"wrote {len(manifest)} photos + library.json to {OUT}")
    print("\ncredits (Pexels licence — attribution not required, traceability is):")
    print("\n".join(credits))
    print("\nscout what the shelf says about them:")
    print(f"  xcrun swift libraryscout.swift '{OUT}'")


if __name__ == "__main__":
    main()
