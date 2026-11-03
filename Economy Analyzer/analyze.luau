-- Independent passive economy observer; no .rbxl export and no remote calls.
local settings=... or {}
local source=game:HttpGet("https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v0.8.1/Economy%20Analyzer/Analyzer.luau",true)
local chunk,err=loadstring(source,"CompleteSavePlace/EconomyAnalyzer")
assert(chunk,"Economy Analyzer compilation failed: "..tostring(err))
local analyzer=chunk()
local environment=type(getgenv)=="function" and getgenv() or getfenv()
local previous=environment.CSP_EconomyAnalyzer
if previous and type(previous.destroy)=="function" then previous:destroy() end
local session=analyzer.start(settings)
environment.CSP_EconomyAnalyzer=session
return session
