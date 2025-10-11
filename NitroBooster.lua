local NITRO_SPELLID = 54861
local NB_BOOTS_MAX = 5

function nb_boots_get_config(ctx)
	-- local name = GetUnitName("Player");
	-- nb_load_boots_from_gui(ctx);
	local conf = bg_config_get(ctx, "boots");
	if not conf then
		bg_dbg(ctx, "empty config, creating new");
		bg_config_set(ctx, "boots", {})
		conf = bg_config_get(ctx, "boots");
	end
	return conf;
end


function nb_item_get_state(ctx, itemid)
	local ctime = GetTime();
	local equipped_boots = GetInventoryItemID("player", 8)
	local equipped = itemid == equipped_boots;
	local started = 0;
	local duration = 0;
	local enable = 0;
	if equipped_boots == itemid then
		started, duration, enable = GetItemCooldown(itemid)
	else
		local bag, slot = bg_bag_find_item(itemid);
		if bag == nil or slot == nil then
			bg_dbg(ctx, "something went wrong bag index/slot index getting status of "..itemid);
			return
		else
			started, duration, enable = GetContainerItemCooldown(bag, slot)
		end
	end

	local cd_left = (started+duration)-ctime;
	if started == 0 then
		cd_left = 0
	end

	-- boots in bag and unused, but equipping will trigger cd
	if not equipped and cd_left < 30 then
		cd_left = 30
	end


	return {
		cd_left = cd_left,
		equipped = equipped,
		usable = (itemid == equipped_boots) and cd_left <= 0
	}
end

function nb_del_boots(ctx, itemid)
	local boots = nb_boots_get_config(ctx);
	bg_dbg(ctx, "deleting boots:" .. itemid);
	boots[itemid] = nil ;-- nb_item_get_cd(ctx, itemid)
end


function nb_add_boots(ctx, itemid, prio, link)
	local boots = nb_boots_get_config(ctx);
	if boots[itemid] then
		bg_dbg(ctx, "boots already there: " .. itemid);
		return
	end
	bg_dbg(ctx, "adding boots:" .. itemid);
	boots[itemid] = {
		prio = prio,
		link = link
	} ;-- nb_item_get_cd(ctx, itemid)
end

