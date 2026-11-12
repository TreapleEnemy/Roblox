"""GladeSlayer: офлайн-проверка проекта без Roblox Studio.

1. Синтаксис всех .luau через luau-compile.
2. Опечатки в глобальных именах через luau-analyze (неизвестные глобалы вне API Roblox).
3. Зависимости: каждый require/WaitForChild указывает на существующий модуль,
   каждая вызываемая функция модуля (Alias.Func) в нём определена, ключи Config существуют.
4. FX-события сервера имеют обработчики на клиенте; Request-действия клиента есть на сервере.
5. Юнит-тесты Rules/Config (tests/rules_spec.luau) в luau.exe со стабами Roblox-типов.

Запуск: python tools/verify.py [--luau DIR]   (по умолчанию ищет luau в PATH и ../.temp/luau)
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
FOLDERS = {"shared": "Shared", "server": "Server", "client": "Client", "character": "Character"}

ROBLOX_GLOBALS = set("""game workspace script Instance Vector3 Vector2 CFrame Color3 ColorSequence ColorSequenceKeypoint
NumberSequence NumberSequenceKeypoint NumberRange UDim UDim2 Enum TweenInfo task tick Ray RaycastParams OverlapParams
PhysicalProperties BrickColor Random Region3 Rect DateTime plugin shared settings typeof warn elapsedTime time wait delay
spawn utf8 Font Axes Faces debug buffer""".split())

errors = []
notes = []


def fail(msg):
    errors.append(msg)
    print("  FAIL " + msg)


def ok(msg):
    print("  ok   " + msg)


def find_tool(name, extra_dir):
    exe = name + (".exe" if os.name == "nt" else "")
    for d in [extra_dir, os.path.join(ROOT, "..", ".temp", "luau"), os.path.join(ROOT, ".temp", "luau")]:
        if d and os.path.isfile(os.path.join(d, exe)):
            return os.path.join(d, exe)
    return shutil.which(name)


def load_sources():
    files = {}
    for folder in FOLDERS:
        base = os.path.join(SRC, folder)
        for name in sorted(os.listdir(base)):
            if name.endswith(".luau"):
                path = os.path.join(base, name)
                with open(path, encoding="utf-8") as f:
                    files[(folder, name)] = f.read()
    return files


def module_name(filename):
    return filename.split(".")[0]


def check_syntax(files, compiler):
    print("[1] Синтаксис (luau-compile)")
    if not compiler:
        fail("luau-compile не найден — синтаксис не проверен")
        return
    paths = [os.path.join(SRC, folder, name) for folder, name in files]
    paths.extend(os.path.join(ROOT, "tests", n) for n in os.listdir(os.path.join(ROOT, "tests")) if n.endswith(".luau"))
    for path in paths:
        res = subprocess.run([compiler, "--null", path], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if res.returncode != 0:
            res = subprocess.run([compiler, "--binary", path], capture_output=True)
            out = (res.stderr or b"").decode("utf-8", "replace")
        else:
            out = res.stderr + res.stdout
        rel = os.path.relpath(path, ROOT)
        if res.returncode != 0 or "SyntaxError" in out:
            fail("%s: %s" % (rel, out.strip()[:400]))
        else:
            ok(rel)


def check_globals(files, analyzer):
    print("[2] Неизвестные глобальные имена (luau-analyze)")
    if not analyzer:
        fail("luau-analyze не найден — глобалы не проверены")
        return
    for folder, name in files:
        path = os.path.join(SRC, folder, name)
        res = subprocess.run([analyzer, path], capture_output=True, text=True, encoding="utf-8", errors="replace")
        bad = set()
        for line in (res.stdout + res.stderr).splitlines():
            m = re.search(r"Unknown global '(\w+)'", line)
            if m and m.group(1) not in ROBLOX_GLOBALS:
                bad.add(m.group(1))
            if "SyntaxError" in line:
                bad.add("SyntaxError: " + line.strip())
        if bad:
            fail("%s/%s: %s" % (folder, name, ", ".join(sorted(bad))))
        else:
            ok("%s/%s" % (folder, name))


def defined_members(source, module):
    names = set(re.findall(r"function\s+%s[.:](\w+)" % module, source))
    names |= set(re.findall(r"\b%s\.(\w+)\s*=" % module, source))
    return names


def check_dependencies(files):
    print("[3] Зависимости модулей")
    by_folder = {}
    for folder, name in files:
        by_folder.setdefault(folder, {})[module_name(name)] = files[(folder, name)]
    shared = by_folder["shared"]
    config_src = shared["Config"]
    for (folder, name), source in files.items():
        own = by_folder[folder]
        label = "%s/%s" % (folder, name)
        aliases = {}
        for alias, base, target in re.findall(r"local\s+(\w+)\s*=\s*require\(([\w.]+):WaitForChild\(\"(\w+)\"\)\)", source):
            container = shared if base in ("Shared",) or (folder == "shared" and base == "script.Parent") else own
            if base == "script.Parent" and folder != "shared":
                container = own
            if target not in container:
                fail("%s: require %s.%s — модуль не найден" % (label, base, target))
                continue
            aliases[alias] = (target, container[target])
        for alias, base, target in re.findall(r"local\s+(\w+)\s*=\s*require\(([\w.]+)\.(\w+)\)", source):
            container = own if base in ("script.Parent", "script") else shared
            if target not in container:
                fail("%s: require %s.%s — модуль не найден" % (label, base, target))
                continue
            aliases[alias] = (target, container[target])
        for alias, (target, target_src) in aliases.items():
            used = set(re.findall(r"(?<![\w.:])%s\.(\w+)" % alias, source))
            if target == "Config":
                missing = [k for k in used if not re.search(r"\b%s\s*=" % k, config_src)]
            else:
                defined = defined_members(target_src, target) | defined_members(target_src, alias)
                missing = sorted(k for k in used if k not in defined)
            if missing:
                fail("%s: %s.%s не определено в %s" % (label, alias, "/".join(sorted(missing)), target))
        # Внутренние ссылки модуля на собственные функции
        mod = module_name(name)
        if folder in ("shared", "server", "client") and re.search(r"local\s+%s\s*=\s*\{\}" % mod, source):
            used = set(re.findall(r"(?<![\w.:])%s\.(\w+)" % mod, source))
            missing = sorted(used - defined_members(source, mod))
            if missing:
                fail("%s: %s.%s не определено" % (label, mod, "/".join(missing)))
        if not any(e.startswith(label) for e in errors):
            ok(label)
    # Config: ключи, на которые ссылается сам Rules/Models/Animator уже проверены выше.


def check_protocol(files):
    print("[4] Протокол клиент-сервер")
    server = "\n".join(s for (f, _), s in files.items() if f == "server")
    client = "\n".join(s for (f, _), s in files.items() if f == "client")
    fx_sent = set(re.findall(r"FX:Fire(?:AllClients|Client)\((?:\w+,\s*)?\"(\w+)\"", server))
    fx_handled = set(re.findall(r"function handlers\.(\w+)", client))
    for kind in sorted(fx_sent):
        if kind in fx_handled:
            ok("FX %s обрабатывается клиентом" % kind)
        else:
            fail("FX %s: нет обработчика на клиенте" % kind)
    actions = set(re.findall(r"request\(\"(\w+)\"", client)) | set(re.findall(r"InvokeServer\(\"(\w+)\"", client))
    for action in sorted(actions):
        if re.search(r"\b%s\s*=\s*function|handlers\.%s\b|\[\"%s\"\]|action == \"%s\"" % (action, action, action, action), server):
            ok("Request %s обрабатывается сервером" % action)
        else:
            fail("Request %s: нет обработчика на сервере" % action)


STUBS = r"""
local function vec(x, y, z)
	local v = { X = x or 0, Y = y or 0, Z = z or 0 }
	return setmetatable(v, {
		__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
		__mul = function(a, b) if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end,
		__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) return vec(t.X / m, t.Y / m, t.Z / m) end return nil end,
	})
