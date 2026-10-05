"""Create a project-local release identity; keep .tmp/android backed up privately."""
import json
import os
import secrets
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
toolchain = json.loads((root / ".tmp/android/toolchain.json").read_text())
signing_file = root / ".tmp/android/signing.json"
keystore = root / ".tmp/android/release.keystore"
if signing_file.exists():
    signing = json.loads(signing_file.read_text())
else:
    signing = {"alias": "demonslayer", "password": secrets.token_urlsafe(28)}
    signing_file.write_text(json.dumps(signing), encoding="utf-8")
environment = os.environ.copy()
environment["GODOT_RELEASE_KEY_PASSWORD"] = signing["password"]
if not keystore.exists():
    subprocess.run([
        str(Path(toolchain["java_home"]) / "bin/keytool.exe"), "-genkeypair",
        "-keystore", str(keystore), "-storetype", "JKS", "-alias", signing["alias"],
        "-storepass:env", "GODOT_RELEASE_KEY_PASSWORD", "-keypass:env", "GODOT_RELEASE_KEY_PASSWORD",
        "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
        "-dname", "CN=Demon Slayer Beta, OU=Game, O=Lingjiechuanshuo, C=CN",
    ], env=environment, check=True, capture_output=True)
credentials = root / ".godot/export_credentials.cfg"
credentials.write_text(
    '[preset.0.options]\n\nkeystore/release="' + keystore.as_posix() + '"\n'
    'keystore/release_user="' + signing["alias"] + '"\n'
    'keystore/release_password="' + signing["password"] + '"\n', encoding="utf-8"
)
print("ANDROID_RELEASE_IDENTITY_READY (private credentials remain under .tmp and .godot)")
