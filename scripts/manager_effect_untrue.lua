local onEffectActorStartTurnOriginal;
local parseEffectCompOriginal;
local removeEffectByTypeOriginal;
local getEffectsByTypeOriginal;
local hasEffectOriginal;
local checkConditionalOriginal;
local checkConditionalHelperOriginal;

function onInit()
	TokenManager.addEffectTagIconConditional("IFN", TokenManager2.handleIFEffectTag);
	TokenManager.addEffectTagIconSimple("IFTN", "");
	
	onEffectActorStartTurnOriginal = EffectManager5E.onEffectActorStartTurn;
	EffectManager5E.onEffectActorStartTurn = onEffectActorStartTurn;

	parseEffectCompOriginal = EffectManager5E.parseEffectComp;
	EffectManager5E.parseEffectComp = parseEffectComp;

	removeEffectByTypeOriginal = EffectManager5E.removeEffectByType;
	EffectManager5E.removeEffectByType = removeEffectByType;

	getEffectsByTypeOriginal = EffectManager5E.getEffectsByType;
	EffectManager5E.getEffectsByType = getEffectsByType;

	hasEffectOriginal = EffectManager5E.hasEffect;
	EffectManager5E.hasEffect = hasEffect;

	checkConditionalOriginal = EffectManager5E.checkConditional;
	EffectManager5E.checkConditional = checkConditional;

	checkConditionalHelperOriginal = EffectManager5E.checkConditionalHelper;
	EffectManager5E.checkConditionalHelper = checkConditionalHelper;

	EffectManager.setCustomOnEffectActorStartTurn(onEffectActorStartTurn);
end

function registerOptions()
	OptionsManager.registerOption2('NO_TARGET', false, 'option_header_IFN', 'opt_ifn_no_target', 'option_entry_cycler', 
		{ labels = 'opt_val_off', values = 'off', baselabel = 'opt_val_off', baseval = 'off', default = 'off' })
end

function onEffectActorStartTurn(nodeActor, nodeEffect)
	local sEffName = DB.getValue(nodeEffect, "label", "");
	local aEffectComps = EffectManager.parseEffect(sEffName);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = parseEffectComp(sEffectComp);
		-- Conditionals
		if rEffectComp.type == "IFT" then
			break;
		elseif rEffectComp.type == "IFTN" then
			break;
		elseif rEffectComp.type == "IF" then
			local rActor = ActorManager.resolveActor(nodeActor);
			if not checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
				break;
			end
		elseif rEffectComp.type == "IFN" then
			local rActor = ActorManager.resolveActor(nodeActor);
			if checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
				break;
			end
		
		-- Ongoing damage and regeneration
		elseif rEffectComp.type == "DMGO" or rEffectComp.type == "REGEN" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				if rEffectComp.type == "REGEN" then
					local rActor = ActorManager.resolveActor(nodeActor);
					if (ActorHealthManager.getWoundPercent(rActor) >= 1) then 
						break;
					end
				end
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				EffectManager5E.applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp);
			end

		-- NPC power recharge
		elseif rEffectComp.type == "RCHG" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				EffectManager5E.applyRecharge(nodeActor, nodeEffect, rEffectComp);
			end
		end
	end
end

function parseEffectComp(s)
	return parseEffectCompOriginal(s);
end

function removeEffectByType(nodeCT, sEffectType)
	if not sEffectType then
		return;
	end
	local aEffectsToDelete = {};

	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local nActive = DB.getValue(nodeEffect, "isactive", 0);
		-- COMPATIBILITY FOR ADVANCED EFFECTS
		-- Thanks Kel
		--if (nActive ~= 0) then
		if ((not AdvancedEffects and nActive ~= 0) or (AdvancedEffects and EffectManagerADND.isValidCheckEffect(rActor,v))) then
		-- END COMPATIBILITY
			local s = DB.getValue(nodeEffect, "label", "");
			
			local aCompsToDelete = {};
			
			local aEffectComps = EffectManager.parseEffect(s);
			local nComp = 1;
			for _,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = parseEffectComp(sEffectComp);
				-- Check conditionals
				if rEffectComp.type == "IFT" then
					break;
				elseif rEffectComp.type == "IFTN" then
					break;
				elseif rEffectComp.type == "IF" then
					local rActor = ActorManager.resolveActor(nodeActor);
					if not checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFN" then
					local rActor = ActorManager.resolveActor(nodeActor);
					if checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
						break;
					end
				
				-- Check for effect match
				elseif rEffectComp.type == sEffectType then
					table.insert(aCompsToDelete, nComp);
				end
				
				nComp = nComp + 1;
			end
			
			-- Delete portion of effect that matches (or register for full deletion)
			if #aCompsToDelete >= #aEffectComps then
				table.insert(aEffectsToDelete, nodeEffect);
			elseif #aCompsToDelete > 0 then
				local aNewEffectComps = {};
				local nEffectComps = #aEffectComps;
				for i = 1,nEffectComps do
					if not StringManager.contains(aCompsToDelete, i) then
						table.insert(aNewEffectComps, aEffectComps[i]);
					end
				end
				
				local sNewEffect = EffectManager.rebuildParsedEffect(aNewEffectComps);
				DB.setValue(nodeEffect, "label", "string", sNewEffect);
			end
		end
	end
	
	for _,v in ipairs(aEffectsToDelete) do
		v.delete();
	end
