AdvancedColors = AdvancedColors or {}

if SERVER then
	resource.AddFile("materials/adv_colour/null.vmt")
else
	---@class AdvancedColorEntity: Entity
	---@field _adv_colours table<integer, Color>
	---@field _adv_colours_mats table<integer, IMaterial>

	---This stores all SubColoring info. This helps to prevent __index calls
	---
	--- - [1]: boolean, Has this been processed?
	--- - [2]: table<integer, Color>, Equivalent to _adv_colours
	--- - [3]: table<integer, IMaterial>, Equivalent to _adv_colours_mats
	---@class AdvancedColorEntityInfo 
	---@field [1] boolean Has this been processed?
	---@field [2] table<integer, Color> Equivalent to _adv_colours
	---@field [3] table<integer, IMaterial> Equivalent to _adv_colours_mats
	---@field [4] table<integer, IMaterial>? Material cache
	---@field [5] boolean Flush

	---@type Entity[]
	AdvancedColors.Entities = AdvancedColors.Entities or {}
	---@type table<Entity, AdvancedColorEntityInfo>
	AdvancedColors.EntitySet = AdvancedColors.EntitySet or {}
	local advancedColorEntities = AdvancedColors.Entities
	local advancedColorEntitySet = AdvancedColors.EntitySet
	
	local function refreshEntities()
		advancedColorEntities = {}
		for entity in pairs(advancedColorEntitySet) do
			table.insert(advancedColorEntities, entity)
		end
	end
	---@param entity Entity
	---@return AdvancedColorEntityInfo
	local function addEntity(entity)
		local entityInfo = {true, {}, {}, nil, true} 
		advancedColorEntitySet[entity] = entityInfo
		refreshEntities()
		return entityInfo
	end

	local function removeEntity(entity)
		advancedColorEntitySet[entity] = nil
		refreshEntities()
	end

	local empty = {}
	net.Receive("adv_colour_mat", function()
		local ent, ind, str = net.ReadEntity(), net.ReadInt( 16 ), net.ReadString()
		---@cast ent AdvancedColorEntity
		ent._adv_colours_mats = ent._adv_colours_mats or {}
		if ind >= 0 then
			ent._adv_colours_mats[ind] = Material( str )
		else
			ent._adv_colours_mats = {}
		end
		ent._adv_colours_flush = true
		local hasColor = next(ent._adv_colours or empty)
		local hasMats = next(ent._adv_colours_mats or empty)
		if hasColor or hasMats then
			local entityInfo = advancedColorEntitySet[ent]
			if not entityInfo then
				entityInfo = addEntity(ent)
			end
			entityInfo[3] = ent._adv_colours_mats
		elseif not hasColor and not hasMats then
			removeEntity(ent)
		end

		ent:CallOnRemove("adv_colour_remove", function(ent, ...)
			removeEntity(ent)
		end)
	end)

	net.Receive("adv_colour", function()
		local ent, ind, reset, color = net.ReadEntity(), net.ReadInt( 16 ), net.ReadBool()
		---@cast ent AdvancedColorEntity
		local color
		if not reset then
			color = net.ReadColor()
		end
		local flush = true
		ent._adv_colours = ent._adv_colours or {}
		ent._adv_colours[ind] = color
		ent._adv_colours_flush = flush
		local hasColor = next(ent._adv_colours or empty)
		local hasMat = next(ent._adv_colours_mats or empty)
		if hasColor or hasMat then
			local entityInfo = advancedColorEntitySet[ent]
			if not advancedColorEntitySet[ent] then
				entityInfo = addEntity(ent)
			end
			entityInfo[2] = ent._adv_colours
			entityInfo[5] = flush
		elseif not hasColor and not hasMat then
			advancedColorEntitySet[ent] = nil
			refreshEntities()
		end
	end)
	
	---INFO: Originally used GMod's null material. However, maps can override this (see gm_floatingworlds_3_v2).
	local null = Material( "adv_colour/null" )	

	local render_SetColorModulation = render.SetColorModulation
	local render_MaterialOverrideByIndex = render.MaterialOverrideByIndex
	local render_SetBlend = render.SetBlend

	local ipairs = ipairs
	local pairs = pairs
	local next = next
	-- FIXME: The behavior down here runs (multiple times) every tick and iterates over ALL entities
	-- Make this only iterate over a single entity and skip after being processed in the same frame
	hook.Remove("PreDrawOpaqueRenderables", "adv_colour")
	hook.Add( "PreDrawOpaqueRenderables", "adv_colour", function( depth, skybox )
		for k, v in ipairs(advancedColorEntities) do
			if not IsValid(v) then
				removeEntity(v)
				continue
			end
			local entityInfo = advancedColorEntitySet[v]
			if !v:IsPlayer() and entityInfo[1] then
				-- Only process this entity once per tick
				entityInfo[1] = false
				local colorMats = entityInfo[3]
				local colors = entityInfo[2]
				
				local colorCache = entityInfo[4]
				if not colorCache then
					colorCache = {}
					for k, v in ipairs(v:GetMaterials()) do
						colorCache[k-1] = Material(v)
					end
					entityInfo[4] = colorCache
				end
				
				for index, mat in pairs(colorCache) do -- All of the submats to invisible
					if colorMats[index] or colors[index] then
						if v._adv_colours_flush then 
							v:_OldSetSubMaterial( index, nil ) 
						end
						render_MaterialOverrideByIndex( index, null )
					end
				end
				
				entityInfo[5] = false
				
				local color = v:GetColor()
				
				local lastkey = 0
				
				for k, v in pairs(colorMats) do
					if k > lastkey then
						lastkey = k
					end
				end
				
				for k, v in pairs(colors) do
					if k > lastkey then
						lastkey = k
					end
				end
				
				for index, col in pairs(colorCache) do -- Draw all the submats we need
					if colorMats[index] or colors[index] then
						local subcolor = colors[index]
						if subcolor then
							render.SetColorModulation( subcolor.r/255, subcolor.g/255, subcolor.b/255 )
							render.SetBlend( subcolor.a/255 )
						else
							render_SetColorModulation( color.r/255, color.g/255, color.b/255 )
							render_SetBlend( color.a/255 )
						end
						
						render_MaterialOverrideByIndex( index, colorMats[index] or colorCache[index] )
						
						v:DrawModel()
						
						render_SetColorModulation( 1, 1, 1 )
						render_SetBlend( 1 )
							
						for index, mat in pairs(colorCache) do -- All of the submats to invisible
							render_MaterialOverrideByIndex( index, null )
						end
					end
				end
				
				for index, col in pairs(colorCache) do -- Draw the normal parts
					
					if colorMats[index] or colors[index] then
					
					else
						render_SetColorModulation( color.r/255, color.g/255, color.b/255 )
						render_SetBlend( color.a/255 )
						
						render_MaterialOverrideByIndex( index, colorCache[index] )
					end
				end
					
				v:DrawModel()
						
				render_SetColorModulation( 1, 1, 1 )
				render_SetBlend( 1 )
				
				for index, col in pairs(colorCache) do -- Reset the submats
					render_MaterialOverrideByIndex( index, nil )
				end
				
				v._adv_colours_resetmat = v:GetMaterial()
				v:SetMaterial(null:GetName()) 
				--v:SetNoDraw(true) -- Don't draw the default model

				entityInfo[3] = colorMats or {}
			elseif v:GetNoDraw() then
				--v:SetNoDraw(false)
				local colorMats = entityInfo[3]
				if colorMats and next(colorMats) then
					for i, o in pairs(colorMats) do
						v:_OldSetSubMaterial( i, tostring(o) ) 
					end
				end
			end
		end
	end)
	
	hook.Remove("PostDrawOpaqueRenderables", "adv_colour")
	hook.Add( "PostDrawOpaqueRenderables", "adv_colour", function( depth, skybox )
		for _, v in ipairs(advancedColorEntities) do
			if !v:IsPlayer() then
				advancedColorEntitySet[v][1] = true
				v:SetMaterial( v._adv_colours_resetmat or "" )
			end
		end
	end)
end
