"""Offline fallback for this project's Lua-compatible Luau subset.
Uses the installed liblua 5.4 via ctypes, NOT a Luau compiler or Roblox runtime.
Checks syntax, runs pure Rules tests, dependencies, protocol, and mocked service tests.
Do not infer Studio/physics/rendering/DataStore validation from this report.
"""
from pathlib import Path
import ctypes
import ctypes.util
import importlib.util
import sys
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('verify', ROOT/'tools/verify.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
libname = ctypes.util.find_library('lua5.4') or ctypes.util.find_library('lua-5.4') or '/usr/lib64/liblua-5.4.so'
lib = ctypes.CDLL(libname)
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
lib.luaL_loadbufferx.restype = ctypes.c_int
lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lib.lua_pcallk.restype = ctypes.c_int
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ctypes.c_void_p]
def lua(source, name, execute=False):
    state = lib.luaL_newstate()
    lib.luaL_openlibs(state)
    raw = source.encode('utf8')
    result = lib.luaL_loadbufferx(state, raw, len(raw), name.encode(), b't')
    if result == 0 and execute:
        result = lib.lua_pcallk(state, 0, 0, 0, 0, None)
    error = lib.lua_tolstring(state, -1, None).decode('utf8','replace') if result else ''
    lib.lua_close(state)
    if result:
        raise AssertionError(name+': '+error)
print('PORTABLE CHECK: Lua 5.4 fallback; not official Luau/Studio verification.', flush=True)
files = v.load_sources()
for path in sorted(ROOT.glob('**/*.luau')):
    lua(path.read_text(),str(path.relative_to(ROOT)))
print('PASS: all source/test files parse in the Lua-compatible subset', flush=True)
v.check_dependencies(files)
v.check_protocol(files)
assert not v.errors, v.errors
stubs = v.STUBS + '''
math.clamp = function(v,a,b) return math.max(a,math.min(b,v)) end
table.find = function(t,x) for i,v in ipairs(t) do if v==x then return i end end end
'''
parts = [stubs, 'local __src,__cache={},{}',
 'local function __load(n) if not __cache[n] then __cache[n]=__src[n]() end return __cache[n] end',
 'local parent={WaitForChild=function(_,n) return {__module=n} end}']
for name in ('Config','Rules'):
    parts += ["__src['"+name+"']=function()\nlocal script={Parent=parent}\nlocal require=function(m) return __load(m.__module) end\n"+(ROOT/'src/shared'/f'{name}.luau').read_text()+'\nend']
parts += ["Config=__load('Config'); Rules=__load('Rules'); local passed=0",
 'function check(name,condition) assert(condition,name); passed=passed+1 end',
 (ROOT/'tests/rules_spec.luau').read_text(),
 (ROOT/'tests/expansion_spec.luau').read_text(),
 'print("PASS: "..passed.." pure Rules/config assertions")']
lua('\n'.join(parts),'rules_and_expansion',True)
# Additional mock-runtime smoke harness for server-side travel and procedural factories.
if (ROOT/'tests/runtime_smoke.luau').exists():
    modules = ['Config','Rules','Models','Animator','ExpansionWorld','TravelService','MobService','EconomyService','UI','Icons','Effects']
    chunks = []
    for name in modules:
        candidates=list((ROOT/'src').glob(f'*/{name}.luau'))
        source=candidates[0].read_text()
        chunks.append("__sources['"+name+"']=function() local script={Parent=__parent}; local require=__require; "+source+'\nend')
    harness=(ROOT/'tests/runtime_smoke.luau').read_text().replace('-- INSERT_MODULES', '\n'.join(chunks))
    lua(harness,'mock_runtime_smoke',True)
print('PASS: portable checks completed. Studio, official Luau analysis, visuals and real services NOT tested.', flush=True)
