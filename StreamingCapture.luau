-- CompleteSavePlace GPS collector. Experimental; references are retained, not cloned.
-- Requests standard Roblox streaming regions; does not move the character or change streaming settings.
local GPS = {}

local function numberOption(config, name, default, minimum, maximum)
	local value = config[name]
	if value == nil then return default end
	assert(type(value) == "number" and value == value and value >= minimum and value <= maximum,
		"GPS: invalid " .. name)
	return value
end

function GPS.settings(config)
	assert(config == nil or type(config) == "table", "GPS settings must be a table")
	config = config or {}
	return {
		Step = numberOption(config, "Step", 512, 128, 2048),
		InitialRadius = numberOption(config, "InitialRadius", 1024, 128, 8192),
		MaxRadius = numberOption(config, "MaxRadius", 4096, 128, 16384),
		MaxCells = math.floor(numberOption(config, "MaxCells", 196, 1, 1024)),
		MaxSeconds = numberOption(config, "MaxSeconds", 600, 1, 3600),
		MaxInstances = math.floor(numberOption(config, "MaxInstances", 300000, 1, 1000000)),
		RequestTimeout = numberOption(config, "RequestTimeout", 4, 0.1, 30),
		SettleSeconds = numberOption(config, "SettleSeconds", 1, 0, 10),
		Height = config.Height,
		Bounds = config.Bounds,
		AutoExpand = config.AutoExpand ~= false,
	}
end

function GPS.newPlanner(settings, origin)
	local planner = {settings=settings, origin=origin, visited={}, attempted=0}
	local radius = math.min(settings.InitialRadius, settings.MaxRadius)
	planner.minX, planner.maxX = origin.X-radius, origin.X+radius
	planner.minZ, planner.maxZ = origin.Z-radius, origin.Z+radius
	if settings.Bounds then
		local b = settings.Bounds
		assert(type(b) == "table" and b.Min and b.Max, "GPS Bounds requires Min and Max positions")
		for _, axis in {"X", "Z"} do
			local low, high = b.Min[axis], b.Max[axis]
			assert(type(low)=="number" and type(high)=="number" and low==low and high==high and low<=high,
				"GPS: invalid Bounds." .. axis)
			assert(math.abs(low-origin[axis])<=settings.MaxRadius and math.abs(high-origin[axis])<=settings.MaxRadius,
				"GPS: Bounds exceeds MaxRadius from the player")
		end
		planner.minX, planner.maxX = b.Min.X, b.Max.X
		planner.minZ, planner.maxZ = b.Min.Z, b.Max.Z
	end
	function planner:observe(position, extent)
		if self.settings.Bounds or not self.settings.AutoExpand then return end
		local limit = self.settings.MaxRadius
		local padding = math.min(extent or 0, self.settings.Step)
		self.minX = math.min(self.minX, math.max(origin.X-limit, position.X-padding))
		self.maxX = math.max(self.maxX, math.min(origin.X+limit, position.X+padding))
		self.minZ = math.min(self.minZ, math.max(origin.Z-limit, position.Z-padding))
		self.maxZ = math.max(self.maxZ, math.min(origin.Z+limit, position.Z+padding))
	end
	function planner:range()
		local step = self.settings.Step
		local limit = math.floor(self.settings.MaxRadius/step)
		return math.max(-limit,math.floor((self.minX-origin.X)/step)), math.min(limit,math.ceil((self.maxX-origin.X)/step)),
			math.max(-limit,math.floor((self.minZ-origin.Z)/step)), math.min(limit,math.ceil((self.maxZ-origin.Z)/step))
	end
	function planner:nextPoint()
		if self.attempted >= self.settings.MaxCells then return nil, "cell_limit" end
		local x0,x1,z0,z1 = self:range()
		local best, bestDistance
		for x=x0,x1 do
			for z=z0,z1 do
				local key = x .. ":" .. z
				local distance = x*x+z*z
				if not self.visited[key] and (not bestDistance or distance<bestDistance) then
					best, bestDistance = {x=x,z=z,key=key}, distance
				end
			end
		end
		if not best then return nil, "grid_exhausted" end
		self.visited[best.key] = true
		self.attempted += 1
		return {X=origin.X+best.x*self.settings.Step, Y=origin.Y, Z=origin.Z+best.z*self.settings.Step}
	end
	function planner:total()
		local x0,x1,z0,z1 = self:range()
		return (x1-x0+1)*(z1-z0+1)
	end
	return planner
end

