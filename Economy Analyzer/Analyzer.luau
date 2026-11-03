-- CompleteSavePlace Economy Analyzer. Passive client observations; no remote calls or module execution.
local Analyzer = {Version="0.8.1"}
local families = {
	currencies={"money","cash","coin","currency","gems","diamond","gold","income","earn","balance"},
	levels={"level","rank","prestige"},
	xp={"xp","exp","experience"},
	rebirths={"rebirth","reincarnat","ascension"},
	prices={"price","cost","purchase","shop","upgrade","sell","reward"},
	multipliers={"multiplier","boost","double","bonus"},
	collection={"animal","catch","strength","power","luck","rarity","chance","weight","food"},
}
local order={"currencies","levels","xp","rebirths","prices","multipliers","collection"}

local function copy(value)
	if type(value)~="table" then return value end
	local result={}
	for key,item in value do result[key]=copy(item) end
	return result
end

local function finite(value)
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end

local function clipped(value, limit)
	local text=tostring(value)
	if #text<=limit then return text end
	local boundary=limit+1
	while boundary>1 and string.byte(text,boundary)>=128 and string.byte(text,boundary)<192 do boundary-=1 end
	return string.sub(text,1,boundary-1) .. "…"
end

function Analyzer.classify(label)
	local lower=string.gsub(label,"(%u)(%u%l)","%1 %2")
	lower=string.gsub(lower,"([%l%d])(%u)","%1 %2")
	lower=string.lower(string.gsub(lower,"[%W_]"," "))
	lower=" "..string.gsub(lower,"%s+"," ").." "
	local result={}
	for _,family in order do
		for _,word in families[family] do
			if string.find(lower," "..word.." ",1,true) or string.find(lower," "..word.."s ",1,true)
				or family=="currencies" and string.find(label,"$",1,true) then result[#result+1]=family;break end
		end
	end
	return result
end

function Analyzer.value(value)
	if type(value)=="number" then
		return {raw=tostring(value),number=finite(value) and value or nil,approximate=false}
	end
	if type(value)=="boolean" then return {raw=tostring(value),boolean=value,approximate=false} end
	local raw=clipped(value,256)
	local cleaned=string.gsub(raw,"<[^>]*>","")
	for grouped in string.gmatch(cleaned,"%d[%d,]*,%d[%d,]*") do
		local first=true
		for group in string.gmatch(grouped,"[^,]+") do
			if (first and #group>3) or (not first and #group~=3) then return {raw=raw,approximate=true} end
			first=false
		end
	end
	cleaned=string.gsub(cleaned,",","")
	local numerator,denominator=string.match(cleaned,"([%d%.]+)%s*/%s*([%d%.]+)")
	local number,suffix=string.match(cleaned,"([%+%-]?%d+%.?%d*)%s*([%a]*)")
	local scales={k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,qi=1e18,sx=1e21,sp=1e24,oc=1e27,no=1e30,dc=1e33}
	local parsed=number and tonumber(number)
	if suffix and suffix~="" then
		local scale=scales[string.lower(suffix)]
		if scale then parsed=parsed*scale
		elseif string.lower(suffix)~="xp" then parsed=nil end
	end
	return {raw=raw,number=finite(parsed) and parsed or nil,
		denominator=denominator and tonumber(denominator) or nil,approximate=true}
end

-- A small tokenizer for numeric assignment candidates. Comments and string
-- contents are never treated as executable expressions; nothing is evaluated.
function Analyzer.sourceCandidates(source, limit, yieldIfDue)
	local tokens,i,line={},1,1
	local function push(kind,text) tokens[#tokens+1]={kind=kind,text=text,line=line} end
	while i<=#source and #tokens<20000 do
		if yieldIfDue and i%512==0 then yieldIfDue() end
		local rest=string.sub(source,i,i+256)
		local c=string.sub(source,i,i)
		if c=="\n" then line+=1;i+=1
		elseif string.match(c,"%s") then i+=1
		else
			local comment=string.sub(rest,1,2)=="--"
			local start=i+(comment and 2 or 0)
			local equals=string.match(string.sub(source,start,start+32),"^%[(=*)%[")
			if equals then
				local a,b=string.find(source,"]"..equals.."]",start+2+#equals,true)
				local finish=b or #source
				local _,newlines=string.gsub(string.sub(source,i,finish),"\n","")
				line+=newlines;i=finish+1
			elseif comment then
				i=string.find(source,"\n",i,true) or #source+1
			elseif c=='"' or c=="'" then
				local quote,begin=c,i+1
				i+=1
				while i<=#source and string.sub(source,i,i)~=quote do
					if string.sub(source,i,i)=="\\" then i+=1 end
					if string.sub(source,i,i)=="\n" then line+=1 end
					i+=1
				end
				push("string",string.sub(source,begin,i-1));i+=1
			else
				local name=string.match(rest,"^[%a_][%w_]*")
				local number=string.match(rest,"^%d+%.?%d*[eE][%+%-]?%d+") or string.match(rest,"^%d+%.?%d*")
				if name then push("name",name);i+=#name
				elseif number then push("number",number);i+=#number
				else push("punct",c);i+=1 end
			end
		end
	end
	local found={}
	for n,token in tokens do
		local at=n+1
		local key=token.kind=="name" and token.text or nil
		if token.kind=="string" and tokens[n-1] and tokens[n-1].text=="[" and tokens[at] and tokens[at].text=="]" then
			key=token.text;at+=1
		end
		if key and #Analyzer.classify(key)>0 and tokens[at] and tokens[at].text=="=" then
			at+=1
			local sign=1
			if tokens[at] and tokens[at].text=="-" then sign=-1;at+=1 end
			local literal,nextToken=tokens[at],tokens[at+1]
			if literal and literal.kind=="number" and (not nextToken or not string.find("+-*/^%(.:",nextToken.text,1,true)) then
				local value=tonumber(literal.text)
				if finite(value) then
					found[#found+1]={key=key,number=sign*value,line=token.line,status="client_literal_candidate"}
					if #found>=limit then break end
				end
			end
		end
	end
	local hints={}
	for n,token in tokens do
		if token.text=="function" and #hints<8 then
			local names={}
			local at=n+1
			while tokens[at] and at<n+12 and tokens[at].text~="(" do names[#names+1]=tokens[at].text;at+=1 end
			local name=table.concat(names,"")
			if name=="" and tokens[n-1] and tokens[n-1].text=="=" and tokens[n-2] then name=tokens[n-2].text end
			if #Analyzer.classify(name)>0 then
				for k=at,math.min(#tokens,at+80) do
					local current=tokens[k]
					if current.text=="end" then break end
					if current.text=="return" then
						local expression={}
						for j=k+1,math.min(#tokens,k+40) do
							local t=tokens[j]
							if t.text=="end" or t.text==";" or t.line>current.line then break end
							if t.kind=="string" then table.clear(expression);break end
							expression[#expression+1]=t.text
						end
						if #expression>0 then hints[#hints+1]={name=name,line=current.line,expression=clipped(table.concat(expression," "),240),status="client_return_expression_candidate"} end
						break
					end
				end
			end
		end
	end
	return found,#tokens>=20000 or #found>=limit,hints
end

function Analyzer.newState(metadata, limits)
	local state={metadata=metadata,limits=limits,findings={},events={},markers={},modules={},
		counts={eventChanges=0,eventsDropped=0,findingsDropped=0,instancesScanned=0,scanLimited=false},active=true}
	function state:add(path,label,kind,value,when)
		if #self.findings>=limits.MaxFindings then self.counts.findingsDropped+=1;return nil end
		local row={id=#self.findings+1,path=path,label=label,kind=kind,categories=Analyzer.classify(label),
			status=kind=="ui_text" and "display_observation" or "replicated_observation",first=Analyzer.value(value),latest=Analyzer.value(value),firstAt=when,lastAt=when}
		self.findings[#self.findings+1]=row
		row.observedMin,row.observedMax,row.samples=row.first.number,row.first.number,1
		return row
	end
	function state:change(row,value,when)
		local parsed=Analyzer.value(value)
		if parsed.raw==row.latest.raw then return end
		local old=row.latest
		row.latest,row.lastAt=parsed,when
		row.samples+=1
		if parsed.number then
			row.observedMin=math.min(row.observedMin or parsed.number,parsed.number)
			row.observedMax=math.max(row.observedMax or parsed.number,parsed.number)
		end
		self.counts.eventChanges+=1
		if #self.events>=limits.MaxEvents then self.counts.eventsDropped+=1;return end
		local delta=old.number and parsed.number and parsed.number-old.number or nil
		self.events[#self.events+1]={findingId=row.id,at=when,before=old.raw,after=parsed.raw,
			delta=finite(delta) and delta or nil,
			approximate=old.approximate or parsed.approximate,
			markerId=#self.markers>0 and #self.markers or nil,causality="not_established"}
	end
	function state:mark(label,when)
		if #self.markers>=200 then return false end
		self.markers[#self.markers+1]={id=#self.markers+1,label=clipped(label,120),at=when,
			note="User label; subsequent changes are associated in time, not proven effects"}
		return true
	end
	return state
end

function Analyzer.snapshot(state, elapsed)
	local systems={}
	for _,name in order do systems[name]={status="not_observed",findingIds={}} end
	local findings={}
	for _,row in state.findings do
		findings[#findings+1]=copy(row)
		for _,name in row.categories do
			systems[name].status="candidates_observed"
			systems[name].findingIds[#systems[name].findingIds+1]=row.id
		end
	end
	return {schemaVersion=1,analyzerVersion=Analyzer.Version,metadata=table.clone(state.metadata),
		elapsed=elapsed,active=state.active,stopReason=state.stopReason,scanError=state.scanError,
		limits=table.clone(state.limits),counts=table.clone(state.counts),
		findings=findings,events=copy(state.events),markers=copy(state.markers),modules=copy(state.modules),systems=systems,
		unknowns={xpFormula="not_verified",levelCap="not_verified",rebirthCap="not_verified",serverRules="unavailable_from_client_only",
			economyCompleteness="not_established",dropProbabilities="not_verified"},
		limitations={"No module is required or executed; no remote is called or hooked.",
			"Client literals and decompiled text are candidates, not authoritative server rules.",
			"UI numbers can be abbreviated, rounded, hidden or stale; event association does not establish causality.",
			"Not observed does not mean absent. No level/rebirth cap is inferred from current values or leaderboards."}}
end

function Analyzer.escape(value)
	local text=tostring(value)
	return (string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(text,"&","&amp;"),"<","&lt;"),">","&gt;"),'"',"&quot;"),"'","&#39;"))
end

function Analyzer.html(report)
	local h=Analyzer.escape
	local parts={[[<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Economy Analyzer</title><style>
body{font:15px system-ui;background:#09131c;color:#e1edf1;margin:0;padding:32px}main{max-width:1100px;margin:auto}h1,h2{color:#81efce}section,article{background:#12212d;border:1px solid #29434d;border-radius:12px;padding:18px;margin:16px 0}small{color:#a8bac6}code{overflow-wrap:anywhere}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:9px;border-bottom:1px solid #29434d;vertical-align:top}th{color:#81efce}p{line-height:1.6}.badge{font-size:12px;color:#ffdc90}li{margin:9px 0}</style><main><h1>Economy Analyzer</h1><p class="badge">Observations client — économie complète et règles serveur non vérifiées</p>]]}
	parts[#parts+1]="<section><b>"..h(report.metadata.gameName).."</b><p>Place "..h(report.metadata.placeId).." · Version "..h(report.analyzerVersion).." · "..h(math.floor(report.elapsed)).." s</p><p>"..#report.findings.." champs · "..#report.events.." changements conservés · "..#report.modules.." sources examinées</p></section>"
	for _,category in order do
		parts[#parts+1]="<section><h2>"..h(category).."</h2><p>"..h(report.systems[category].status).."</p><table><tr><th>Champ / source</th><th>Début → actuel</th><th>Statut</th></tr>"
		for _,id in report.systems[category].findingIds do
			local row=report.findings[id]
			parts[#parts+1]="<tr><td>"..h(row.label).."<br><small><code>"..h(row.path).."</code></small></td><td>"..h(row.first.raw).." → "..h(row.latest.raw).."</td><td>"..h(row.status).."</td></tr>"
		end
		parts[#parts+1]="</table></section>"
	end
	parts[#parts+1]="<section><h2>Configurations candidates</h2>"
	for _,module in report.modules do
		parts[#parts+1]="<article><code>"..h(module.path).."</code><p>"..h(module.status).."</p><ul>"
		for _,literal in module.literals or {} do
			parts[#parts+1]="<li>"..h(literal.key).." = "..h(literal.number).." · ligne "..h(literal.line).." · "..h(literal.status).."</li>"
		end
		for _,hint in module.formulaHints or {} do
			parts[#parts+1]="<li>"..h(hint.name).." : <code>return "..h(hint.expression).."</code> · "..h(hint.status).."</li>"
		end
		parts[#parts+1]="</ul></article>"
	end
	parts[#parts+1]="</section><section><h2>Actions marquées</h2><ul>"
	for _,marker in report.markers do parts[#parts+1]="<li>"..h(marker.at).." s — "..h(marker.label).."</li>" end
	parts[#parts+1]="</ul><p>Association temporelle uniquement : un achat ou une vente n'est pas déduit automatiquement d'un changement.</p></section><section><h2>Changements observés</h2><table><tr><th>Temps</th><th>Champ</th><th>Changement</th></tr>"
	for _,event in report.events do
		parts[#parts+1]="<tr><td>"..h(event.at).." s</td><td>"..h(report.findings[event.findingId].label).."</td><td>"..h(event.before).." → "..h(event.after).."</td></tr>"
	end
	parts[#parts+1]="</table></section><section><h2>Inconnues et limites</h2><ul>"
	for key,value in report.unknowns do parts[#parts+1]="<li>"..h(key).." : "..h(value).."</li>" end
	for _,value in report.limitations do parts[#parts+1]="<li>"..h(value).."</li>" end
	parts[#parts+1]="<li>Événements non conservés : "..h(report.counts.eventsDropped).." ; champs ignorés faute de place : "..h(report.counts.findingsDropped).." ; scan limité : "..h(report.counts.scanLimited)..".</li></ul></section></main></html>"
	return table.concat(parts)
end

local function limit(config,name,default,minimum,maximum)
	local value=config[name]
	if value==nil then return default end
	assert(finite(value) and value>=minimum and value<=maximum,"Economy Analyzer: invalid "..name)
	return value
end

function Analyzer.start(config)
	config=config or {}
	assert(type(config)=="table","Economy Analyzer settings must be a table")
	config=table.clone(config)
	local limits={MaxFindings=limit(config,"MaxFindings",500,1,3000),MaxEvents=limit(config,"MaxEvents",2000,1,20000),
		MaxInstances=limit(config,"MaxInstances",30000,1,200000),MaxSeconds=limit(config,"MaxSeconds",600,1,7200),
		MaxModules=limit(config,"MaxModules",20,0,100),MaxSourceBytes=limit(config,"MaxSourceBytes",100000,100,500000),
		SourceTimeout=limit(config,"SourceTimeout",3,0.1,10)}
	local player=assert(game:GetService("Players").LocalPlayer,"A local player is required")
	local storage=game:GetService("ReplicatedStorage")
	local http=game:GetService("HttpService")
	local gameName="Place "..tostring(game.PlaceId)
	pcall(function() gameName=game:GetService("MarketplaceService"):GetProductInfoAsync(game.PlaceId).Name end)
	local state=Analyzer.newState({placeId=game.PlaceId,gameName=gameName,
		profile=game.PlaceId==120219252362013 and "animal_progression_discovery" or "generic_discovery",
		profileNote="Discovery hints only; no game formula is assumed",decompileEnabled=config.Decompile==true},limits)
	local started=os.clock()
	local function elapsed() return math.floor((os.clock()-started)*1000)/1000 end
	local session={state=state}
	local connections,tracked,seenModules={},{},{}
	local sourcesClosed,sourceBusy,scanBusy=false,false,false
	local latestModuleQueue={}
	local gui,status,actionBox
	local feedbackUntil=0
	local function disconnect()
		for _,connection in connections do pcall(function() connection:Disconnect() end) end
		table.clear(connections)
		table.clear(tracked)
	end
	function session:stop(reason)
		state.stopReason=state.stopReason or reason or "user_stopped"
		state.active=false;disconnect()
		if status then status.Text="Observation arrêtée — le rapport reste exportable" end
	end
	function session:mark(label) return state:mark(label or "Action",elapsed()) end
	function session:snapshot() return Analyzer.snapshot(state,elapsed()) end
	function session:destroy() self:stop();if gui then gui:Destroy() end end
	local function safePath(object)
		local path=object:GetFullName()
		local prefix=player:GetFullName()
		if string.sub(path,1,#prefix)==prefix then path="LocalPlayer"..string.sub(path,#prefix+1) end
		return clipped(path,400)
	end
	local function excluded(object)
		local path=string.lower(safePath(object))
		if string.find(path,"economyanalyzer",1,true) then return true end
		for _,word in {"leaderboard","playerlist","chat","password","secret","token","sessionid"} do
			if string.find(path,word,1,true) then return true end
		end
		local cursor=object
		while cursor and cursor.Parent~=storage do cursor=cursor.Parent end
		if cursor and string.lower(cursor.Name)=="playerdata" then
			local child=object
			while child and child.Parent~=cursor do child=child.Parent end
			return not child or (child.Name~=player.Name and child.Name~=tostring(player.UserId))
		end
		return false
	end
	local function observe(object,field,label,kind,read,signal)
		local lower=string.lower(label)
		for _,word in {"password","secret","token","sessionid","authkey"} do
			if string.find(lower,word,1,true) then return end
		end
		local fields=tracked[object]
		if fields and fields[field] then return end
		if #Analyzer.classify(label)==0 then return end
		local ok,value=pcall(read)
		if not ok or (type(value)~="number" and type(value)~="string" and type(value)~="boolean") then return end
		if kind=="ui_text" and not Analyzer.value(value).number then return end
		local row=state:add(safePath(object).."."..field,label,kind,value,elapsed())
		if not row then return end
		if not fields then fields={};tracked[object]=fields end
		fields[field]=row
		local lastUI=-math.huge
		local connected,connection=pcall(function()
			return signal():Connect(function()
				if not state.active then return end
				local good,nextValue=pcall(read)
				if not good then return end
				if kind=="ui_text" and os.clock()-lastUI<0.25 then
					state.counts.eventsDropped+=1;row.latest=Analyzer.value(nextValue);row.lastAt=elapsed();return
				end
				lastUI=os.clock()
				state:change(row,nextValue,elapsed())
			end)
		end)
		if connected then connections[#connections+1]=connection end
	end
	local function inspectModule(object)
		if seenModules[object] or #state.modules>=limits.MaxModules or sourcesClosed then return end
		if #Analyzer.classify(object.Name.." "..safePath(object))==0 and not string.find(string.lower(object.Name),"config",1,true) then return end
		seenModules[object]=true
		local row={path=safePath(object),status="unreadable_or_empty",literals={}}
		state.modules[#state.modules+1]=row
		local ok,source=pcall(function() return object.Source end)
		if (not ok or type(source)~="string" or source=="") and config.Decompile==true and type(decompile)=="function" then
			local done=false
			local thread=task.spawn(function() ok,source=pcall(decompile,object);done=true end)
			local deadline=os.clock()+limits.SourceTimeout
			while not done and state.active and os.clock()<deadline do task.wait(0.05) end
			if not done then
				pcall(task.cancel,thread);sourcesClosed=true;row.status="decompile_deadline";return
			end
			row.sourceMethod="decompile"
		else row.sourceMethod="Source_property" end
		if not ok or type(source)~="string" or source=="" then return end
		row.bytes=#source
		row.sourceTruncated=#source>limits.MaxSourceBytes
		source=string.sub(source,1,limits.MaxSourceBytes)
		local lastYield=os.clock()
		row.literals,row.parserLimited,row.formulaHints=Analyzer.sourceCandidates(source,64,function()
			if os.clock()-lastYield>=0.004 then task.wait();lastYield=os.clock() end
		end)
		row.status="client_source_candidates"
	end
	local function scan()
		local roots={player,storage}
		local count,lastYield=0,os.clock()
		local moduleQueue={}
		local function priority(object)
			local name=string.lower(object.Name)
			return (string.find(name,"data",1,true) or string.find(name,"config",1,true)) and 0 or 1
		end
		local function queueModule(object)
			if limits.MaxModules==0 then return end
			if #Analyzer.classify(object.Name.." "..safePath(object))==0 and not string.find(string.lower(object.Name),"config",1,true) then return end
			if #moduleQueue<limits.MaxModules*5 then moduleQueue[#moduleQueue+1]=object;return end
			-- Late-discovered data modules must not be starved by client controllers.
			for i=#moduleQueue,1,-1 do
				if priority(object)<priority(moduleQueue[i]) then moduleQueue[i]=object;return end
			end
		end
		for _,root in roots do
			-- Breadth-first and per-root quotas keep a large GUI or asset folder
			-- from hiding the other root and avoid materializing all descendants.
			local items,index={root},1
			local budget=math.max(1,math.floor(limits.MaxInstances/#roots))
			while index<=#items and index<=budget do
				local object=items[index];index+=1
				if not state.active then return end
				count+=1
				if count>limits.MaxInstances then state.counts.scanLimited=true;break end
				if not excluded(object) then
					local path=safePath(object)
					local ok,attributes=pcall(function() return object:GetAttributes() end)
					if ok then
						for key in attributes do
							local lower=string.lower(key)
							if not string.find(lower,"token",1,true) and not string.find(lower,"secret",1,true) then
								observe(object,"@"..key,key,"replicated_attribute",function() return object:GetAttribute(key) end,function() return object:GetAttributeChangedSignal(key) end)
							end
						end
					end
					if object:IsA("ValueBase") then
						observe(object,"Value",path,"replicated_value",function() return object.Value end,function() return object:GetPropertyChangedSignal("Value") end)
					elseif object:IsA("TextLabel") or object:IsA("TextButton") then
						observe(object,"Text",path.." "..clipped(object.Text,120),"ui_text",function() return object.Text end,function() return object:GetPropertyChangedSignal("Text") end)
					elseif object:IsA("ModuleScript") then queueModule(object) end
					for _,child in object:GetChildren() do
						if #items<budget then items[#items+1]=child else state.counts.scanLimited=true;break end
					end
				end
				state.counts.instancesScanned=count
				if count%128==0 or os.clock()-lastYield>=0.004 then task.wait();lastYield=os.clock() end
			end
		end
		table.sort(moduleQueue,function(a,b)
			if priority(a)~=priority(b) then return priority(a)<priority(b) end
			return safePath(a)<safePath(b)
		end)
		latestModuleQueue=moduleQueue
		for _,object in moduleQueue do
			if not state.active then break end
			inspectModule(object)
		end
	end
	function session:analyzeSources()
		assert(state.active,"Restart observation before analyzing sources")
		assert(not scanBusy,"Discovery is in progress; retry source analysis when it finishes")
		assert(not sourceBusy,"A source pass is already running")
		assert(type(decompile)=="function","This runtime has no decompile function; readable Source properties were already inspected")
		sourceBusy=true
		config.Decompile=true;state.metadata.decompileEnabled=true
		sourcesClosed=false;table.clear(seenModules);table.clear(state.modules)
		local ok,err=pcall(function()
			for _,object in latestModuleQueue do
				if not state.active or sourcesClosed then break end
				inspectModule(object)
			end
		end)
		sourceBusy=false
		assert(ok,tostring(err))
		return #state.modules
	end
	function session:export()
		assert(type(writefile)=="function" and type(makefolder)=="function" and type(isfolder)=="function","Report export requires writefile, makefolder and isfolder")
		local title=string.gsub(gameName,'[<>:"/\\|?*%c]'," ")
		title=string.gsub(title,"%s+"," ");title=string.gsub(title,"[%. ]+$","")
		title=clipped(title,64)
		local function folderFor(name)
			for n=1,9999 do
				local path=name.." - Economy Analysis"..(n==1 and "" or " ("..n..")")
				if not isfolder(path) and (type(isfile)~="function" or not isfile(path)) then
					makefolder(path)
					if isfolder(path) then return path end
					error("Output folder was not created",0)
				end
			end
			error("No free report folder",0)
		end
		local ok,folder=pcall(folderFor,title)
		if not ok and string.find(title,"[\128-\255]") then
			title=string.gsub(title,"[\128-\255]","")
			title=string.gsub(string.gsub(title,"^%s+",""),"%s+$","")
			if title=="" then title="Place "..game.PlaceId end
			ok,folder=pcall(folderFor,title)
		end
		assert(ok,tostring(folder))
		local report=self:snapshot()
		local json,html=http:JSONEncode(report),Analyzer.html(report)
		writefile(folder.."/report.json",json)
		writefile(folder.."/report.html",html)
		if type(readfile)=="function" then
			assert(readfile(folder.."/report.json")==json and readfile(folder.."/report.html")==html,"Report readback did not match")
		end
		print("[Economy Analyzer] Reports written: "..folder.."/report.json and report.html (coverage unverified)")
		return folder
	end
	local function ui()
		gui=Instance.new("ScreenGui");gui.Name="EconomyAnalyzer";gui.ResetOnSpawn=false
		local panel=Instance.new("Frame");panel.Size=UDim2.fromOffset(420,248);panel.Position=UDim2.new(1,-440,0,40)
		panel.BackgroundColor3=Color3.fromRGB(12,23,33);panel.Parent=gui
		status=Instance.new("TextLabel");status.Size=UDim2.new(1,-24,0,60);status.Position=UDim2.fromOffset(12,8)
		status.BackgroundTransparency=1;status.TextWrapped=true;status.TextSize=15;status.TextColor3=Color3.fromRGB(210,245,235);status.Parent=panel
		actionBox=Instance.new("TextBox");actionBox.PlaceholderText="Action à marquer : vente, achat, rebirth…";actionBox.Text=""
		actionBox.Size=UDim2.new(1,-24,0,34);actionBox.Position=UDim2.fromOffset(12,74);actionBox.TextSize=14;actionBox.Parent=panel
		local function button(text,y,fn)
			local b=Instance.new("TextButton");b.Text=text;b.Size=UDim2.new(1,-24,0,28);b.Position=UDim2.fromOffset(12,y)
			b.BackgroundColor3=Color3.fromRGB(100,230,195);b.TextSize=14;b.Parent=panel
			b.Activated:Connect(function()
				local ok,err=pcall(fn)
				if not ok then warn("[Economy Analyzer] "..tostring(err));status.Text=clipped(err,150) end
			end)
		end
		button("Marquer l'action",116,function() session:mark(actionBox.Text~="" and actionBox.Text or "Action");actionBox.Text="" end)
		button("Exporter le rapport (sans arrêter l'observation)",148,function()
			local folder=session:export();status.Text="Rapport écrit : "..folder;feedbackUntil=os.clock()+4
		end)
		button("Analyser les modules (décompilation en lecture seule)",180,function()
			status.Text="Analyse des sources accessibles…"
			local count=session:analyzeSources();status.Text=tostring(count).." sources examinées — règles serveur non vérifiées";feedbackUntil=os.clock()+4
		end)
		button("Arrêter l'observation",212,function() session:stop() end)
		local hidden=gethui or get_hidden_gui
		gui.Parent=type(hidden)=="function" and hidden() or game:GetService("CoreGui")
	end
	if config.ShowUI~=false then
		local ok,err=pcall(ui)
		if not ok then if gui then gui:Destroy();gui=nil end;warn("[Economy Analyzer] Panel unavailable; use the session API: "..tostring(err)) end
	end
	local function refresh()
		if status and state.active and os.clock()>=feedbackUntil then status.Text=string.format("Economy Analyzer · %d champs · %d changements\nLecture seule — règles serveur non vérifiées",#state.findings,#state.events) end
	end
	scanBusy=true
	local ok,err=pcall(scan)
	scanBusy=false
	if not ok then session:destroy();error("Economy initial scan failed: "..tostring(err),0) end
	refresh()
	session.worker=task.spawn(function()
		local lastScan=os.clock()
		while state.active do
			task.wait(0.5)
			if not state.active then break end
			if gui and not gui.Parent then session:stop("panel_closed");break end
			if elapsed()>=limits.MaxSeconds then session:stop("time_limit");break end
			if not sourceBusy and os.clock()-lastScan>=10 then
				scanBusy=true
				local good,failure=pcall(scan)
				scanBusy=false
				if not good then state.scanError=clipped(failure,256);session:stop("scan_error");break end
				lastScan=os.clock()
			end
			refresh()
		end
	end)
	print("[Economy Analyzer] Passive observation started. Export is manual; server formulas and caps remain unverified.")
	return session
end

return Analyzer
