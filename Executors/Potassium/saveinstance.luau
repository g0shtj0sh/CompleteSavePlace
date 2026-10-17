-- CompleteSavePlace / Potassium entry point
-- Shared serializer, explicit native API bindings. AGPL-3.0; see LICENSE and NOTICE.md.
-- Reference: https://docs.potassium.pro/api-reference
local CORE_URL = "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.6.4/saveinstance.luau"
local runtimeOptions = ... or {}
local identify = identifyexecutor or getexecutorname
assert(type(identify) == "function", "Potassium: identifyexecutor is unavailable")
local identified, executorName, executorVersion = pcall(identify)
assert(identified and type(executorName) == "string" and string.find(string.lower(executorName), "potassium", 1, true),
	"This entry point requires Potassium. Use the universal presets for other runtimes.")

local nativeCrypt = type(crypt) == "table" and crypt or {}
local nativeBsp = getbspval
local adapter = {
	onProgress = runtimeOptions.onProgress,
	name = "Potassium",
	executorVersion = tostring(executorVersion or "unknown"),
	globals = {
		gethiddenproperty = gethiddenproperty or gethiddenprop,
		gethui = gethui or get_hidden_gui,
		getnilinstances = getnilinstances,
		getscriptbytecode = getscriptbytecode or dumpstring,
		base64encode = nativeCrypt.base64encode or base64encode,
		base64decode = nativeCrypt.base64decode or base64decode,
		setrbxclipboard = setrbxclipboard,
	},
	lz4compress = nativeCrypt.lz4compress or lz4compress,
	capabilities = {
		getbspval = type(nativeBsp) == "function",
		gethiddenproperty = type(gethiddenproperty or gethiddenprop) == "function",
		getnilinstances = type(getnilinstances) == "function",
		getscriptbytecode = type(getscriptbytecode or dumpstring) == "function",
		decompile = type(decompile) == "function",
		appendfile = type(appendfile) == "function",
		lz4compress = type(nativeCrypt.lz4compress or lz4compress) == "function",
	},
}
if type(nativeBsp) == "function" then
	adapter.readBinaryString = function(instance, property)
		return nativeBsp(instance, property, false) -- Raw bytes; never write base64 text as geometry.
	end
else
	warn("[CSP / Potassium] getbspval unavailable in this build; using ordinary property fallbacks.")
end

local source = game:HttpGet(CORE_URL, true)
assert(type(source) == "string" and #source > 0, "Potassium: empty shared engine response")
adapter.sharedCoreUrl = CORE_URL
adapter.sharedCoreBytes = #source
local chunk, compileError = loadstring(source, "CompleteSavePlace/PotassiumCore")
assert(chunk, "Potassium: shared engine compilation failed: " .. tostring(compileError))
local engine = chunk(adapter)
assert(type(engine) == "function", "Potassium: shared core did not return an exporter")
return engine