function GPS.newArchive(root, maximum)
	local archive = {root=root, children={[root]={}}, properties={}, parents={}, count=0, limitReached=false}
	function archive:remember(object)
		if object == root then return end
		local chain, cursor = {}, object
		while cursor and cursor ~= root do
			chain[#chain+1] = cursor
			cursor = cursor.Parent
		end
		if cursor ~= root then return end -- ignore unrelated or already streamed-out objects
		for i=#chain,1,-1 do
			local item = chain[i]
			local parent = i == #chain and root or chain[i+1]
			if not self.children[item] then
				if self.count >= maximum then self.limitReached=true; return end
				self.children[item] = {}
				self.count += 1
				local values = {Name=item.Name}
				if item:IsA("BasePart") then
					values.CFrame, values.Size = item.CFrame, item.Size
				end
				self.properties[item] = values
			end
			local oldParent = self.parents[item]
			if oldParent ~= parent then
				if oldParent then
					local siblings = self.children[oldParent]
					local index = table.find(siblings,item)
					if index then table.remove(siblings,index) end
				end
				self.children[parent][#self.children[parent]+1] = item
				self.parents[item] = parent
			end
		end
	end
	return archive
end

local function makeUI(stop)
	local gui
	local ok, result = pcall(function()
		gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "CompleteSavePlaceGPS", false, 10000
		local panel = Instance.new("Frame")
		panel.Size, panel.Position = UDim2.fromOffset(390,134), UDim2.new(0.5,-195,0,42)
		panel.BackgroundColor3 = Color3.fromRGB(12,22,32)
		panel.Parent = gui
		local text = Instance.new("TextLabel")
		text.Size, text.Position = UDim2.new(1,-24,0,66), UDim2.fromOffset(12,6)
		text.BackgroundTransparency, text.TextWrapped = 1,true
		text.TextColor3, text.TextSize = Color3.fromRGB(220,245,240),15
		text.Parent = panel
		local track = Instance.new("Frame")
		track.Size, track.Position = UDim2.new(1,-24,0,6), UDim2.fromOffset(12,76)
		track.BackgroundColor3 = Color3.fromRGB(40,55,65)
		track.Parent = panel
		local fill = Instance.new("Frame")
		fill.Size, fill.BackgroundColor3 = UDim2.fromScale(0,1),Color3.fromRGB(98,230,193)
		fill.Parent = track
		local button = Instance.new("TextButton")
		button.Size, button.Position = UDim2.new(1,-24,0,32),UDim2.fromOffset(12,92)
		button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(98,230,193),Color3.fromRGB(12,22,32)
		button.Text, button.TextSize = "Exporter la collecte",14
		button.Parent = panel
		button.Activated:Connect(stop)
		local hiddenUI = gethui or get_hidden_gui
		gui.Parent = type(hiddenUI)=="function" and hiddenUI() or game:GetService("CoreGui")
		return {gui=gui,text=text,fill=fill}
	end)
	if not ok then
		if gui then gui:Destroy() end
		warn("[CSP GPS] Progress panel unavailable: " .. tostring(result))
		return nil
	end
	return result
end

function GPS.run(config, onProgress)
	local settings = GPS.settings(config)
	local players = game:GetService("Players")
	local player = assert(players.LocalPlayer,"GPS requires a local player")
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local origin = rootPart and rootPart.Position or workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
	assert(origin,"GPS: player position and camera are unavailable")
	local height = settings.Height
	if height ~= nil then
		assert(type(height)=="number" and height==height and math.abs(height)<100000,"GPS: invalid Height")
		origin = Vector3.new(origin.X,height,origin.Z)
	end
	local planner = GPS.newPlanner(settings,origin)
	local archive = GPS.newArchive(workspace,settings.MaxInstances)
	local summary = {experimental=true,coverage="unverified",boundsSource=settings.Bounds and "manual" or "observed_client_geometry",
		terrainSnapshots=false,step=settings.Step,maxCells=settings.MaxCells,maxSeconds=settings.MaxSeconds,
		maxRadius=settings.MaxRadius,maxInstances=settings.MaxInstances,requestFailures=0,requestsCompleted=0,
		requestTimeout=settings.RequestTimeout,settleSeconds=settings.SettleSeconds,autoExpand=settings.AutoExpand,
		points={},
		propertySnapshots="Name and BasePart CFrame/Size; remaining properties read during export",retention="original_instance_references"}
	local started, stopped, exportRequested, awaitingExport = os.clock(),false,false,false
	local pending, head = {},1
	local ui = makeUI(function() stopped=true;exportRequested=true end)
	assert(ui,"GPS: export requires the Exporter button; progress panel unavailable. No export started.")
	local connection, requestThread
	local function stopReason()
		if not ui.gui.Parent then return "panel_closed" end
		if stopped then return "user_stopped" end
		if archive.limitReached then return "instance_limit" end
		if os.clock()-started>=settings.MaxSeconds then return "time_limit" end
	end
	local function progress(operation)
		local total = planner:total()
		local value = {phase=awaitingExport and "gps-awaiting-export" or "gps",detail={operation=operation,pointsAttempted=planner.attempted,
			estimatedPoints=total,retainedInstances=archive.count,requestFailures=summary.requestFailures},
			meter={completed=planner.attempted,total=total,label="GPS points attempted (estimated grid)"}}
		if ui then
			ui.text.Text = string.format("CSP GPS · %d / ~%d points · %d objets\n%s · couverture non garantie",planner.attempted,total,archive.count,operation)
			ui.fill.Size = UDim2.fromScale(math.clamp(planner.attempted/math.max(total,1),0,1),1)
		end
		if onProgress then onProgress(value) end
	end
	local function remember(item)
		archive:remember(item)
		if item:IsA("BasePart") and item.Anchored then
			planner:observe(item.Position,item.Size.Magnitude/2)
		end
	end
	local function drain(manual)
		local processed = 0
		local lastYield = os.clock()
		while head<=#pending and (manual and not exportRequested and not archive.limitReached or not manual and not stopReason()) do
			local item = pending[head]
			head += 1
			remember(item)
			processed += 1
			if processed%128==0 or os.clock()-lastYield>=0.004 then task.wait();lastYield=os.clock() end
		end
		if head>#pending then table.clear(pending);head=1 end
	end
	local ok, failure = xpcall(function()
		connection = workspace.DescendantAdded:Connect(function(item)
			if #pending-head+1 >= settings.MaxInstances then archive.limitReached=true;return end
			pending[#pending+1]=item
		end)
		progress("Inventaire initial")
		local initial = workspace:GetDescendants()
		local lastYield, lastUpdate = os.clock(),os.clock()
		for i,item in initial do
			if stopReason() then break end
			remember(item)
			if i%128==0 or os.clock()-lastYield>=0.004 then
				task.wait()
				lastYield=os.clock()
				if os.clock()-lastUpdate>=0.25 then progress("Inventaire initial");lastUpdate=os.clock() end
			end
		end
		table.clear(initial)
		drain()
		if not workspace.StreamingEnabled then summary.reason="streaming_disabled" end
		while workspace.StreamingEnabled and not stopReason() do
			local point, reason = planner:nextPoint()
			if not point then summary.reason=reason;break end
			local cellStarted, countBefore = os.clock(),archive.count
			local cell = {x=point.X,y=point.Y,z=point.Z,requestReturned=false}
			summary.points[#summary.points+1]=cell
			progress("Chargement d'une zone")
			local done, requestOK, requestError = false,false,nil
			requestThread = task.spawn(function()
				requestOK,requestError = pcall(player.RequestStreamAroundAsync,player,Vector3.new(point.X,point.Y,point.Z),settings.RequestTimeout)
				done=true
			end)
			local deadline = os.clock()+settings.RequestTimeout+1
			while not done and not stopReason() and os.clock()<deadline do drain();task.wait(0.05) end
			if not done then
				summary.reason=stopReason() or "request_deadline"
				cell.elapsed, cell.newInstances = os.clock()-cellStarted,archive.count-countBefore
				break -- never accumulate outstanding streaming requests
			end
			requestThread=nil
			cell.requestReturned, cell.requestOK = true,requestOK
			if requestOK then summary.requestsCompleted+=1 else
				summary.requestFailures+=1
				summary.lastRequestError=tostring(requestError)
				if summary.requestFailures>=3 then
					summary.reason="request_failures"
					cell.elapsed, cell.newInstances = os.clock()-cellStarted,archive.count-countBefore
					break
				end
			end
			local settleUntil = os.clock()+settings.SettleSeconds
			while not stopReason() and os.clock()<settleUntil do drain();task.wait(0.05) end
			drain()
			cell.elapsed, cell.newInstances = os.clock()-cellStarted,archive.count-countBefore
			progress("Zone parcourue")
		end
		summary.reason=summary.reason or stopReason()
		if requestThread then pcall(task.cancel,requestThread);requestThread=nil end
		summary.automaticSeconds=os.clock()-started
		-- Budgets stop automatic requests, never authorize an export. Keep
		-- collecting manually visited regions within the object budget until click.
		local waitStarted = os.clock()
		awaitingExport = not exportRequested
		while not exportRequested do
			if not ui.gui.Parent then error("GPS panel closed; export was not requested",0) end
			if archive.limitReached then
				if connection then connection:Disconnect();connection=nil end
				table.clear(pending);head=1
			else
				drain(true)
			end
			progress(archive.limitReached and "Limite d'objets atteinte — clique sur Exporter" or "Parcours en pause — explore ou clique sur Exporter")
			task.wait(0.25)
		end
		summary.manualWaitSeconds = os.clock()-waitStarted
		summary.exportTrigger = "button"
	end,function(message) return tostring(message) end)
	if connection then connection:Disconnect() end
	if requestThread then pcall(task.cancel,requestThread) end
	if ui then ui.gui:Destroy() end
	table.clear(pending)
	if not ok then error("GPS collection failed: " .. failure,0) end
	summary.elapsed = os.clock()-started
	summary.pointsAttempted, summary.estimatedPoints = planner.attempted,planner:total()
	summary.retainedInstances = archive.count
	summary.bounds = {minX=planner.minX,maxX=planner.maxX,minZ=planner.minZ,maxZ=planner.maxZ,height=origin.Y}
	return {children=archive.children,properties=archive.properties,summary=summary}
end

return GPS
