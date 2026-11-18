"""Encode the v1.0 phase-three animation as native SWF JPEGs with lossless alpha."""
import io
import struct
import zlib

FIRST_FRAME = 32000
LAST_FRAME = 32938
PNG_FRAME_COUNT = 933


def is_boss_png(code, data):
    return code == 21 and FIRST_FRAME <= int.from_bytes(data[:2], "little") <= LAST_FRAME


def encode_boss_png(data, small):
    from PIL import Image

    with Image.open(io.BytesIO(data[2:])) as frame:
        if frame.format != "PNG" or frame.mode != "RGBA":
            raise ValueError("Unexpected boss frame format")
        if small:
            frame = half_resolution(frame)
        alpha = frame.getchannel("A").tobytes()
        color = io.BytesIO()
        # JPEG3 stores premultiplied color. Straight RGB creates bright halos
        # around translucent fire and lightning in the player.
        premultiplied = frame.convert("RGBa")
        rgb = Image.merge("RGB", premultiplied.split()[:3])
        rgb.save(color, "JPEG", quality=82, subsampling=0, optimize=True)
    jpeg = color.getvalue()
    return data[:2] + struct.pack("<I", len(jpeg)) + jpeg + zlib.compress(alpha, 9)


def half_resolution(frame):
    from PIL import Image

    # The three frame sizes all have even widths and odd heights. Duplicate
    # the last row so that one new texel always spans exactly 2x2 old pixels.
    width, height = frame.size
    if width % 2 or height % 2 != 1:
        raise ValueError("Unexpected boss frame dimensions")
    padded = Image.new("RGBA", (width, height + 1))
    padded.paste(frame)
    padded.paste(frame.crop((0, height - 1, width, height)), (0, height))
    return padded.resize((width // 2, (height + 1) // 2), Image.Resampling.LANCZOS)


def scale_bitmap_fill(shape):
    # Only the bitmap sampling matrix changes. The same SWF shape still
    # occupies its original stage rectangle with its original registration.
    bitmap_id = int.from_bytes(shape[:2], "little") - 1000
    rect_bytes = (5 + 4 * (shape[2] >> 3) + 7) // 8
    fill = 2 + rect_bytes
    header = b"\x01\x41" + struct.pack("<H", bitmap_id)
    if shape[fill:fill + 4] != header:
        raise ValueError("Unexpected boss bitmap fill")
    matrix = fill + 4
    # SWF MATRIX: scale=20 twips per texel, no rotation or translation.
    native = bitmap_matrix(20)
    if shape[matrix:matrix + len(native)] != native:
        raise ValueError("Unexpected boss bitmap transform")
    return shape[:matrix] + bitmap_matrix(40) + shape[matrix + len(native):]


def bitmap_matrix(twips_per_pixel):
    scale = twips_per_pixel << 16
    bits = scale.bit_length() + 1
    fixed = format(scale, "0%db" % bits)
    fields = "1" + format(bits, "05b") + fixed + fixed + "0" + "00000"
    byte_count = (len(fields) + 7) // 8
    padded = fields.ljust(byte_count * 8, "0")
    return int(padded, 2).to_bytes(byte_count, "big")
