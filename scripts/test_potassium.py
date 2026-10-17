"""Exercise the actual dedicated entry point with mocked native API contracts."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
local source = __ENTRY_SOURCE__
for _, scenario in {"success", "missing-bsp", "wrong-executor", "identify-error", "bad-compile", "bad-core"} do
    local captured, fetched, warned
    local env = setmetatable({}, {__index=getfenv()})
    env.identifyexecutor = function()
        if scenario == "identify-error" then error("identity unavailable") end
        return scenario == "wrong-executor" and "Other" or "Potassium", "test-build"
    end
    env.getbspval = scenario ~= "missing-bsp" and function(instance, property, base64)
        assert(instance == "terrain" and property == "SmoothGrid" and base64 == false)
        return "\0\255TERRAIN"
    end or nil
    env.gethiddenproperty = function() return "HIDDEN" end
    env.getnilinstances = function() return {} end
    env.getscriptbytecode = function() return "BYTECODE" end
    env.crypt = {base64encode=function() return "B64" end, base64decode=function() return "RAW" end, lz4compress=function() return "LZ4" end}
    env.game = {HttpGet=function(_, url)
        fetched = true
        assert(string.find(url, "/v0.6.4/saveinstance.luau", 1, true))
        return "SHARED_CORE"
    end}
    env.warn = function() warned = true end
    env.loadstring = function(text)
        assert(text == "SHARED_CORE")
        if scenario == "bad-compile" then return nil, "compile failure" end
        return function(adapter)
            captured = adapter
            if scenario == "bad-core" then return {} end
            return function(options) return {options=options, runtimeAdapter=adapter.name} end
        end
    end
    local chunk = assert(loadstring(source))
    setfenv(chunk, env)
    local progressSink=function() end
    local ok, engine = pcall(chunk,{onProgress=progressSink})
    local valid = scenario == "success" or scenario == "missing-bsp"
    assert(ok == valid, scenario)
    if valid then
        assert(fetched and captured.name == "Potassium" and captured.executorVersion == "test-build")
        assert(captured.onProgress==progressSink, "Dedicated entry must preserve the wrapper's progress sink")
        assert(captured.globals.gethiddenproperty == env.gethiddenproperty)
        assert(captured.globals.base64encode == env.crypt.base64encode)
        assert(captured.lz4compress == env.crypt.lz4compress)
        assert(engine({Binary=true}).runtimeAdapter == "Potassium")
        if scenario == "success" then
            assert(captured.readBinaryString("terrain", "SmoothGrid") == "\0\255TERRAIN")
            assert(captured.capabilities.getbspval == true)
        else
            assert(captured.readBinaryString == nil and captured.capabilities.getbspval == false and warned)
        end
    elseif scenario == "wrong-executor" or scenario == "identify-error" then
        assert(not fetched, "Wrong executor must fail before loading shared code")
    end
end
print("Potassium entry-point scenarios passed: explicit bindings, raw bytes, missing API fallback, identity rejection, compilation failure, invalid core.")
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    source = (ROOT / "Executors/Potassium/saveinstance.luau").read_text(encoding="utf-8")
    program = HARNESS.replace("__ENTRY_SOURCE__", "[====[" + source + "]====]")
    with tempfile.TemporaryDirectory(prefix="csp-potassium-") as directory:
        path = Path(directory) / "entry.luau"
        path.write_text(program, encoding="utf-8")
        result = subprocess.run([args.luau, str(path)], capture_output=True, text=True)
    print(result.stdout, end="")
    if result.returncode:
        raise SystemExit(result.stderr)

if __name__ == "__main__":
    main()
