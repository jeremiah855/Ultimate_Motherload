"""Build the community patch against the published v1.0 game. Python 3.8+."""
import argparse
import hashlib
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

import boss_art

HERE = Path(__file__).resolve().parent
RELEASE_HASH = "acc20979d29bbaae7157dc7d307785306f49b40c3a72e66a2ca5f6a9027db0fb"


def tag(code, payload):
    n = len(payload)
    header = struct.pack("<H", (code << 6) + min(n, 63))
    return header + (struct.pack("<I", n) if n >= 63 else b"") + payload


def unpack(raw):
    if raw[:3] == b"CWS":
        raw = b"FWS" + raw[3:8] + zlib.decompress(raw[8:])
    if raw[:3] != b"FWS" or len(raw) != struct.unpack_from("<I", raw, 4)[0]:
        raise ValueError("Invalid movie header")
    return raw


def tags(movie):
    offset = 12 + (5 + 4 * (movie[8] >> 3) + 7) // 8
    while offset < len(movie):
        start = offset
        header = struct.unpack_from("<H", movie, offset)[0]
        code, size = divmod(header, 64)
        offset += 2
        if size == 63:
            size = struct.unpack_from("<I", movie, offset)[0]
            offset += 4
        end = offset + size
        if end > len(movie):
            raise ValueError("Truncated SWF tag")
        yield code, movie[offset:end], start, end
        offset = end


def hook_sources():
    first = "\n".join((HERE / "src" / name).read_text() for name in ("terrain.as", "features.as"))
    actions = {
        1: first,
        2: "delete _root.ucCameraPending; ucMenu(true);",
        4: "ucEarnedContinuation=false;",
        5: "loadGameFlag=false;",
        6: "ucApplyCamera();",
        18: "ucMenu(false); saveAndQuit=function(){savePreferences(); ucSave(true);};",
        19: "if (satanDead && currentGameBehavior==0) { ucEarnedContinuation=true; }",
        20: """saveText.text="Save a local checkpoint?";
            save_BTNyesMC._visible=true; save_BTNnoMC._visible=true; save_BTNok2MC._visible=false;
            beginSave=function(){
                save_BTNyesMC._visible=false; save_BTNnoMC._visible=false;
                save_BTNok2MC._visible=true; ucSave(false);
            };""",
    }
    for frame in range(2, 26):
        actions[frame] = "if (ucToolbar != undefined) { ucToolbar.removeMovieClip(); }\n" + actions.get(frame, "")
    return actions


def compile_hooks(jar, header, destination):
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        actions = hook_sources()
        body = (tag(12, b"\0") + tag(1, b"")) * len(actions) + tag(0, b"")
        carrier = temp / "carrier.swf"
        carrier.write_bytes(b"FWS" + header[3:4] + struct.pack("<I", len(header)+len(body)) + header[8:] + body)
        for frame, source in actions.items():
            folder = temp / "import" / ("frame_%d" % frame)
            folder.mkdir(parents=True)
            (folder / "DoAction.as").write_text(source)
        subprocess.run(["java", "-jar", str(jar), "-importScript", str(carrier), str(destination), str(temp / "import")], check=True)


def continue_button(payload):
    # DefineButton2 2054 has one final release record. The existing handler
    # remains verbatim. If _root.ucContinue() handled the click, skip to End.
    record = 3 + struct.unpack_from("<H", payload, 3)[0]
    if payload[record:record+4] != bytes.fromhex("00000800") or payload[-1] != 0:
        raise ValueError("Unexpected Continue button structure")
    at = record + 4
    def action(opcode, data):
        return bytes([opcode]) + struct.pack("<H",len(data)) + data
    prefix = action(0x96, b"\x07\0\0\0\0\0_root\0") + b"\x1c"
    prefix += action(0x96, b"\0ucContinue\0") + b"\x52"
    prefix += action(0x9d, struct.pack("<h",len(payload)-at-1))
    return payload[:at] + prefix + payload[at:]