function nb_add_boots_test(ctx)
	nb_add_boots(ctx, 49907) -- [Boots of Kingly Upheaval]
	nb_add_boots(ctx, 40742) -- [Bladed Steelboots]
	nb_add_boots(ctx, 40743) -- [Kyzoc's Ground Stompers]
	nb_add_boots(ctx, 45166) -- [Charred Saronite Greaves]
	nb_add_boots(ctx, 47885) -- [Greaves of the Lingering Vortex]
end

function nb_boots_update(ctx)
	local ctime = GetTime();
	local boots = nb_boots_get_config(ctx);
	for k, v in pairs(boots) do
		local prio = boots[k].prio;
		local link = boots[k].link;

		boots[k] = nb_item_get_state(ctx, k)

		boots[k].prio = prio
		boots[k].link = link
	end
end

function nb_get_equipped(ctx)
	local boots = nb_boots_get_config(ctx);
	for k, v in pairs(boots) do
		if v.equipped == true then
			return v
		end
	end
	return nil
end

function PlayerHasBuff(buffName)
	local i = 1
	while true do
		local name = UnitBuff("player", i)
		if not name then
			break -- No more buffs
		end
		if name == buffName then
			return true
		end
		i = i + 1
	end
	return false
end

function nb_next(ctx)

	if UnitAffectingCombat("player") then
		-- print("cannot change in combat");
		return false;
	end

	if bg_am_i_dead() then
		return false;
	end

	-- if PlayerHasBuff("Nitro Boosts") then
	--	-- print("already boooosting");
	--	return false;
	-- end

	local lowest_cd = 300;
	local lowest_cd_item = "";
	local equipped = false;
	local boots = nb_boots_get_config(ctx);
	if bg_table_len(boots) < 1 then
		-- print("no boots");
		return
	end

	-- local prio = 0;
	for k, v in pairs(boots) do
		if ( boots[k].cd_left + boots[k].prio ) < lowest_cd then
			lowest_cd = boots[k].cd_left
			equipped  = boots[k].equipped
			lowest_cd_item = k
			lowest_cd_item_link = boots[k].link
		end
	end

	if equipped then
		return false;
	end
	bg_dbg(ctx, "equipping :: next lowest cd has:"..lowest_cd_item_link .. " cd:"..lowest_cd);
	bg_equip_item_by_id(lowest_cd_item);
end

function nb_config_name_by_idx_gui(idx)
	return bg_playername() .. "gui_nitro_boots_" .. idx
end

function nb_load_boots_from_gui(ctx)
	-- return just itemids in table
	bg_config_set(ctx, "boots", {});
	local ret = {};
	for idx=1,NB_BOOTS_MAX do
		local itemLink = bg_config_get(ctx, nb_config_name_by_idx_gui(idx));
		if itemLink then
			local itemID = tonumber(strmatch(itemLink, "item:(%d+)"))
			if itemID then
				print("adding boots:"..itemLink);
				nb_add_boots(ctx, itemID, idx, itemLink);
			end
		end
	end
end

local gui_built = false
function nb_gui(ctx)
	local topcontainer = bg_frame_main_get(ctx);
	if not gui_built then
		bg_frame_main_add_config_CheckBox(ctx, "Enable auto-swap", "enabled");
		for idx=1,NB_BOOTS_MAX do
			bg_frame_main_add_config_EditBox(ctx, "pair_"..idx , nb_config_name_by_idx_gui(idx), nil, function()
				nb_load_boots_from_gui(ctx);
			end)
		end
		bg_frame_main_add_config_EditBox(ctx, "Interval in seconds/fractions (needs ui reload, default 0.1)", "interval")
		bg_frame_main_add_config_CheckBox(ctx, "Debug (needs ui reload)", "debug");
		gui_built = true
	end

	topcontainer:Show();
end

function nb_config_get_interval(ctx)
	local default = 0.1
	local interval= default 
	if bg_config_get(ctx, "interval") then
		interval = tonumber(bg_config_get(ctx, "interval"))
		if not interval  then
			interval = default
		end
	end
	return interval
end

function nb_print_help()
	print("Welcome to Nitrobooster!")
	print(" /nb gui -- show config window")
	print(" /nb list -- show current boots")
	print(" /nb reset -- resets the configuration");
end

bg_context_new("NitroBooster", "NitroBoosterConfig", function(ctx)
	ctx.debug = bg_config_get(ctx, "debug");
	bg_slashcommand(ctx, "/nb", function (param1, param2, param3)
		local boots = nb_boots_get_config(ctx);

		if param1 == "test" then
			nb_add_boots_test(ctx);
			return false;
		end
		if param1 == "update" then
			nb_boots_update(ctx);
			return false;
		end
		if param1 == "add" then
			nb_add_boots(ctx,tonumber(param2));
			bg_dbg_table(ctx, boots, 2)
			return false;
		end
		if param1 == "del" then
			nb_del_boots(ctx,tonumber(param2));
			bg_dbg_table(ctx, boots, 2)
			return false;
		end
		if param1 == "reset" then
			-- bg_config_set(ctx, "boots", {});
			bg_config_wipe(ctx);
			return false;
		end
		if param1 == "gui" or param1 == "conf" or param1 == "config" then
			nb_gui(ctx);
			return false;
		end
		if param1 == "dump" then
			-- bg_dump_config(ctx);
			return false;
		end
		if param1 == "loadgui" then
			nb_load_boots_from_gui(ctx);
			return false;
		end
		if param1 == "list" then
			bg_dbg(ctx, "listing boots>>>>");
			bg_dbg_table(ctx, boots, 2);
			bg_dbg(ctx, "done listing boots<<<<");
			return false;
		end


		if param1 == "toggle" then
			local state = bg_config_get(ctx, "enabled")
			local newstate = not state
			bg_config_set(ctx, "enabled", newstate)
			if newstate then
				print("NitroBooster enabled");
			else
				print("NitroBooster diabled");
			end
			return false;
		end

		-- equip the next pair of boots that are ready to use
		if param1 == "next" then
			nb_next(ctx);
			return false;
		end
		-- if param1 == "run" then
		--	bh_run(ctx);
		--	return false;
		-- end
		-- print("hi");
		-- bg_dbg(ctx, "hiiii!");
		--
		nb_print_help();
	end);

	bg_timer_interval(ctx, nb_config_get_interval(ctx), function (ctx)
		local enabled = bg_config_get(ctx, "enabled")
		if enabled then
			nb_boots_update(ctx);
			nb_next(ctx);
		end
	end);

	nb_load_boots_from_gui(ctx);

	-- bg_event_handler_add(ctx, "OnUpdate", function(ctx)
	--	print("update?! " .. GetTime())
	-- end)
	--
	-- nb_add_boots_test(ctx);

end);
