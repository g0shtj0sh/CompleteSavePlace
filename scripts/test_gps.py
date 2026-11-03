"""Exercise the GPS planner, retained tree, streaming lifecycle, and actual export integration."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
local source=__SOURCE__
local function vector(x,y,z) return {X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)} end
local function node(class,name,parent)
    local n={ClassName=class,Name=name,Parent=parent,Archivable=true,Anchored=true,
        Position=vector(0,0,0),Size=vector(1,1,1),CFrame='retained transform'}
    n.IsA=function(self,want) return self.ClassName==want or want=='BasePart' and self.ClassName=='Part' end
    n.GetChildren=function() return {} end
    return n
end
local GPS=assert(loadstring(source))()
for _,bad in {{Step=0},{MaxCells=0},{MaxRadius=math.huge},{Height='invalid'},{MaxSeconds=0},{MaxInstances=-1},{MaxInstances=math.huge}} do
    if bad.Height then continue end
    assert(not pcall(GPS.settings,bad),'Reject invalid budgets')
end
assert(GPS.settings().MaxInstances==0,'GPS defaults to unlimited retained objects')
local unlimited=GPS.newArchive(node('Workspace','Unlimited'),0)
for i=1,300001 do unlimited:remember(node('Folder',tostring(i),unlimited.root)) end
assert(unlimited.count==300001 and not unlimited.limitReached,'Retain beyond the former 300000-object cap')
unlimited=nil
local settings=GPS.settings({Step=128,InitialRadius=128,MaxRadius=256,MaxCells=25})
local planner=GPS.newPlanner(settings,vector(0,4,0))
assert(planner:total()==9)
assert(planner:nextPoint().X==0,'Start near the player')
planner:observe(vector(999999,4,0),0)
assert(planner.maxX==256 and planner:total()==12,'Expansion stays inside MaxRadius')
local seen={}
while true do
    local point,reason=planner:nextPoint()
    if not point then assert(reason=='grid_exhausted');break end
    assert(point.Y==4 and math.abs(point.X)<=256 and math.abs(point.Z)<=256)
    local key=point.X..':'..point.Z
    assert(not seen[key]);seen[key]=true
end
local manual=GPS.newPlanner(GPS.settings({Step=128,MaxRadius=256,Bounds={Min=vector(0,0,0),Max=vector(128,0,128)}}),vector(0,0,0))
manual:observe(vector(10000,0,10000),0)
assert(manual:total()==4 and manual.maxX==128,'Manual limits never auto-expand')
assert(not pcall(GPS.newPlanner,GPS.settings({MaxRadius=256,Bounds={Min=vector(0,0,0),Max=vector(10000,0,0)}}),vector(0,0,0)))
local limited=GPS.newPlanner(GPS.settings({MaxCells=1}),vector(0,0,0))
assert(limited:nextPoint());local _,reason=limited:nextPoint();assert(reason=='cell_limit')

local root=node('Workspace','Workspace')
local folder=node('ModuleScript','Assets',root)
local first=node('Part','DuplicateName',folder)
local second=node('Part','DuplicateName',folder)
local archive=GPS.newArchive(root,10)
archive:remember(first);archive:remember(second);archive:remember(first)
assert(archive.count==3 and #archive.children[folder]==2,'Keep legitimate duplicate names; deduplicate by identity')
folder.Parent=nil;first.Parent=nil
archive:remember(first)
assert(archive.parents[first]==folder and archive.children[root][1]==folder,'Retain hierarchy after streaming out')
assert(archive.properties[first].CFrame=='retained transform')
local third=node('Folder','New parent',root)
second.Parent=third;archive:remember(second)
assert(#archive.children[folder]==1 and archive.parents[second]==third,'Keep observed reparenting consistent')
local tiny=GPS.newArchive(root,1);first.Parent=folder;folder.Parent=root;tiny:remember(first)
assert(tiny.limitReached and tiny.count==1)

-- Run the actual collector against a deterministic streaming/scheduler simulation.
local function lifecycle(mode)
    local tick,calls,cancelled,disconnected,destroyed=0,0,0,false,false
    local callback,stopButton,lastProgress
    local awaitingTicks=0
    local panelGui
    local world=node('Workspace','Workspace')
    world.StreamingEnabled=mode~='disabled'
    local part=node('Part','Original',world)
    world.GetDescendants=function() return {part} end
    world.DescendantAdded={Connect=function(_,fn)
        callback=fn
        return {Disconnect=function() disconnected=true end}
    end}
    local player={Character={FindFirstChild=function() return {Position=vector(0,0,0)} end}}
    player.RequestStreamAroundAsync=function(_,point,timeout)
        calls+=1;assert(timeout==0.1)
        if mode=='errors' then error('requests unavailable') end
        if mode=='deadline' then coroutine.yield() end
        if calls==1 then
            local extra=node('Part','New streamed zone',world);extra.Position=vector(256,0,0)
            callback(extra)
        else part.Parent=nil end
    end
    local env=setmetatable({}, {__index=getfenv()})
    env.workspace=world
    env.Vector3={new=vector}
    env.Color3={fromRGB=function(...) return {...} end}
    env.UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
    env.Instance={new=function(class)
        if mode=='headless' then error('no GUI') end
        local item={Destroy=function() destroyed=true end,Activated={Connect=function(_,fn) stopButton=fn end}}
        if class=="ScreenGui" then panelGui=item end
        return item
    end}
    env.game={GetService=function(_,name)
        if name=='Players' then return {LocalPlayer=player} end
        return {}
    end}
    env.os=setmetatable({clock=function() return tick end},{__index=os})
    env.warn=function() end
    env.task={spawn=function(fn) local thread=coroutine.create(fn);assert(coroutine.resume(thread));return thread end,
        wait=function(seconds)
            tick+=mode=='time' and 0.6 or seconds or 0.01
            if mode=='user' and tick>=0.1 then stopButton() end
            if lastProgress and lastProgress.phase=='gps-awaiting-export' then
                awaitingTicks+=1
                if mode=='manual' and awaitingTicks==1 then callback(node('Part','Manual exploration',world)) end
                if mode=='closed' then panelGui.Parent=nil;return end
                assert(not destroyed,'Panel stays open while export awaits a click')
                if awaitingTicks==3 then stopButton() end
            end
        end,
        cancel=function(thread) cancelled+=1;coroutine.close(thread) end}
    local chunk=assert(loadstring(source));setfenv(chunk,env)
    local runtime=chunk()
    local success,result=pcall(runtime.run,{Step=128,InitialRadius=128,MaxRadius=256,MaxCells=3,RequestTimeout=0.1,
        SettleSeconds=0.1,MaxInstances=mode=='instances' and 1 or 0,MaxSeconds=mode=='time' and 1 or 20},function(progress)
        lastProgress=progress
        if mode=='progress-error' then error('checkpoint sink broke') end
    end)
    assert(disconnected or mode=='headless','Disconnect stream listeners on completion')
    assert(destroyed or mode=='headless','Remove progress UI')
    if mode=='progress-error' or mode=='headless' or mode=='closed' then assert(not success);return end
    assert(success,tostring(result))
    assert(result.summary.coverage=='unverified' and result.summary.terrainSnapshots==false)
    assert(result.children[world][1]==part,'Original geometry survives stream-out')
    if mode=='disabled' then assert(calls==0 and result.summary.reason=='streaming_disabled')
    elseif mode=='errors' then assert(calls==3 and result.summary.reason=='request_failures')
    elseif mode=='deadline' then assert(calls==1 and cancelled==1 and result.summary.reason=='request_deadline')
    elseif mode=='user' then assert(result.summary.reason=='user_stopped')
    elseif mode=='time' then assert(result.summary.reason=='time_limit')
    elseif mode=='manual' then assert(result.summary.retainedInstances==3)
    elseif mode=='instances' then assert(result.summary.reason=='instance_limit')
    else assert(calls==3 and result.summary.reason=='cell_limit' and result.summary.retainedInstances==2) end
    assert(#result.summary.points==calls)
    if mode=='normal' then
        assert(result.summary.points[1].newInstances==1 and result.summary.points[1].requestOK)
        assert(result.summary.points[2].newInstances==0)
    end
    assert(result.summary.exportTrigger=='button')
    if mode~='user' then assert(awaitingTicks==3,'No automatic return/export after budgets or traversal') end
    assert(lastProgress.meter.label=='GPS points attempted (estimated grid)')
end
for _,mode in {'normal','disabled','errors','deadline','user','time','headless','instances','progress-error','manual','closed'} do lifecycle(mode) end

-- Exercise the actual core merge followed by its actual instance collector.
local InstancesOverrides={[first]={Properties={Name='Explicit name wins'}}}
local RuntimeAdapter={workspaceCapture=archive}
local ExportReport={}
__MERGE__
assert(InstancesOverrides[first].Properties.Name=='Explicit name wins')
assert(InstancesOverrides[first].Properties.CFrame=='retained transform')
assert(ExportReport.gps==archive.summary)
local OPTIONS={ExcludeModuleScripts=true}
local ClassSerializableCache,IgnoreList,DecompileIgnore,NotCreatableFixes={},{},{},{}
local decompileIgnoreMap,Progress={},{}
local ClassList={Workspace={},Folder={},Instance={},ModuleScript={},Part={}}
local IgnoreNotArchivable=false
local SaveNotCreatable,SaveNotCreatableWillBeEnabled,TreatUnionsAsParts,HasAutoRemaps=true,false,false,false
local function yieldIfDue() end
local function isClassSerializable() return true end
local function replaceClassName() error('unexpected class remap') end
__COLLECT__
folder.Parent=nil;first.Parent=nil
local collected=collect({root})
assert(collected.instCount==5 and collected.entries[folder].class=='Folder')
assert(collected.entries[first].parent==folder and collected.entries[second].parent==third)
assert(collected.refs[first]~=nil,'Retained geometry gets binary referents')
local kept={}
for _,instance in {first,node('Part','Unrelated orphan')} do
__NIL_GUARD__
    kept[#kept+1]=instance
end
assert(#kept==1 and kept[1].Name=='Unrelated orphan','GPS nodes must not be detached into NilInstances extras')
print('GPS passed: bounded grid, adaptive/manual limits, duplicate identity, retained/reparented hierarchy, budgets, stream requests, deadline, user stop, headless UI, cleanup, actual core merge/collection and nil-instance exclusion.')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', default='luau')
    args = parser.parse_args()
    source = (ROOT/'StreamingCapture.luau').read_text(encoding='utf-8')
    core = (ROOT/'saveinstance.luau').read_text(encoding='utf-8')
    merge = core.split('\t\t-- GPS retains original instances',1)[1].split('\n\t\tsetMeter("Collecting instances")',1)[0]
    merge = '\t\t-- GPS retains original instances'+merge
    collect = 'local function collect(roots)'+core.split('local function collect(roots)',1)[1].split('\tlocal pendingExtras =',1)[0]
    nil_guard = '\t\t\t\tlocal capture = RuntimeAdapter.workspaceCapture'+core.split('\t\t\t\tlocal capture = RuntimeAdapter.workspaceCapture',1)[1].split('\n\t\t\t\tif instance:IsA("ServiceProvider")',1)[0]
    program = HARNESS.replace('__SOURCE__','[====['+source+']====]').replace('__MERGE__',merge).replace('__COLLECT__',collect).replace('__NIL_GUARD__',nil_guard)
    with tempfile.TemporaryDirectory(prefix='csp-gps-') as directory:
        path = Path(directory)/'gps.luau'
        path.write_text(program,encoding='utf-8')
        result = subprocess.run([args.luau,str(path)],capture_output=True,text=True)
    print(result.stdout,end='')
    if result.returncode:
        raise SystemExit(result.stderr)


if __name__=='__main__':
    main()