def build(args):
    raw = args.input.read_bytes()
    if hashlib.sha256(raw).hexdigest() != RELEASE_HASH:
        raise ValueError("Use the original v1.0 release SWF (see README)")
    movie = unpack(raw)
    header = movie[:next(tags(movie))[2]]
    hooks_path = HERE / "hooks.swf"
    with tempfile.TemporaryDirectory() as temp:
        if args.ffdec:
            hooks_path = Path(temp) / "hooks.swf"
            compile_hooks(args.ffdec, header, hooks_path)
            if args.export_hooks:
                args.export_hooks.write_bytes(hooks_path.read_bytes())
        hooks = [d for c,d,_,_ in tags(unpack(hooks_path.read_bytes())) if c == 12]
    if len(hooks) != 25 or b"ucContinue" not in hooks[0]:
        raise ValueError("Incomplete AVM1 hooks")
    encoded_ids = set()
    scaled_ids = set()
    out = bytearray(header)
    frame = 1
    inserted = set()
    changes = []
    for code, data, start, end in tags(movie):
        if frame not in inserted and (code == 1 or (frame == 6 and code == 12)):
            out.extend(tag(12,hooks[frame-1]))
            inserted.add(frame)
        if code == 34 and data[:2] == struct.pack("<H",2054):
            out.extend(tag(code,continue_button(data)))
            changes.append("button")
        elif args.boss_art != "original" and boss_art.is_boss_png(code, data):
            out.extend(tag(35, boss_art.encode_boss_png(data, args.boss_art == "small")))
            encoded_ids.add(int.from_bytes(data[:2], "little"))
        elif args.boss_art == "small" and code == 2 and int.from_bytes(data[:2], "little") - 1000 in encoded_ids:
            out.extend(tag(code, boss_art.scale_bitmap_fill(data)))
            scaled_ids.add(int.from_bytes(data[:2], "little") - 1000)
        else:
            out.extend(movie[start:end])
        if code == 39 and data[:2] == struct.pack("<H",1092):
            out.extend(tag(39,struct.pack("<HHHH",65000,1,64,0)))
            changes.append("sprite")
        if code == 56 and struct.pack("<H",1092)+b"tileBlank\0" in data:
            out.extend(tag(56,struct.pack("<HH",1,65000)+b"tileEmpty\0"))
            changes.append("export")
        if code == 1:
            frame += 1
    if sorted(changes) != ["button","export","sprite"] or inserted != set(range(1,26)):
        raise ValueError("Unexpected release layout")
    if args.boss_art != "original" and len(encoded_ids) != boss_art.PNG_FRAME_COUNT:
        raise ValueError("Unexpected number of boss PNGs")
    if args.boss_art == "small" and scaled_ids != encoded_ids:
        raise ValueError("Missing shapes for scaled boss frames")
    out[4:8] = struct.pack("<I",len(out))
    result = b"CWS" + out[3:8] + zlib.compress(out[8:],6)
    if unpack(result) != out:
        raise ValueError("Output verification failed")
    with args.output.open("xb") as handle:
        handle.write(result)
    print("Built",args.output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path, help="new output path")
    parser.add_argument("--ffdec", type=Path, help="compile readable sources with FFDec 26.5.0")
    parser.add_argument("--export-hooks", type=Path, help="save the recompiled hooks alongside the source")
    parser.add_argument("--boss-art", choices=("small","full","original"), default="small",
                        help="half-resolution textures, native-resolution JPEGs, or original data")
    args = parser.parse_args()
    if args.boss_art != "original":
        try:
            from PIL import Image
        except ImportError:
            parser.error("compact art requires Pillow (python -m pip install Pillow), or use --boss-art original")
    if args.export_hooks and not args.ffdec:
        parser.error("--export-hooks requires --ffdec")
    build(args)
