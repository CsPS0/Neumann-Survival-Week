"""Where the built school is cut off: which open rooms a walker cannot reach from the spawn.

Run from ROBLOX-GAME/:
    lune run tools/school-dryrun -- --obstacles <dir>/obstacles.json
    python tools/map-editor/reach.py <dir>/obstacles.json [<dir>]

Uses the real built geometry (from the dry run): floors to stand on, everything collidable at body height (walls,
furniture, lockers), door panels count as open unless locked. Free floor is shrunk by a walker's radius, joined
across floors through the stairwells and flooded from the spawn. Prints the open rooms nobody can reach and, with an
output folder, draws reach-<floor>.png per floor (green: reachable, red: walkable but cut off, dark: blocked).

With REACH_KEYED=1 it checks the story's key locks (src/server/Campaign/Keys.luau): every classroom, computer room
and gym with a single way in is locked except the story's rooms (the day's lessons are counted as locked too, the
worst case). Every other open room must stay reachable, and every locked room's door must be reachable from outside.
"""
import json
import re
import sys
from collections import deque

import numpy as np

CELL = 0.1  # metres
RADIUS = float(__import__("os").environ.get("REACH_RADIUS", "0.45"))  # a walker's half width (Roblox pathfinding: 1.5 studs = 0.5 m)
ORIGIN = [(42.6, 21.9), (20.3, 21.9), (20.3, 21.9)]  # plan point at world 0,0 per floor (import-map.luau)
OPEN_TYPES = {"classroom", "it", "lab", "office", "library", "wc", "gym", "changing", "entrance", "dining",
              "kitchen", "storage", "medical"}
KEYED_TYPES = {"classroom", "it", "gym"}  # KeyRules.KEYED: normal, computer, gym
# CampaignData.STORY and AFTER_ROOMS: open all story long.
STORY_ROOMS = {(0, "24"), (2, "229"), (0, "14"), (0, "33"), (2, "205"), (2, "GT8"), (1, "114")}
KEYED = __import__("os").environ.get("REACH_KEYED") == "1"