end

function getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	if not rActor then
		return {};
	end
	local results = {};
	
	-- Set up filters
	local aRangeFilter = {};
	local aOtherFilter = {};
	if aFilter then
		for _,v in pairs(aFilter) do
			if type(v) ~= "string" then
				table.insert(aOtherFilter, v);
			elseif StringManager.contains(DataCommon.rangetypes, v) then
				table.insert(aRangeFilter, v);
			else
				table.insert(aOtherFilter, v);
			end
		end
	end
	
	-- Iterate through effects
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		-- Check active
		local nActive = DB.getValue(v, "isactive", 0);
		-- COMPATIBILITY FOR ADVANCED EFFECTS
		-- Thanks Kel
		--if (nActive ~= 0) then
		if ((not AdvancedEffects and nActive ~= 0) or (AdvancedEffects and EffectManagerADND.isValidCheckEffect(rActor,v))) then
		-- END COMPATIBILITY
			local sLabel = DB.getValue(v, "label", "");
			local sApply = DB.getValue(v, "apply", "");

			-- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
			local bTargeted = EffectManager.isTargetedEffect(v);
			if not bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
				local aEffectComps = EffectManager.parseEffect(sLabel);

				-- Look for type/subtype match
				local nMatch = 0;
				for kEffectComp,sEffectComp in ipairs(aEffectComps) do
					local rEffectComp = parseEffectComp(sEffectComp);
					-- Handle conditionals
					if rEffectComp.type == "IF" then
						if not checkConditional(rActor, v, rEffectComp.remainder) then
							break;
						end
					elseif rEffectComp.type == "IFN" then
						if checkConditional(rActor, v, rEffectComp.remainder) then
							break;
						end
					elseif rEffectComp.type == "IFT" then
						if not rFilterActor then
							break;
						end
						if not checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
							break;
						end
						bTargeted = true;
					elseif rEffectComp.type == "IFTN" then
						if (OptionsManager.isOption('NO_TARGET', 'off') and not rFilterActor) or checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
							break;
						end
						bTargeted = true;
					
					-- Compare other attributes
					else
						-- Strip energy/bonus types for subtype comparison
						local aEffectRangeFilter = {};
						local aEffectOtherFilter = {};
						local j = 1;
						while rEffectComp.remainder[j] do
							local s = rEffectComp.remainder[j];
							if #s > 0 and ((s:sub(1,1) == "!") or (s:sub(1,1) == "~")) then
								s = s:sub(2);
							end
							if StringManager.contains(DataCommon.dmgtypes, s) or s == "all" or 
									StringManager.contains(DataCommon.bonustypes, s) or
									StringManager.contains(DataCommon.conditions, s) or
									StringManager.contains(DataCommon.connectors, s) then
								-- SKIP
							elseif StringManager.contains(DataCommon.rangetypes, s) then
								table.insert(aEffectRangeFilter, s);
							else
								table.insert(aEffectOtherFilter, s);
							end
							
							j = j + 1;
						end
					
						-- Check for match
						local comp_match = false;
						if rEffectComp.type == sEffectType then

							-- Check effect targeting
							if bTargetedOnly and not bTargeted then
								comp_match = false;
							else
								comp_match = true;
							end
						
							-- Check filters
							if #aEffectRangeFilter > 0 then
								local bRangeMatch = false;
								for _,v2 in pairs(aRangeFilter) do
									if StringManager.contains(aEffectRangeFilter, v2) then
										bRangeMatch = true;
										break;
									end
								end
								if not bRangeMatch then
									comp_match = false;
								end
							end
							if #aEffectOtherFilter > 0 then
								local bOtherMatch = false;
								for _,v2 in pairs(aOtherFilter) do
									if type(v2) == "table" then
										local bOtherTableMatch = true;
										for k3, v3 in pairs(v2) do
											if not StringManager.contains(aEffectOtherFilter, v3) then
												bOtherTableMatch = false;
												break;
											end
										end
										if bOtherTableMatch then
											bOtherMatch = true;
											break;
										end
									elseif StringManager.contains(aEffectOtherFilter, v2) then
										bOtherMatch = true;
										break;
									end
								end
								if not bOtherMatch then
									comp_match = false;
								end
							end
						end

						-- Match!
						if comp_match then
							nMatch = kEffectComp;
							if nActive == 1 then
								table.insert(results, rEffectComp);
							end
						end
					end
				end -- END EFFECT COMPONENT LOOP

				-- Remove one shot effects
				if nMatch > 0 then
					if nActive == 2 then
						DB.setValue(v, "isactive", "number", 1);
					else
						if sApply == "action" then
							EffectManager.notifyExpire(v, 0);
						elseif sApply == "roll" then
							EffectManager.notifyExpire(v, 0, true);
						elseif sApply == "single" then
							EffectManager.notifyExpire(v, nMatch, true);
						end
					end
				end
			end -- END TARGET CHECK
		end  -- END ACTIVE CHECK
	end  -- END EFFECT LOOP
	
	-- RESULTS
	return results;
