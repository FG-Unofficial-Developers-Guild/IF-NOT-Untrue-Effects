-- Save references to the original functions from EffectManager5E
local originalOnEffectActorStartTurn
local originalRemoveEffectByType
local originalGetEffectsByType
local originalHasEffect
local originalCheckConditionalHelper

function onInit()
    TokenManager.addEffectTagIconConditional("IFN", TokenManager2.handleIFEffectTag)
	TokenManager.addEffectTagIconSimple("IFTN", "")

    originalOnEffectActorStartTurn = EffectManager5E.onEffectActorStartTurn
    originalRemoveEffectByType = EffectManager5E.removeEffectByType
    originalGetEffectsByType = EffectManager5E.getEffectsByType
    originalHasEffect = EffectManager5E.hasEffect
    originalCheckConditionalHelper = EffectManager5E.checkConditionalHelper

	EffectManager5E.onEffectActorStartTurn = onEffectActorStartTurn
	EffectManager5E.removeEffectByType = removeEffectByType
	EffectManager5E.getEffectsByType = getEffectsByType
	EffectManager5E.hasEffect = hasEffect
	EffectManager5E.checkConditionalHelper = checkConditionalHelper

    EffectManager.setCustomOnEffectActorStartTurn(onEffectActorStartTurn)
end

-- Wrapper for onEffectActorStartTurn to handle IFN and IFTN
function onEffectActorStartTurn(nodeActor, nodeEffect)
    local sEffName = DB.getValue(nodeEffect, "label", "")
    local aEffectComps = EffectManager.parseEffect(sEffName)
    for _, sEffectComp in ipairs(aEffectComps) do
        local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp)
        -- Handle the new IFN and IFTN conditionals
        if rEffectComp.type == "IFTN" then
            if EffectManager5E.checkConditional(ActorManager.resolveActor(nodeActor), nodeEffect, rEffectComp.remainder) then
                break
            end
        elseif rEffectComp.type == "IFN" then
            local rActor = ActorManager.resolveActor(nodeActor)
            if EffectManager5E.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
                break
            end
        end
    end
    -- Call the original function from EffectManager5E
    originalOnEffectActorStartTurn(nodeActor, nodeEffect)
end

-- Wrapper for removeEffectByType to handle IFN and IFTN
function removeEffectByType(nodeCT, sEffectType)
    -- Add custom logic for IFN and IFTN
    for _, nodeEffect in ipairs(DB.getChildList(nodeCT, "effects")) do
        local aEffectComps = EffectManager.parseEffect(DB.getValue(nodeEffect, "label", ""))
        for _, sEffectComp in ipairs(aEffectComps) do
            local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp)
            if rEffectComp.type == "IFTN" then
                if EffectManager5E.checkConditional(ActorManager.resolveActor(nodeCT), nodeEffect, rEffectComp.remainder) then
                    break
                end
            elseif rEffectComp.type == "IFN" then
                if EffectManager5E.checkConditional(ActorManager.resolveActor(nodeCT), nodeEffect, rEffectComp.remainder) then
                    break
                end
            end
        end
    end
    -- Call the original function from EffectManager5E
    originalRemoveEffectByType(nodeCT, sEffectType)
end

-- Wrapper for getEffectsByType to handle IFN and IFTN
function getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
    -- Add custom logic for IFN and IFTN before calling original function
    local results = {}
    -- Process IFN and IFTN
    for _, v in ipairs(DB.getChildList(ActorManager.getCTNode(rActor), "effects")) do
        local aEffectComps = EffectManager.parseEffect(DB.getValue(v, "label", ""))
        for _, sEffectComp in ipairs(aEffectComps) do
            local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp)
            if rEffectComp.type == "IFTN" then
                if EffectManager5E.checkConditional(rFilterActor, v, rEffectComp.remainder, rActor) then
                    break
                end
            elseif rEffectComp.type == "IFN" then
                if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                    break
                end
            end
        end
    end
    -- Call original function from EffectManager5E after custom logic
    return originalGetEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
end

-- Wrapper for hasEffect to handle IFN and IFTN
function hasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    -- Add custom logic for IFN and IFTN
    for _, v in ipairs(DB.getChildList(ActorManager.getCTNode(rActor), "effects")) do
        local aEffectComps = EffectManager.parseEffect(DB.getValue(v, "label", ""))
        for _, sEffectComp in ipairs(aEffectComps) do
            local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp)
            if rEffectComp.type == "IFTN" then
                if EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
                    return false
                end
            elseif rEffectComp.type == "IFN" then
                if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
                    return false
                end
            end
        end
    end
    -- Call the original function from EffectManager5E after custom logic
    return originalHasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets)
end

-- Wrapper for checkConditionalHelper to handle IFN and IFTN
function checkConditionalHelper(rActor, sEffect, rTarget, aIgnore)
    if not rActor then
        return false
    end
    
    -- Iterate through each effect on the actor
    for _, v in ipairs(DB.getChildList(ActorManager.getCTNode(rActor), "effects")) do
        local nActive = DB.getValue(v, "isactive", 0)
        if nActive ~= 0 and not StringManager.contains(aIgnore, DB.getPath(v)) then
            -- Parse each effect label
            local sLabel = DB.getValue(v, "label", "")
            local aEffectComps = EffectManager.parseEffect(sLabel)
            
            -- Iterate through each effect component looking for a type match
            for _, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp)
                
                -- CHECK CONDITIONALS
                if rEffectComp.type == "IFN" then
                    if EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder, nil, aIgnore) then
                        break
                    end
                elseif rEffectComp.type == "IFTN" then
                    if not rTarget then
                        break
                    end
                    if EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor, aIgnore) then
                        break
                    end
                end
            end
        end
    end
    
    -- Call the original function from EffectManager5E after custom logic for IFN and IFTN
    return originalCheckConditionalHelper(rActor, sEffect, rTarget, aIgnore)
end
