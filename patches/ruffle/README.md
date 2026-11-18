# Ruffle terrain, camera, local checkpoints, and compact boss art

This optional patch builds a playable SWF from the published Ultimate Motherload v1.0 release. It targets the terrain slowdown reported in Ruffle desktop on CachyOS, particularly at full-width zoom. It also provides local checkpoints using the game's save station and title screen.

## Rebuild Lite

1. Start in a checkout containing this patch, or extract the patch kit and open a terminal in the folder containing `patches/`.
2. Download the **Ultimate_Motherload.swf** asset from the [original v1.0 release](https://github.com/jeremiah855/Ultimate_Motherload/releases/tag/v1.0). Put it beside the `patches/` folder. The builder checks its SHA-256 automatically.
3. Install Python 3 and Pillow 9.1 or newer. On CachyOS, `sudo pacman -S --needed python-pillow` installs Pillow for the system Python. Alternatively, use a virtual environment.

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install "Pillow>=9.1"
```

Build the game, then open the output in Ruffle desktop.

```sh
python3 patches/ruffle/build.py Ultimate_Motherload.swf Ultimate_Motherload_lite.swf
ruffle Ultimate_Motherload_lite.swf
```

The output path must be a new filename. If a previous build already exists, choose a different output name. Lite is the default.

| Boss art setting | Result with the tested encoder | Artwork |
| --- | ---: | --- |
| `--boss-art small` (default) | 17.6 MB | Half-resolution boss textures drawn at the original stage size |
| `--boss-art full` | 32.3 MB | Original texture dimensions and exact per-pixel alpha |
| `--boss-art original` | about 92.7 MB | Original embedded artwork, standard-library build |

Sizes use decimal MB. Exact encoded output can vary by Pillow, JPEG and zlib version. The downloads used Pillow 13.0.0.

The v1.0 input has SHA-256 `acc20979d29bbaae7157dc7d307785306f49b40c3a72e66a2ca5f6a9027db0fb`. The supplied Lite build has SHA-256 `d16a7d84dba9822d6189f7cbb79bf6020520e177e3119b6fd2b35a1b51060e74`.

## Recompile the ActionScript after an edit

The regular build reads `hooks.swf`, a small compiled copy of the edits in `src/`. To pick up changes to those sources, run the builder with Java and JPEXS Free Flash Decompiler 26.5.0. Replace the JAR path below with the location of your copy. This command builds the playable SWF and updates the compiled hooks for the next regular build.

```sh
python3 patches/ruffle/build.py Ultimate_Motherload.swf rebuilt.swf \
  --ffdec /path/to/ffdec.jar --export-hooks patches/ruffle/hooks.swf
```

The source package contains the patch and its build instructions. The game assets come from the player's copy of the release.

## Play

- Click Camera on the title screen or in Options to cycle Classic, 1.5×, 2×, and Full width. The existing zoom hotkeys also work. Options changes apply upon returning to play. A fresh profile starts in Classic, and camera choices persist locally.
- Fly into the floating save station and choose Yes to replace the local checkpoint. The game's existing Save and Quit handler also uses the local slot when invoked. Return to the title screen in Normal mode and click the built-in Continue. If you just earned continuation to the next level, that action takes priority in the current session. The seeded-mode title action still opens seed entry.
- A checkpoint returns the pod to the surface. It restores the mine, seed, cash, equipment, cargo, consumables, health, fuel, and transmission progress. Boss fights and unfinished digs must finish before saving. The speedrun split session restarts. Builds from the earlier checkpoint experiment use the same storage name and format when the Flash player grants the same storage scope.

## Implementation

- `boss_art.py` converts the 933 RGBA PNGs in the phase-three boss animation to DefineBitsJPEG3 with quality 82, 4:4:4 color, and a separately compressed alpha plane. The other six lossless frames stay in their original format. Lite pads the odd-height frames by one row before downsampling and doubles their bitmap fill scale. The shape outlines, registration, timeline and hitbox scripts retain their release definitions.
- Row and column updates calculate the camera origin once per pass. For a full-width redraw this reduces 3,276 tile-coordinate helper calls to two for the same 1,638 slots.

- `src/terrain.as` places graphic and collision sprites directly in their original layers, preserves stable slot depths, and clears recycled slots that scroll outside the map. It skips the 256 first-use searches for tunnel artwork by populating the game's eight-neighbor lookup table. Empty cells and terrain edges still use the original visual selection rules.
- `src/features.as` holds camera settings, local persistence, the save pod, and the Continue handler. Map cells are packed into column strings. Resume runs the original seeded generator to initialize game globals, then restores the saved terrain before drawing it.
- `build.py` verifies the release hash, exports the missing transparent tileEmpty symbol, injects frame actions, and prefixes the existing Continue release action with a checkpoint check. The original Continue handler is the fallback. Menu and gameplay render quality use the released game's logic.

| Camera | Terrain grid | Slots |
| --- | ---: | ---: |
| Classic | 13 × 10 | 130 |
| 1.5× | 30 × 27 | 810 |
| 2× | 41 × 31 | 1,271 |
| Full width | 39 × 42 | 1,638 |

The larger horizontal buffer at 2× supports horizontal streaming. Full width already covers the world horizontally. Slot counts describe the work area and do not directly predict frame time.

## Manual regression checks

1. Start a fresh profile, cycle cameras, move to both surface edges, and dig a vertical shaft. Inspect tunnel edges, collision, and the HUD when returning from a shop at each camera setting.
2. Save at the floating station after digging and buying an upgrade. Close the player, reopen, and click Continue. Verify equipment, cash, and the shaft.
3. Try the title screen without a checkpoint, seeded mode, and native continuation after completing a level. Check that new games still start normally.
4. Compare gameplay with and without the patch in the same Ruffle build at the same zoom and seed. Checkpoint writes are synchronous user actions, so do not include saving time in a movement benchmark.
5. Run phase three through its attacks, revival and defeat in desktop Ruffle. Compare the boss position, silhouette and attack timing at each art setting.
