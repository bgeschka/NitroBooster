-- https://www.wowace.com/projects/ace3/pages/ace-gui-3-0-widgets


function bg_dbg(ctx, ...)
	if ctx.debug then
		-- local msg = ""
		-- for i,v in ipairs(arg) do
		--	msg = msg .. tostring(v) .. " "
		-- end
		print("[[" .. ctx.addonname .. "]] ", ...)
	end
end

function bg_playername()
	return GetUnitName("PLAYER")
end

function bg_event_handler_add(ctx, eventname, callback)
	bg_dbg(ctx, "registering eventhandlers", eventname);
	ctx.eventhandlers[eventname] = callback;
	ctx.frame_conv:RegisterEvent(eventname);
end

local timers = 0
function bg_timer_interval(ctx, interval_seconds, callback)
	timers = timers + 1;
	ctx.timers["u_"..timers] = {
		lastcall = 0,
		interval = interval_seconds,
		callback = callback
	}
end

function bg_context_new(addonname, configname, readycallback)
	local ctx = {
		addonname = addonname,
		configname = configname,
		loaded = false,
		debug = false,
		frame_conv = nil,
		frame_main = nil,
		eventhandlers = {},
		timers = {}
	}
	ctx.frame_conv = CreateFrame("Frame", addonname .."FrameForAddonLoad", UIParent);
	ctx.frame_conv:SetScript("OnUpdate", function(event, eventname, ...)
		-- print("updating:"..GetTime().. " event " .. eventname)
		local ctime = GetTime();
		for k, v in pairs(ctx.timers) do
			if (v.lastcall + v.interval) < ctime then
				v.callback(ctx);
				v.lastcall = ctime
			end
		end
	end)

	ctx.frame_conv:SetScript("OnEvent", function(event, eventname, ...)
		-- bg_dbg(ctx, "event:", eventname);
		if ctx.eventhandlers[eventname] then
			-- bg_dbg(ctx,"calling handler:", eventname);
			ctx.eventhandlers[eventname](...)
		end
	end);

	bg_event_handler_add(ctx, "ADDON_LOADED", function (...)
		if(ctx.loaded) then
			return;
		end
		ctx.loaded = true
		if _G[ctx.configname] == nil then
			_G[ctx.configname] = {
				-- empty storage object
			}
		end
		readycallback(ctx);
	end);
	return ctx;
end

function bg_dump_config(ctx)
	bg_dbg_table(_G[ctx.configname]);
end

-- my own lib, convenience functions
function bg_string_split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

bg_CLASSCOLORS = {
	DEATHKNIGHT	= {R = 0.77	,G = 0.12	,B = 0.23},
	DRUID		= {R = 1	,G = 0.49	,B = 0.04},
	HUNTER		= {R = 0.67	,G = 0.83	,B = 0.45},
	MAGE		= {R = 0.41	,G = 0.8	,B = 0.94},
	PALADIN		= {R = 0.96	,G = 0.55	,B = 0.73},
	PRIEST		= {R = 1	,G = 1		,B = 1},
	ROGUE		= {R = 1	,G = 0.96	,B = 0.41},
	SHAMAN		= {R = 0	,G = 0.44	,B = 0.87},
	WARLOCK		= {R = 0.58	,G = 0.51	,B = 0.79},
	WARRIOR		= {R = 0.78	,G = 0.61	,B = 0.43}
};

function bg_getclass()
	local class, CL = UnitClass("PLAYER");
	return CL;
end

function bg_slashcommand(ctx, slashcmd, cb)
	local str_globvar = "SLASH_"..ctx.addonname.."1"
	_G[str_globvar] = slashcmd;

	SlashCmdList[ctx.addonname] = function(msg)
		local t = bg_string_split(msg, " ");
		local param1 = t[1];
		local param2 = t[2];
		local param3 = t[3];
		cb(param1, param2, param3);
	end
end;