def main():
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    out_dir = sys.argv[2] if len(sys.argv) > 2 else None
    plan = json.load(open("tools/map-editor/school-map.json", encoding="utf-8"))
    fh = data["floorHeight"]
    parts = data["parts"]
    xs = [p["x0"] for p in parts] + [p["x1"] for p in parts]
    zs = [p["z0"] for p in parts] + [p["z1"] for p in parts]
    gx0, gz0 = min(xs) - 1, min(zs) - 1
    nx, nz = int((max(xs) + 1 - gx0) / CELL) + 1, int((max(zs) + 1 - gz0) / CELL) + 1

    def idx(x, z):
        return int(round((x - gx0) / CELL)), int(round((z - gz0) / CELL))

    def fill(grid, p):
        i0, k0 = idx(p["x0"], p["z0"])
        i1, k1 = idx(p["x1"], p["z1"])
        grid[max(i0, 0):max(i1, 0), max(k0, 0):max(k1, 0)] = True

    r = int(np.ceil(RADIUS / CELL))
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    disk = (xx * xx + yy * yy) <= r * r

    def dilate(grid):
        out = np.zeros_like(grid)
        for di, dk in zip(*np.nonzero(disk)):
            di -= r
            dk -= r
            src = grid[max(0, -di):nx - max(0, di), max(0, -dk):nz - max(0, dk)]
            out[max(0, di):max(0, di) + src.shape[0], max(0, dk):max(0, dk) + src.shape[1]] |= src
        return out

    floors = len(plan["floors"])
    keyed = set()
    if KEYED:
        for f, fl in enumerate(plan["floors"]):
            for room in fl["rooms"]:
                label = room.get("label") or ""
                ways = len(re.findall(r"[A-Za-z][\d.]*", room.get("doors") or ""))
                if label and room.get("type") in KEYED_TYPES and ways == 1 and (f, label) not in STORY_ROOMS:
                    keyed.add((f, label))
    walk = []
    for f in range(floors):
        base = f * fh
        floor_g = np.zeros((nx, nz), bool)
        block_g = np.zeros((nx, nz), bool)
        for p in parts:
            if p["k"] == "door" and not p.get("locked") and (p.get("floor"), p.get("room")) not in keyed:
                continue
            if base - 0.35 <= p["y1"] <= base + 0.35 and p["y1"] - p["y0"] < 1.0:
                fill(floor_g, p)
            if p["y0"] < base + 1.8 and p["y1"] > base + 0.4 and p["n"] not in ("Step", "Ramp"):
                fill(block_g, p)
        w = floor_g & ~dilate(block_g)
        # Stairwells join the floors: walkable on every floor.
        for s in data["stairs"]:
            i0, k0 = idx(s["x0"], s["z0"])
            i1, k1 = idx(s["x1"], s["z1"])
            w[i0:i1, k0:k1] = True
        walk.append(w)

    # Flood from the spawn; a stairwell cell reached on one floor is reached on all floors.
    seen = [np.zeros((nx, nz), bool) for _ in range(floors)]
    stair_mask = np.zeros((nx, nz), bool)
    for s in data["stairs"]:
        i0, k0 = idx(s["x0"], s["z0"])
        i1, k1 = idx(s["x1"], s["z1"])
        stair_mask[i0:i1, k0:k1] = True
    si, sk = idx(data["spawn"]["x"], data["spawn"]["z"])
    q = deque([(0, si, sk)])
    seen[0][si, sk] = True
    while q:
        f, i, k = q.popleft()
        nbrs = [(f, i + 1, k), (f, i - 1, k), (f, i, k + 1), (f, i, k - 1)]
        if stair_mask[i, k]:
            nbrs += [(g, i, k) for g in range(floors) if g != f]
        for g, a, b in nbrs:
            if 0 <= a < nx and 0 <= b < nz and walk[g][a, b] and not seen[g][a, b]:
                seen[g][a, b] = True
                q.append((g, a, b))

    cut = []
    for f, fl in enumerate(plan["floors"]):
        ox, oz = ORIGIN[f]
        for room in fl["rooms"]:
            if room.get("type") not in OPEN_TYPES or not room.get("label") or (f, room["label"]) in keyed:
                continue
            x0, x1 = sorted(((room["x0"] - ox), (room["x1"] - ox)))
            z0, z1 = sorted(((room["y0"] - oz), (room["y1"] - oz)))
            i0, k0 = idx(x0, z0)
            i1, k1 = idx(x1, z1)
            region_w = walk[f][i0:i1, k0:k1]
            region_s = seen[f][i0:i1, k0:k1]
            if region_w.any() and not region_s.any():
                cut.append(f"{f}:{room['label']}")
            elif not region_w.any():
                cut.append(f"{f}:{room['label']} (no walkable floor)")
    print("cut off:", ", ".join(cut) if cut else "none")
    lost = []
    for p in data.get("patrol", []):
        f = min(range(floors), key=lambda g: abs(p["y"] - g * fh))
        i, k = idx(p["x"], p["z"])
        r0 = int(0.6 / CELL)
        if not seen[f][max(i - r0, 0):i + r0 + 1, max(k - r0, 0):k + r0 + 1].any():
            lost.append(f"{f}:({p['x']:.1f}, {p['z']:.1f})")
    print("patrol points nobody reaches:", ", ".join(lost) if lost else "none")
    if KEYED:
        shut = []
        for p in parts:
            key = (p.get("floor"), p.get("room"))
            if p["k"] == "door" and key in keyed:
                i0, k0 = idx(min(p["x0"], p["x1"]) - 0.8, min(p["z0"], p["z1"]) - 0.8)
                i1, k1 = idx(max(p["x0"], p["x1"]) + 0.8, max(p["z0"], p["z1"]) + 0.8)
                if not seen[key[0]][max(i0, 0):i1, max(k0, 0):k1].any():
                    shut.append(f"{key[0]}:{key[1]}")
        print(f"keyed rooms: {len(keyed)}; doors nobody can reach:", ", ".join(sorted(set(shut))) if shut else "none")

    if out_dir:
        from PIL import Image, ImageDraw
        for f, fl in enumerate(plan["floors"]):
            img = np.zeros((nz, nx, 3), np.uint8)
            img[:] = (30, 30, 34)
            w, s = walk[f].T, seen[f].T
            img[w & ~s] = (200, 50, 50)
            img[s] = (70, 170, 90)
            im = Image.fromarray(img).resize((nx * 2, nz * 2), Image.NEAREST)
            dr = ImageDraw.Draw(im)
            ox, oz = ORIGIN[f]
            for room in fl["rooms"]:
                x0, x1 = sorted(((room["x0"] - ox), (room["x1"] - ox)))
                z0, z1 = sorted(((room["y0"] - oz), (room["y1"] - oz)))
                i0, k0 = idx(x0, z0)
                i1, k1 = idx(x1, z1)
                dr.rectangle([i0 * 2, k0 * 2, i1 * 2, k1 * 2], outline=(150, 150, 220))
                dr.text((i0 * 2 + 3, k0 * 2 + 2), room.get("label") or "", fill=(255, 255, 255))
            im.save(f"{out_dir}/reach-{f}.png")


if __name__ == "__main__":
    main()
