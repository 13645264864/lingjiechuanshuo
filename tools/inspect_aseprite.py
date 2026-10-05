import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
frames, width, height = struct.unpack_from("<HHH", data, 6)
print(f"frames={frames} canvas={width}x{height}")
offset = 128
for frame in range(frames):
    frame_size, magic, count, duration = struct.unpack_from("<IHHH", data, offset)
    chunk = offset + 16
    for _ in range(count):
        size, kind = struct.unpack_from("<IH", data, chunk)
        if kind == 0x2018:
            cursor = chunk + 6
            tag_count = struct.unpack_from("<H", data, cursor)[0]
            cursor += 10
            for _ in range(tag_count):
                start, end, direction = struct.unpack_from("<HHB", data, cursor)
                name_length = struct.unpack_from("<H", data, cursor + 17)[0]
                name = data[cursor + 19:cursor + 19 + name_length].decode()
                print(f"{name}: {start}-{end} direction={direction}")
                cursor += 19 + name_length
        chunk += size
    offset += frame_size