function bg_dbg_table (ctx, tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			bg_dbg(ctx, formatting)
			bg_dbg_table(ctx, v, indent+1)
		elseif type(v) == 'boolean' then
			bg_dbg(ctx,formatting .. tostring(v))
		else
			bg_dbg(ctx,formatting .. v)
		end
	end
end

function bg_frame_main_get(ctx)
	if ctx.frame_main == nil then
		local AceGUI = LibStub("AceGUI-3.0")
		ctx.AceGUI = AceGUI;
		local frame = AceGUI:Create("Frame")
		frame:SetTitle(ctx.addonname)
		frame:SetStatusText("made by pewz")
		--[[
		container:SetLayout(layout)
		Set the Layout this container should use when managing its child frames.
		Currently implemented Layouts in AceGUI-3.0:
		"Flow" - A row based flow layout
		"List" - A simple stacking layout
		"Fill" - Fill the whole container with the first widget (used by Groups)
		--]]

		frame:SetLayout("List")
		-- frame:SetLayout("Fill")

		ctx.frame_main = frame;
	end

	return ctx.frame_main;
end

function bg_bag_qty_by_link(link)
	local qty = 0;
	for i=0,NUM_BAG_SLOTS do
		for j=1,GetContainerNumSlots(i) do
			if GetContainerItemLink(i,j)==link then
				local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, ItemID, isBound = GetContainerItemInfo(i, j)
				if itemCount ~= nil then
					qty = qty + itemCount;
				end
			end
		end
	end

	return qty
end

function bg_bag_qty_by_id(ItemID)
	local itemName,link = GetItemInfo(ItemID);
	return bg_bag_qty_by_link(link);
end

function bg_bag_qty_by_id_enough(why ,ItemID, qty)
	local itemName,link=GetItemInfo(ItemID);
	local havqty = bg_bag_qty_by_link(link)
	if havqty >= qty then return true end
	print("not enough "..itemName .. " for " .. why .. " (x"..(qty - havqty)..")");
	return false;
end

function bg_config_print(ctx)
	print("config for:"..ctx.addonname);
	print("------------------------------");
	for k,v in pairs(_G[ctx.configname]) do
		print(" >> " .. k.." : " .. tostring(v));
	end
	print("------------------------------");
end

function bg_config_wipe(ctx)
	_G[ctx.configname] = {};
end

function bg_config_set(ctx, key, value)
	_G[ctx.configname][key] = value;
	if ctx.debug then
		bg_config_print(ctx);
	end
end

function bg_config_get(ctx, key)
	local value = _G[ctx.configname][key];
	return value
end

function bg_frame_main_add_config_EditBox(ctx, label, configfield, parent, cb)
	local eb = ctx.AceGUI:Create("EditBox")
	eb:SetLabel(label)
	eb:SetWidth(400)
	local startvalue = bg_config_get(ctx, configfield);
	if startvalue then
		eb:SetText(startvalue);
	end
	-- eb:DisableButton(true)
	eb:SetCallback("OnEnterPressed", function(widget, event, text)
		bg_config_set(ctx, configfield, text);
		if cb then
			cb()
		end
		-- widget:ClearFocus();
		return true;
	end)


	if parent then
		parent:AddChild(eb)
	else
		ctx.frame_main:AddChild(eb)
	end
	return eb;
end

function bg_frame_main_add_config_CheckBox(ctx, label, configfield)
	local config_checkbox = ctx.AceGUI:Create("CheckBox")
	config_checkbox:SetLabel(label)
	config_checkbox:SetWidth(400)
	config_checkbox:SetValue(false); --always start false
	local startvalue = bg_config_get(ctx, configfield);
	if startvalue == true then
		config_checkbox:SetValue(true);
	end
	config_checkbox:SetCallback("OnValueChanged", function(self, event, value)
		bg_config_set(ctx, configfield, value);
	end);
	ctx.frame_main:AddChild(config_checkbox)
end

function bg_bag_for_each(cb)
	for i=0,NUM_BAG_SLOTS do
		for j=1,GetContainerNumSlots(i) do
			cb(i,j);
		end
	end
end

function bg_string_append(str, append)
	return str .. append
end

function bg_string_append_nl(str, append)
	return bg_string_append(str,bg_string_append("\n",append));
end

function bg_bag_find_item(itemID)
	for bag = 0, 4 do
		local numSlots = GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local itemLink = GetContainerItemLink(bag, slot)
			if itemLink then
				local foundID = tonumber(string.match(itemLink, "item:(%d+):"))
				if foundID == itemID then
					return bag, slot
				end
			end
		end
	end
	return nil -- Not found
end

function bg_equip_item_by_id(itemID)
	local bag, slot = bg_bag_find_item(itemID)
	if bag and slot then
		UseContainerItem(bag, slot)
		return true -- Success
	end
	return false -- Not found or failed
end

function bg_table_len(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function bg_am_i_dead()
	if UnitIsDead("PLAYER") then
		return true
	else
		return false
	end
end

function bg_combat()
	if UnitAffectingCombat("player") then
		return true;
	end
	return false;
end