end
Vector3 = { new = vec, zero = vec(0, 0, 0), one = vec(1, 1, 1) }
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Color3.fromHSV = function() return Color3.new(1, 1, 1) end
local anyEnum = setmetatable({}, { __index = function(t, k) return setmetatable({ Name = k }, { __index = function(_, k2) return { Name = k2 } end }) end })
Enum = anyEnum
CFrame = { new = function() return {} end, Angles = function() return {} end }
UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end }
NumberSequence = { new = function() return {} end }
ColorSequence = { new = function() return {} end }
"""


def run_tests(files, luau):
    print("[5] Юнит-тесты Rules/Config (luau)")
    if not luau:
        fail("luau не найден — тесты не запущены")
        return
    shared = {module_name(n): s for (f, n), s in files.items() if f == "shared"}
    with open(os.path.join(ROOT, "tests", "rules_spec.luau"), encoding="utf-8") as f:
        spec = f.read()
    for extra in ("expansion_spec.luau", "update3_spec.luau"):
        path = os.path.join(ROOT, "tests", extra)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                spec += "\n" + f.read()
    parts = [STUBS, "local __src, __cache = {}, {}",
             "local function __load(name) if __cache[name] == nil then __cache[name] = __src[name]() end return __cache[name] end",
             "local __parent = { WaitForChild = function(_, n) return { __module = n } end, FindFirstChild = function(_, n) return { __module = n } end }"]
    for name in ("Config", "Rules"):
        parts.append("__src[%r] = function()\nlocal script = { Parent = __parent }\nlocal require = function(m) return __load(m.__module) end\n%s\nend" % (name, shared[name]))
    parts.append("Config = __load('Config')\nRules = __load('Rules')\nlocal __passed, __failed = 0, 0")
    parts.append("function check(name, cond) if cond then __passed = __passed + 1 else __failed = __failed + 1 print('  FAIL test: ' .. name) end end")
    parts.append("local __ok, __err = pcall(function()\n%s\nend)" % spec)
    parts.append("if not __ok then print('  FAIL test crashed: ' .. tostring(__err)) __failed = __failed + 1 end")
    parts.append("print(string.format('  tests: %d passed, %d failed', __passed, __failed))")
    tmp = os.path.join(tempfile.gettempdir(), "gladeslayer_spec.luau")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    res = subprocess.run([luau, tmp], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (res.stdout + res.stderr).strip()
    print(out)
    if res.returncode != 0 or "FAIL" in out or "passed" not in out:
        fail("юнит-тесты Rules не прошли")


SMOKE_MODULES = ["Config", "Rules", "Models", "Animator", "ExpansionWorld", "DungeonWorld", "DungeonService", "TutorialService",
                 "TravelService", "MobService", "EconomyService", "UI", "Icons", "IconRenderer", "Guide", "Effects"]


def run_smoke(luau):
    print("[6] Mock-рантайм (tests/runtime_smoke.luau в luau)")
    path = os.path.join(ROOT, "tests", "runtime_smoke.luau")
    if not luau or not os.path.isfile(path):
        fail("luau или runtime_smoke.luau не найден — смоук не запущен")
        return
    chunks = []
    for name in SMOKE_MODULES:
        candidates = [os.path.join(SRC, folder, name + ".luau") for folder in FOLDERS]
        source_path = next(p for p in candidates if os.path.isfile(p))
        with open(source_path, encoding="utf-8") as f:
            source = f.read()
        chunks.append("__sources['%s']=function() local script={Parent=__parent}; local require=__require; %s\nend" % (name, source))
    with open(path, encoding="utf-8") as f:
        harness = f.read().replace("-- INSERT_MODULES", "\n".join(chunks))
    tmp = os.path.join(tempfile.gettempdir(), "gladeslayer_smoke.luau")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(harness)
    res = subprocess.run([luau, tmp], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (res.stdout + res.stderr).strip()
    print("  " + out.replace("\n", "\n  ")[-1500:])
    if res.returncode != 0 or "PASS" not in out:
        fail("mock-рантайм смоук не прошёл")


def main():
    extra = None
    if "--luau" in sys.argv:
        extra = sys.argv[sys.argv.index("--luau") + 1]
    files = load_sources()
    check_syntax(files, find_tool("luau-compile", extra))
    check_globals(files, find_tool("luau-analyze", extra))
    check_dependencies(files)
    check_protocol(files)
    run_tests(files, find_tool("luau", extra))
    run_smoke(find_tool("luau", extra))
    print()
    if errors:
        print("ИТОГ: %d проблем(ы)" % len(errors))
        sys.exit(1)
    print("ИТОГ: все офлайн-проверки пройдены")


if __name__ == "__main__":
    main()
