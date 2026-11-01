"""Test passive economy evidence, static literal parsing, lifecycle, and report safety."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
HARNESS=r'''
local source=__SOURCE__
local a=assert(loadstring(source))()
assert(table.find(a.classify('CashMultiplier'),'currencies'))
assert(table.find(a.classify('CashMultiplier'),'multipliers'))
assert(table.find(a.classify('RebirthCost'),'rebirths'))
assert(#a.classify('PlayerName')==0)
assert(#a.classify('IndexPanel.Progress.Count')==0,'IndexPanel is not XP')
assert(a.value('$12.6M').number==12600000 and a.value('$12.6M').approximate)
assert(a.value('537 / 1,746').number==537 and a.value('537 / 1,746').denominator==1746)
assert(a.value('+64 XP').number==64)
assert(math.abs(a.value('$4.14T/s').number-4140000000000)<1)
assert(a.value('1,2M').number==nil,'Do not guess decimal-comma formatting')
assert(a.value(4144704757890).number==4144704757890 and not a.value(1).approximate)
assert(a.value(false).boolean==false)
assert(a.value('???').number==nil and a.value('1UnknownSuffix').number==nil)
assert(a.value(math.huge).number==nil and a.value(0/0).number==nil)
local literals,truncated=a.sourceCandidates([==[
-- MaxLevel=999999
--[=[ RebirthCost=777 ]=]
local text='Price=555'
local text2=[[ MaxLevel=12345 ]]
return {MaxLevel=200, ['RebirthCost']=1e6, XPScale=2*level, Price=-25}
]==],20)
assert(#literals==3 and not truncated)
assert(literals[1].key=='MaxLevel' and literals[1].number==200)
assert(literals[2].number==1000000 and literals[3].number==-25)
assert(literals[1].status=='client_literal_candidate')
local bounded,limited=a.sourceCandidates('Price=1;Cost=2;Reward=3',1)
assert(#bounded==1 and limited)
local _,_,hints=a.sourceCandidates('function XPForLevel(level) return 10 * level ^ 2 end',10)
assert(#hints==1 and hints[1].expression=='10 * level ^ 2' and hints[1].status=='client_return_expression_candidate')
local state=a.newState({gameName='<script>alert(1)</script>',placeId=123},{MaxFindings=2,MaxEvents=2})
local money=state:add('LocalPlayer.@Cash','Cash','replicated_attribute',100,0)
state:mark('Vente <img src=x onerror=alert(1)>',1)
state:change(money,150,2);state:change(money,140,3);state:change(money,130,4)
assert(#state.events==2 and state.events[1].delta==50 and state.events[1].markerId==1)
assert(state.events[1].causality=='not_established' and state.counts.eventsDropped==1)
local level=state:add('LocalPlayer.Level','Level','replicated_value',99999,0)
assert(state:add('x','Xp','replicated_value',0,0)==nil)
local report=a.snapshot(state,5)
assert(report.unknowns.levelCap=='not_verified' and report.systems.rebirths.status=='not_observed')
assert(report.systems.levels.status=='candidates_observed')
state:change(level,100000,6)
assert(report.findings[2].latest.number==99999,'Export snapshots must not change with live updates')
local html=a.html(report)
assert(not string.find(html,'<script>',1,true) and not string.find(html,'<img ',1,true))
assert(string.find(html,'&lt;script&gt;',1,true) and string.find(html,'not_verified',1,true))

-- Exercise the actual scanner and connection cleanup without real Roblox APIs.
local function signal()
    local s={callbacks={},disconnected=0}
    function s:Connect(fn)
        self.callbacks[#self.callbacks+1]=fn
        local index=#self.callbacks
        return {Disconnect=function() self.callbacks[index]=false;self.disconnected+=1 end}
    end
    function s:fire() for _,fn in self.callbacks do if fn then fn() end end end
    return s
end
local function object(class,name,parent,attributes)
    local o={ClassName=class,Name=name,Parent=parent,attributes=attributes or {},children={},signals={}}
    if parent then parent.children[#parent.children+1]=o end
    function o:IsA(want) return self.ClassName==want or want=='ValueBase' and self.ClassName=='NumberValue' end
    function o:GetFullName() return self.Parent and self.Parent:GetFullName()..'.'..self.Name or self.Name end
    function o:GetAttributes() return self.attributes end
    function o:GetAttribute(key) return self.attributes[key] end
    function o:GetAttributeChangedSignal(key)
        if not self.signals[key] then self.signals[key]=signal() end
        return self.signals[key]
    end
    function o:GetPropertyChangedSignal(key) return self:GetAttributeChangedSignal(key) end
    function o:GetDescendants()
        local list={}
        local function visit(p) for _,child in p.children do list[#list+1]=child;visit(child) end end
        visit(self);return list
    end
    function o:GetChildren() return self.children end
    return o
end
local player=object('Player','SecretPlayerName',nil,{Cash=100,XpMultiplier=1,PasswordCash='secret'})
player.UserId=123
local storage=object('ReplicatedStorage','ReplicatedStorage')
local own=object('NumberValue','Level',player);own.Value=120
for n=1,8 do object('ModuleScript','ShopController'..n,player) end
local module=object('ModuleScript','AnimalsData',storage);module.Source='return {MaxLevel=200,Price=100}'
local blocked=object('Folder','PlayerData',storage)
local another=object('Folder','AnotherPlayer',blocked,{Cash=99999})
local gui=object('Folder','PlayerGui',player)
local moneyUI=object('TextLabel','Money',gui);moneyUI.Text='$12.6M'
local board=object('Folder','Leaderboard',gui)
local name=object('TextLabel','Cash',board);name.Text='AnotherPlayer 123'
local env=setmetatable({}, {__index=getfenv()})
local tick=0
env.os=setmetatable({clock=function() return tick end},{__index=os})
local worker
env.task={wait=function(n) tick+=n or 0.01;coroutine.yield() end,
    spawn=function(fn) local thread=coroutine.create(fn);if not worker then worker=thread end;assert(coroutine.resume(thread));return thread end,
    cancel=function(thread) coroutine.close(thread) end}
env.print=function() end;env.warn=function() end
env.require=function() error('Never execute game modules') end
env.decompile=function() error('No decompilation by default') end
env.game={PlaceId=120219252362013,GetService=function(_,service)
    if service=='Players' then return {LocalPlayer=player} end
    if service=='ReplicatedStorage' then return storage end
    if service=='MarketplaceService' then return {GetProductInfoAsync=function() return {Name='Test game'} end} end
    if service=='HttpService' then return {JSONEncode=function() return '{}' end} end
    error(service)
end}
local chunk=assert(loadstring(source));setfenv(chunk,env)
local analyzer=chunk()
local session=analyzer.start({ShowUI=false,MaxSeconds=1,MaxModules=1})
local snapshot=session:snapshot()
assert(#snapshot.findings==4,'Only own Cash, XpMultiplier, Level and numeric Money UI')
assert(#snapshot.modules==1 and #snapshot.modules[1].literals==2)
for _,row in snapshot.findings do
    assert(not string.find(row.path,'SecretPlayerName',1,true))
    assert(not string.find(row.path,'AnotherPlayer',1,true))
    assert(not string.find(row.label,'Password',1,true))
end
local files,folders={},{}
env.writefile=function(path,contents) files[path]=contents end
env.makefolder=function(path) folders[path]=true end
env.isfolder=function(path) return folders[path]==true end
env.isfile=function(path) return files[path]~=nil end
files['Test game - Economy Analysis']='existing file'
assert(not next(folders),'No export during startup')
assert(session:export()=='Test game - Economy Analysis (2)')
assert(files['Test game - Economy Analysis (2)/report.json']=='{}')
assert(string.find(files['Test game - Economy Analysis (2)/report.html'],'Economy Analyzer',1,true))
assert(files['Test game - Economy Analysis']=='existing file','Never overwrite existing files')
module.Source=''
local decompiles=0
env.decompile=function(object) assert(object==module);decompiles+=1;return 'return {RebirthCost=300}' end
assert(session:analyzeSources()==1 and decompiles==1)
assert(session.state.modules[1].sourceMethod=='decompile')
assert(session.state.modules[1].literals[1].key=='RebirthCost')
assert(#snapshot.modules[1].literals==2,'Snapshots retain the previous source pass')
local cancelled=0
env.decompile=function() coroutine.yield() end
env.task.wait=function(n) tick+=n or 0.01 end
env.task.cancel=function(thread) cancelled+=1;coroutine.close(thread) end
assert(session:analyzeSources()==1)
assert(session.state.modules[1].status=='decompile_deadline' and cancelled==1,'Stop a timed-out source pass without accumulating jobs')
player.attributes.Cash=150;player.signals.Cash:fire()
assert(#session.state.events==1 and session.state.events[1].delta==50)
session:mark('Sale');session:stop()
player.attributes.Cash=200;player.signals.Cash:fire()
assert(#session.state.events==1 and not session.state.active)
assert(player.signals.Cash.disconnected==1 and own.signals.Value.disconnected==1)
assert(coroutine.resume(worker),'Worker must finish after stop')
print('Economy Analyzer passed: formatted/unknown numbers, static literals/return hints, evidence classification, bounds, immutable snapshots, HTML escaping, passive scanner, own-player scope, deltas, export collisions, explicit source pass and cleanup; no module execution or remote calls.')
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau',default='luau')
    args=parser.parse_args()
    source=(ROOT/'Economy Analyzer/Analyzer.luau').read_text(encoding='utf-8')
    program=HARNESS.replace('__SOURCE__','[====['+source+']====]')
    with tempfile.TemporaryDirectory(prefix='csp-economy-') as directory:
        path=Path(directory)/'economy.luau'
        path.write_text(program,encoding='utf-8')
        result=subprocess.run([args.luau,str(path)],capture_output=True,text=True)
    print(result.stdout,end='')
    if result.returncode: raise SystemExit(result.stderr)


if __name__=='__main__': main()