end

function hasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
	if not sEffect or not rActor then
		return false;
	end
	local sLowerEffect = sEffect:lower();
	
	-- Iterate through each effect
	local aMatch = {};
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		local nActive = DB.getValue(v, "isactive", 0);
		-- COMPATIBILITY FOR ADVANCED EFFECTS
		-- Thanks Kel
		-- to add support for AE in other extensions, make this change
		-- original line: if nActive ~= 0 then
		if ((not AdvancedEffects and nActive ~= 0) or (AdvancedEffects and EffectManagerADND.isValidCheckEffect(rActor,v))) then
		-- END COMPATIBILITY FOR ADVANCED EFFECTS
			-- Parse each effect label
			local sLabel = DB.getValue(v, "label", "");
			local bTargeted = EffectManager.isTargetedEffect(v);
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			local nMatch = 0;
			for kEffectComp,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = parseEffectComp(sEffectComp);
				-- Handle conditionals
				if rEffectComp.type == "IF" then
					if not checkConditional(rActor, v, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFN" then
					if checkConditional(rActor, v, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFT" then
					if not rTarget then
						break;
					end
					if not checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break;
					end
				elseif rEffectComp.type == "IFTN" then
					if (OptionsManager.isOption('NO_TARGET', 'off') and not rTarget) or checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break;
					end
				
				-- Check for match
				elseif rEffectComp.original:lower() == sLowerEffect then
					if bTargeted and not bIgnoreEffectTargets then
						if EffectManager.isEffectTarget(v, rTarget) then
							nMatch = kEffectComp;
						end
					elseif not bTargetedOnly then
						nMatch = kEffectComp;
					end
				end
				
			end
			
			-- If matched, then remove one-off effects
			if nMatch > 0 then
				if nActive == 2 then
					DB.setValue(v, "isactive", "number", 1);
				else
					table.insert(aMatch, v);
					local sApply = DB.getValue(v, "apply", "");
					if sApply == "action" then
						EffectManager.notifyExpire(v, 0);
					elseif sApply == "roll" then
						EffectManager.notifyExpire(v, 0, true);
					elseif sApply == "single" then
						EffectManager.notifyExpire(v, nMatch, true);
					end
				end
			end
		end
	end
	
	if #aMatch > 0 then
		return true;
	end
	return false;
end

function checkConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	return checkConditionalOriginal(rActor, nodeEffect, aConditions, rTarget, aIgnore);
end

function checkConditionalHelper(rActor, sEffect, rTarget, aIgnore)
	
	if not rActor then
		return false;
	end
	
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		local nActive = DB.getValue(v, "isactive", 0);
		if (((not AdvancedEffects and nActive ~= 0) or (AdvancedEffects and EffectManagerADND.isValidCheckEffect(rActor,v))) and not StringManager.contains(aIgnore, v.getPath())) then
			-- Parse each effect label
			local sLabel = DB.getValue(v, "label", "");
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			for _,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = parseEffectComp(sEffectComp);
				
				-- CHECK CONDITIONALS
				if rEffectComp.type == "IF" then
					if not checkConditional(rActor, v, rEffectComp.remainder, nil, aIgnore) then
						break;
					end
				elseif rEffectComp.type == "IFN" then
					if checkConditional(rActor, v, rEffectComp.remainder, nil, aIgnore) then
						break;
					end
				elseif rEffectComp.type == "IFT" then
					if not rTarget then
						break;
					end
					if not checkConditional(rTarget, v, rEffectComp.remainder, rActor, aIgnore) then
						break;
					end
				elseif rEffectComp.type == "IFTN" then
					if (OptionsManager.isOption('NO_TARGET', 'off') and not rTarget) or checkConditional(rTarget, v, rEffectComp.remainder, rActor, aIgnore) then
						break;
					end
				
				-- CHECK FOR AN ACTUAL EFFECT MATCH
				elseif rEffectComp.original:lower() == sEffect then
					if EffectManager.isTargetedEffect(v) then
						if EffectManager.isEffectTarget(v, rTarget) then
							return true;
						end
					else
						return true;
					end
				end
			end
		end
	end
	
	return false;
end
