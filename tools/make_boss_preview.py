from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = []
for filename in sorted((root / ".godot/nightborne-animation-frames").glob("frame_*.png")):
    with Image.open(filename) as source:
        image = source.convert("RGB")
        image.thumbnail((640, 360), Image.Resampling.NEAREST)
        frames.append(image.quantize(colors=128))
if not frames:
    raise SystemExit("Run tests/boss_animation.gd with -- --capture first")
frames[0].save(
    root / ".godot/nightborne-animation-preview.gif",
    save_all=True,
    append_images=frames[1:],
    duration=200,
    loop=0,
    optimize=True,
)
print(f"BOSS_PREVIEW frames={len(frames)} .godot/nightborne-animation-preview.gif")
