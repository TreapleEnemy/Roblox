# GladeSlayer: сборка без Rojo.
# Читает default.project.json (то же дерево, что у Rojo) и создаёт:
#   dist/GladeSlayer.rbxlx    - плейс для Roblox Studio (File > Open),
#   dist/GladeSlayer_src.zip  - полные исходники + плейс + отчёт проверки.
# Затем перечитывает .rbxlx XML-парсером и сверяет каждый скрипт с исходником.
# Запуск: python tools/build.py
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
SERVICES = {"ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterPlayerScripts",
            "StarterCharacterScripts", "Workspace", "Lighting", "StarterGui"}

_ref = [0]


def referent():
    _ref[0] += 1
    return "RBX%08X" % _ref[0]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_class(filename):
    if filename.endswith(".server.luau"):
        return "Script", filename[:-len(".server.luau")]
    if filename.endswith(".client.luau"):
        return "LocalScript", filename[:-len(".client.luau")]
    if filename.endswith(".luau"):
        return "ModuleScript", filename[:-len(".luau")]
    return None, None


def item(cls, name, children, source=None):
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        props += '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, referent(), props, "".join(children))


def dir_children(path, expected):
    out = []
    for filename in sorted(os.listdir(path)):
        cls, name = script_class(filename)
        if not cls:
            continue
        with open(os.path.join(path, filename), encoding="utf-8") as f:
            source = f.read()
        expected.append((cls, name, source))
        out.append(item(cls, name, [], source))
    return out


def node(name, spec, expected):
    children = []
    if "$path" in spec:
        children.extend(dir_children(os.path.join(ROOT, spec["$path"]), expected))
    for key, value in spec.items():
        if not key.startswith("$"):
            children.append(node(key, value, expected))
    cls = spec.get("$className") or (name if name in SERVICES else "Folder")
    return item(cls, name, children)


def build_rbxlx():
    with open(os.path.join(ROOT, "default.project.json"), encoding="utf-8") as f:
        project = json.load(f)
    expected = []
    body = [item("Workspace", "Workspace", [])]
    for key, value in project["tree"].items():
        if not key.startswith("$"):
            body.append(node(key, value, expected))
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           '<External>null</External><External>nil</External>' + "".join(body) + "</roblox>")
    os.makedirs(DIST, exist_ok=True)
    path = os.path.join(DIST, "GladeSlayer.rbxlx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    return path, expected


def validate_rbxlx(path, expected):
    tree = ET.parse(path)
    refs = [e.get("referent") for e in tree.iter("Item")]
    assert len(refs) == len(set(refs)), "дублирующиеся referent"
    scripts = {}
    for e in tree.iter("Item"):
        name = e.find("Properties/string[@name='Name']").text
        src = e.find("Properties/ProtectedString[@name='Source']")
        if src is not None:
            scripts[(e.get("class"), name)] = src.text or ""
    for cls, name, source in expected:
        assert scripts.get((cls, name)) == source, "исходник не совпал: %s %s" % (cls, name)
    print("OK: %s - %d объектов, %d скриптов совпадают с исходниками" % (os.path.relpath(path, ROOT), len(refs), len(expected)))


def run_verify():
    verifier = "portable_verify.py" if "--portable" in sys.argv else "verify.py"
    res = subprocess.run([sys.executable, "-X", "utf8", os.path.join(ROOT, "tools", verifier)],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    report = res.stdout + res.stderr
    with open(os.path.join(ROOT, "VERIFY_REPORT.txt"), "w", encoding="utf-8") as f:
        f.write(report)
    print(report.strip().splitlines()[-1] if report.strip() else "verify: нет вывода")
    return res.returncode


def build_zip():
    zip_path = os.path.join(DIST, "GladeSlayer_src.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, files in os.walk(ROOT):
            # Скрытые служебные каталоги (.git, .hoplite и т. п.) в архив проекта не попадают.
            dirs[:] = [d for d in dirs if d != "__pycache__" and not d.startswith(".")]
            for filename in files:
                full = os.path.join(base, filename)
                if full == zip_path:
                    continue
                z.write(full, os.path.join("GladeSlayer", os.path.relpath(full, ROOT)))
    print("OK: %s (%d KB)" % (os.path.relpath(zip_path, ROOT), os.path.getsize(zip_path) // 1024))


def main():
    code = run_verify()
    path, expected = build_rbxlx()
    validate_rbxlx(path, expected)
    build_zip()
    if code != 0:
        print("ВНИМАНИЕ: verify.py нашёл проблемы, см. VERIFY_REPORT.txt")
        sys.exit(1)


if __name__ == "__main__":
    main()
