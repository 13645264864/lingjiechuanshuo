import shutil
import sys
import urllib.request
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".tmp/pythondeps"))
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

fonts = root / "fonts"
fonts.mkdir(exist_ok=True)
for name, url in [
    ("NotoSansSC.ttf", "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"),
    ("OFL.txt", "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt"),
]:
    target = fonts / name
    if not target.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "Godot-Release-Assets"})
        with urllib.request.urlopen(request, timeout=60) as response, target.open("wb") as output:
            shutil.copyfileobj(response, output)
        print(f"Downloaded {name}: {target.stat().st_size} bytes", flush=True)
medium = fonts / "NotoSansSC-Medium.ttf"
if not medium.exists():
    with TTFont(fonts / "NotoSansSC.ttf") as source:
        instance = instantiateVariableFont(source, {"wght": 550})
        instance.save(medium)
with Image.open(root / "Sprites/menu_background.jpg") as cover:
    cover.crop((550, 285, 1450, 1185)).resize((256, 256), Image.Resampling.LANCZOS).save(root / "Sprites/app_icon.png")
print("ANDROID_VISUAL_ASSETS_READY", flush=True)
