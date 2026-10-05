"""Fetch the official portable Android toolchain and matching Godot APK templates."""
import hashlib
import io
import json
import os
import shutil
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tmp/android"
DOWNLOADS = TOOLS / "downloads"
SDK = TOOLS / "sdk"
VERSION = "4.7.2"
DOWNLOADS.mkdir(parents=True, exist_ok=True)
SDK.mkdir(parents=True, exist_ok=True)


def open_url(url, headers=None):
    return urllib.request.urlopen(urllib.request.Request(url, headers={
        "User-Agent": "Godot-Android-Build", "Accept-Encoding": "identity", **(headers or {})
    }), timeout=60)


def download(url, target, expected_sha256=None):
    if target.exists() and target.stat().st_size > 0:
        if not expected_sha256 or hashlib.sha256(target.read_bytes()).hexdigest() == expected_sha256:
            return target
    partial = target.with_suffix(target.suffix + ".part")
    print(f"Downloading {target.name}", flush=True)
    with open_url(url) as response, partial.open("wb") as output:
        shutil.copyfileobj(response, output, 1024 * 1024)
    if expected_sha256 and hashlib.sha256(partial.read_bytes()).hexdigest() != expected_sha256:
        raise RuntimeError(f"Checksum mismatch: {target.name}")
    partial.replace(target)
    print(f"Downloaded {target.name}: {target.stat().st_size // 1024 // 1024} MiB", flush=True)
    return target


class RemoteZip(io.RawIOBase):
    """Read only the APK members, not the 1 GB desktop template archive."""
    def __init__(self, url, length):
        with open_url(url, {"Range": f"bytes={length - 65557}-{length - 1}"}) as response:
            self.url = response.url
            content_range = response.headers.get("Content-Range", "")
            if response.status != 206 or "/" not in content_range:
                raise RuntimeError("Official template server does not support byte ranges")
            self.length = int(content_range.rsplit("/", 1)[1])
        self.position = 0
        self.cache = {}
        self.block_size = 1024 * 1024

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.length + offset)
        return self.position

    def read(self, amount=-1):
        end = min(self.length, self.position + amount) if amount >= 0 else self.length
        output = bytearray()
        while self.position < end:
            block = self.position // self.block_size
            if block not in self.cache:
                start = block * self.block_size
                stop = min(start + self.block_size, self.length) - 1
                with open_url(self.url, {"Range": f"bytes={start}-{stop}"}) as response:
                    actual = response.headers.get("Content-Range", "")
                    if not actual.startswith(f"bytes {start}-"):
                        raise RuntimeError(f"Unexpected range response: {actual}")
                    data = response.read()
                if len(self.cache) >= 8:
                    self.cache.pop(next(iter(self.cache)))
                self.cache[block] = data
            data = self.cache[block]
            start_in_block = self.position % self.block_size
            take = min(len(data) - start_in_block, end - self.position)
            if take <= 0:
                raise RuntimeError("Truncated remote template archive")
            output.extend(data[start_in_block:start_in_block + take])
            self.position += take
        return bytes(output)


def templates():
    destination = TOOLS / "templates"
    destination.mkdir(exist_ok=True)
    names = ["android_debug.apk", "android_release.apk"]
    if all((destination / name).exists() for name in names):
        return
    release_url = f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}-stable"
    with open_url(release_url) as response:
        release = json.load(response)
    asset = next(item for item in release["assets"] if item["name"] == f"Godot_v{VERSION}-stable_export_templates.tpz")
    print("Opening official Godot Android templates", flush=True)
    with zipfile.ZipFile(RemoteZip(asset["browser_download_url"], asset["size"])) as archive:
        for name in names:
            member = next(item for item in archive.namelist() if item.endswith("/" + name))
            print(f"Extracting {name}", flush=True)
            temporary = destination / (name + ".part")
            with archive.open(member) as source, temporary.open("wb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
            temporary.replace(destination / name)
    print("Godot Android templates ready", flush=True)


def toolchain():
    with open_url("https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&os=windows&image_type=jdk&vendor=eclipse") as response:
        package = json.load(response)[0]["binary"]["package"]
    jdk_zip = download(package["link"], DOWNLOADS / "jdk17.zip", package["checksum"])
    jdk_root = TOOLS / "jdk"
    if not jdk_root.exists():
        with zipfile.ZipFile(jdk_zip) as archive:
            archive.extractall(jdk_root)
    java_home = next(path.parent.parent for path in jdk_root.glob("*/bin/java.exe"))
    with open_url("https://dl.google.com/android/repository/repository2-1.xml") as response:
        repository = ET.fromstring(response.read())
    packages = {node.attrib["path"]: node for node in repository.iter("remotePackage")}
    for name, destination in [("platform-tools", SDK), ("build-tools;35.0.1", SDK / "build-tools/35.0.1"), ("platforms;android-35", SDK / "platforms/android-35")]:
        destination.mkdir(parents=True, exist_ok=True)
        ready = SDK / "platform-tools/adb.exe" if name == "platform-tools" else destination / ("apksigner.bat" if name.startswith("build-tools") else "android.jar")
        if ready.exists():
            continue
        package = packages[name]
        archive = next(node for node in package.findall("archives/archive") if node.findtext("host-os") in (None, "windows"))
        url = "https://dl.google.com/android/repository/" + archive.findtext("complete/url")
        download_zip = download(url, DOWNLOADS / (name.replace(";", "-") + ".zip"))
        with zipfile.ZipFile(download_zip) as source:
            if name == "platform-tools":
                source.extractall(destination)
            else:
                for item in source.infolist():
                    parts = Path(item.filename).parts[1:]
                    if not parts:
                        continue
                    target = destination.joinpath(*parts)
                    if item.is_dir():
                        target.mkdir(parents=True, exist_ok=True)
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with source.open(item) as stream, target.open("wb") as output:
                            shutil.copyfileobj(stream, output)
    configuration = {"java_home": str(java_home), "android_sdk": str(SDK), "templates": str(TOOLS / "templates")}
    (TOOLS / "toolchain.json").write_text(json.dumps(configuration, indent=2), encoding="utf-8")
    print("Android toolchain ready", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "templates": templates()
    if len(sys.argv) < 2 or sys.argv[1] == "toolchain": toolchain()
