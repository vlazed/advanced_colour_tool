if SERVER then
	util.AddNetworkString( "adv_colour_mat" )
	util.AddNetworkString( "adv_colour" )
end

---@class Entity
---@field AttachedEntity Entity? Dynamic prop if the parent entity is an effect prop
local ENT = FindMetaTable( "Entity" )

if ENT._OldSetSubMaterial == nil then
	ENT._OldSetSubMaterial = ENT.SetSubMaterial
end

---Detour the submaterial setter so Advanced Color Tool can track this and color
---the submaterrial override
---@param ind integer
---@param str string
---@param ignore boolean?
function ENT:SetSubMaterial( ind, str, ignore )
	str = tostring(str)
	self:_OldSetSubMaterial( ind, str )
	self._adv_colours_flush = true
	
	self._adv_colours_mats = self._adv_colours_mats or {}
	self._adv_colours_mats[ind] = str and Material( str ) or nil
	
	if !ignore then
		if SERVER then
			net.Start("adv_colour_mat")
				net.WriteEntity( self )
				net.WriteInt( ind, 16 )
				net.WriteString( str )
			net.Broadcast()
		end
	end
end

---Set the `Color` for the specifed submaterial `ind`ex 
---@param ind integer Submaterial index
---@param color Color? Submaterial color or nil to reset
function ENT:SetSubColor( ind, color )
	self._adv_colours = self._adv_colours or {}
	self._adv_colours[ind] = color
	
	if SERVER then
		net.Start("adv_colour")
			net.WriteEntity( self )
			net.WriteInt( ind, 16 )
			net.WriteBool( !color and true or false )
			if color then 
				net.WriteColor( color ) 
			end
		net.Broadcast()
	end
end

if SERVER then

	hook.Add("PlayerInitialSpawn", "adv_colour", function( ply )
		for k, v in pairs( ents.GetAll() ) do
			if v._adv_colours and table.Count(v._adv_colours) > 0 then
				for i, o in pairs(v._adv_colours) do
					net.Start("adv_colour")
						net.WriteEntity( v )
						net.WriteInt( i, 16 )
						net.WriteBool( false )
						net.WriteColor( o )
					net.Send(ply)
				end			
			end
			if v._adv_colours_mats and table.Count(v._adv_colours_mats) > 0 then
				for i, o in pairs(v._adv_colours_mats) do
					net.Start("adv_colour_mat")
						net.WriteEntity( v )
						net.WriteInt( i, 16 )
						net.WriteString( tostring(o) )
					net.Send(ply)
				end		
			end
		end
	end)

else

	net.Receive("adv_colour_mat", function()
		local ent, ind, str = net.ReadEntity(), net.ReadInt( 16 ), net.ReadString()
		ent._adv_colours_mats = ent._adv_colours_mats or {}
		ent._adv_colours_mats[ind] = Material( str )
		ent._adv_colours_flush = true
	end)

	net.Receive("adv_colour", function()
		local ent, ind, reset, color = net.ReadEntity(), net.ReadInt( 16 ), net.ReadBool(), net.ReadColor()
		
		ent._adv_colours = ent._adv_colours or {}
		ent._adv_colours[ind] = !reset and color or nil
		ent._adv_colours_flush = true
	end)
	
	---INFO: Originally used GMod's null material. However, maps can override this (see gm_floatingworlds_3_v2).
	local null = Material( "adv_colour/null" )

	hook.Remove("PreDrawOpaqueRenderables", "adv_colour")
	hook.Add( "PreDrawOpaqueRenderables", "adv_colour", function( depth, skybox )
		for k, v in pairs( ents.GetAll() ) do
			if !v:IsPlayer() and v._adv_colours and table.Count(v._adv_colours) > 0 then
				
				v._adv_colours_mats = v._adv_colours_mats or {}
				
				if v._adv_colours_cache == nil then
					local mat = {}
					for k, v in pairs(v:GetMaterials()) do
						mat[k-1] = Material(v)
					end
					v._adv_colours_cache = mat
				end
				
				for index, mat in pairs(v._adv_colours_cache) do -- All of the submats to invisible
					if v._adv_colours_mats[index] or v._adv_colours[index] then
						if v._adv_colours_flush then 
							v:_OldSetSubMaterial( index, nil ) 
						end
						render.MaterialOverrideByIndex( index, null )
					end
				end
				
				v._adv_colours_flush = false
				
				local color = v:GetColor()
				
				local lastkey = 0
				
				for k, v in pairs(v._adv_colours_mats) do
					if k > lastkey then
						lastkey = k
					end
				end
				
				for k, v in pairs(v._adv_colours) do
					if k > lastkey then
						lastkey = k
					end
				end
				
				for index, col in pairs(v._adv_colours_cache) do -- Draw all the submats we need
					
					if v._adv_colours_mats[index] or v._adv_colours[index] then
						if v._adv_colours[index] then
							render.SetColorModulation( v._adv_colours[index].r/255, v._adv_colours[index].g/255, v._adv_colours[index].b/255 )
							render.SetBlend( v._adv_colours[index].a/255 )
						else
							render.SetColorModulation( color.r/255, color.g/255, color.b/255 )
							render.SetBlend( color.a/255 )
						end
						
						render.MaterialOverrideByIndex( index, v._adv_colours_mats[index] or v._adv_colours_cache[index] )
						
						v:DrawModel()
						
						render.SetColorModulation( 1, 1, 1 )
						render.SetBlend( 1 )
							
						for index, mat in pairs(v._adv_colours_cache) do -- All of the submats to invisible
							render.MaterialOverrideByIndex( index, null )
						end
					end
				end
				
				for index, col in pairs(v._adv_colours_cache) do -- Draw the normal parts
					
					if v._adv_colours_mats[index] or v._adv_colours[index] then
					
					else
						render.SetColorModulation( color.r/255, color.g/255, color.b/255 )
						render.SetBlend( color.a/255 )
						
						render.MaterialOverrideByIndex( index, v._adv_colours_cache[index] )
					end
				end
					
				v:DrawModel()
						
				render.SetColorModulation( 1, 1, 1 )
				render.SetBlend( 1 )
				
				for index, col in pairs(v._adv_colours_cache) do -- Reset the submats
					render.MaterialOverrideByIndex( index, nil )
				end
				
				v._adv_colours_resetmat = v:GetMaterial()
				v:SetMaterial(null:GetName()) 
				--v:SetNoDraw(true) -- Don't draw the default model
			elseif v:GetNoDraw() then
				--v:SetNoDraw(false)
				
				if v._adv_colours_mats and table.Count(v._adv_colours_mats) > 0 then
					for i, o in pairs(v._adv_colours_mats) do
						v:_OldSetSubMaterial( i, tostring(o) ) 
					end
				end
			end
		end
	end)
	
	hook.Remove("PostDrawOpaqueRenderables", "adv_colour")
	hook.Add( "PostDrawOpaqueRenderables", "adv_colour", function( depth, skybox )
		for k, v in pairs( ents.GetAll() ) do
			if !v:IsPlayer() and v._adv_colours and table.Count(v._adv_colours) > 0 then
				v:SetMaterial( v._adv_colours_resetmat or "" )
			end
		end
	end)
	
end

if CLIENT then
	language.Add( "tool.adv_colour.name", "Advanced Colour Tool" )
	language.Add( "tool.adv_colour.desc", "Recolour an entity" )
	language.Add( "tool.adv_colour.left", "Apply colour to an object" )
	language.Add( "tool.adv_colour.right", "Restore an object's colour" )
	language.Add( "tool.adv_colour.reload", "Copy an object's colour" )
	language.Add( "tool.adv_colour.help", "Recolour an entity" )
end

TOOL.Category = "Render"
TOOL.Name = "#tool.adv_colour.name"

TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" },
}

TOOL.ClientConVar[ "r" ] = 255
TOOL.ClientConVar[ "g" ] = 0
TOOL.ClientConVar[ "b" ] = 255
TOOL.ClientConVar[ "a" ] = 255
TOOL.ClientConVar[ "mode" ] = 0
TOOL.ClientConVar[ "fx" ] = 0
TOOL.ClientConVar[ "index" ] = 0

---@param Player Player
---@param Entity Entity
---@param Data AdvColourData
local function SetColour( Player, Entity, Data )

	if ( Data.Color && Data.Color.a < 255 && Data.RenderMode == 0 ) then
		Data.RenderMode = 1
	end
	
	if Data.Index > 0 then
		local col = Color( Data.Color.r, Data.Color.g, Data.Color.b, Data.Color.a )
		
		if Data.ResetIndex then
			---INFO: Behavior to set this to nil is to clear adv_colour_mat field
			---which causes a color reset
			---@diagnostic disable-next-line
			col = nil
		end
		
		Entity:SetSubColor( Data.Index-1, col )
	else
		if ( Data.Color ) then Entity:SetColor( Color( Data.Color.r, Data.Color.g, Data.Color.b, Data.Color.a ) ) end
	end
	
	if ( Data.RenderMode ) then Entity:SetRenderMode( Data.RenderMode ) end
	if ( Data.RenderFX ) then Entity:SetRenderFX( Data.RenderFX ) end

	duplicator.StoreEntityModifier( Entity, "adv_colour", Data )
	
end

if SERVER then
	duplicator.RegisterEntityModifier("adv_colour", SetColour)
end

function TOOL:LeftClick( trace )

	local ent = trace.Entity
	if ( IsValid( ent.AttachedEntity ) ) then ent = ent.AttachedEntity end

	---INFO: Checking nil here to silence LuaLS warning
	if ent and IsValid( ent ) then

		if ( CLIENT ) then return true end
	
		local r = self:GetClientNumber( "r", 0 )
		local g = self:GetClientNumber( "g", 0 )
		local b = self:GetClientNumber( "b", 0 )
		local a = self:GetClientNumber( "a", 0 )
		local mode = self:GetClientNumber( "mode", 0 )
		local fx = self:GetClientNumber( "fx", 0 )
		local index = self:GetClientNumber( "index", 0 )
		
		SetColour( self:GetOwner(), ent, { Index = index, Color = Color( r, g, b, a ), RenderMode = mode, RenderFX = fx } )

		return true
		
	end

end

function TOOL:RightClick( trace )

	local ent = trace.Entity
	if ( IsValid( ent.AttachedEntity ) ) then ent = ent.AttachedEntity end

	---INFO: Checking nil here to silence LuaLS warning
	if ent and IsValid( ent ) then

		if ( CLIENT ) then return true end
	
		local index = self:GetClientNumber( "index", 0 )
		SetColour( self:GetOwner(), ent, { Index = index, ResetIndex = true, Color = Color( 255, 255, 255, 255 ), RenderMode = 0, RenderFX = 0 } )
		return true
	
	end
	
end

function TOOL:Reload( trace )
	
	if SERVER and game.SinglePlayer() then
		local player = Entity(1)
		---INFO: In singleplayer, `Entity(1)` is a `Player`. We type cast to make this clear
		---@cast player Player
		player:SendLua("LocalPlayer():GetActiveWeapon():GetToolObject():Reload()")
		return true
	end
	
	if CLIENT and trace == nil then
		trace = LocalPlayer():GetEyeTrace()
	end
	
	local ent = trace.Entity
	if ( IsValid( ent.AttachedEntity ) ) then ent = ent.AttachedEntity end

	---INFO: Checking nil here to silence LuaLS warning
	if ent and IsValid( ent ) then

		if ( CLIENT ) then 
			local color = ent:GetColor()
			
			RunConsoleCommand( "adv_colour_r", color.r )
			RunConsoleCommand( "adv_colour_g", color.g )
			RunConsoleCommand( "adv_colour_b", color.b )
			RunConsoleCommand( "adv_colour_a", color.a )
			
			local CPanel = controlpanel.Get( "adv_colour" )
			---@cast CPanel AdvColourCPanel
			
			if IsValid(CPanel) and CPanel.Int then
			
				CPanel.Int:UpdateRGB( color.r, color.g, color.b )
				CPanel.Int:UpdateHSL( color.r, color.g, color.b )
				CPanel.Int:UpdateAlpha( color.a )
				
			end
			
		end
			
		return true
	
	end
	
end

local ConVarsDefault = TOOL:BuildConVarList()

if CLIENT then
	
	TOOL.HUDData = {}
	TOOL.HUDData.DefColor = Color( 255, 255, 255, 255 )
	TOOL.HUDData.TextColor = Color( 255, 255, 255, 255 )
	TOOL.HUDData.TextSelColor = Color( 255, 0, 0, 255 )
	TOOL.HUDData.BGColor = Color( 60, 60, 100, 200 )
	TOOL.HUDData.BGSelColor = Color( 200, 200, 60, 200 )
	
	function TOOL:Scroll(trace, dir)
		local ent = trace.Entity
		if ( IsValid( ent.AttachedEntity ) ) then ent = ent.AttachedEntity end

		if IsValid( ent ) and table.Count(self.HUDData.Mats) > 1 then
			self.HUDData.Index = (self.HUDData.Index + dir) % (table.Count(self.HUDData.Mats)+1) 
			RunConsoleCommand( "adv_colour_index", self.HUDData.Index )
			return true
		end
	end

	function TOOL:ScrollUp(trace) return self:Scroll(trace, -1) end

	function TOOL:ScrollDown(trace) return self:Scroll(trace, 1) end
	
	local function get_active_tool(ply, tool)
		local activeWep = ply:GetActiveWeapon()
		if not IsValid(activeWep) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end

		return activeWep:GetToolObject(tool)
	end
	
	---- Thx wire_adv dev again...
	local function hookfunc( ply, bind, pressed )
		if not pressed then return end
		if bind == "invnext" then
			local self = get_active_tool(ply, "adv_colour")
			if not self then return end
			
			return self:ScrollDown(ply:GetEyeTraceNoCursor())
		elseif bind == "invprev" then
			local self = get_active_tool(ply, "adv_colour")
			if not self then return end

			return self:ScrollUp(ply:GetEyeTraceNoCursor())
		end
	end

	if game.SinglePlayer() then -- wtfgarry (have to have a delay in single player or the hook won't get added)
		timer.Simple(5, function() hook.Add( "PlayerBindPress", "adv_colour_tool", hookfunc ) end)
	else
		hook.Add( "PlayerBindPress", "adv_colour_tool", hookfunc )
	end

	surface.CreateFont( "adv_colour_screen", {
		font	= "Helvetica",
		size	= 40,
		weight	= 900
	} )

	local function DrawScrollingText( text, y, texwide )

		local w, h = surface.GetTextSize( text  )
		w = w + 64

		y = y - h / 2 -- Center text to y position

		local x = RealTime() * 250 % w * -1

		while ( x < texwide ) do
		
			surface.SetTextColor( 0, 0, 0, 255 )
			surface.SetTextPos( x + 3, y + 3 )
			surface.DrawText( text )

			surface.SetTextColor( 255, 255, 255, 255 )
			surface.SetTextPos( x, y )
			surface.DrawText( text )

			x = x + w

		end

	end
	
	function TOOL:Think()
		local ent = LocalPlayer():GetEyeTraceNoCursor().Entity
		if ( IsValid( ent.AttachedEntity ) ) then ent = ent.AttachedEntity end
		
		if self.HUDData.AimEnt != ent then
			self.HUDData.AimEnt = ent
			self.HUDData.Mats = nil
			
			if IsValid(self.HUDData.AimEnt) then
				self.HUDData.Index = 0
				self.HUDData.Mats = ent:GetMaterials()
				RunConsoleCommand( "adv_colour_index", self.HUDData.Index )
			end
		end
		
		if IsValid(self.HUDData.AimEnt) then
			self.HUDData.Color = self.HUDData.AimEnt:GetColor()
		end
		
	end
	
	function TOOL:DrawHUD()
		if IsValid(self.HUDData.AimEnt) and table.Count(self.HUDData.Mats) > 1 then
			surface.SetFont("ChatFont")
			
			local OffsetX = ScrW()/2 - 50
			local Text = tostring(self.HUDData.AimEnt)..": "..tostring(table.Count(self.HUDData.Mats)).." materials"
			local MaxW, TextH = surface.GetTextSize(Text)
			MaxW = MaxW + 4
			local OffsetY, MaxH = ScrH()/2, (TextH * (table.Count(self.HUDData.Mats)+2))
			
			local GlobalText = "[Global] = "..self.HUDData.Color.r.." "..self.HUDData.Color.g.." "..self.HUDData.Color.b.." "..self.HUDData.Color.a
			local curw = surface.GetTextSize(GlobalText)
			if curw > MaxW then
				MaxW = curw
			end
			
			for k, v in pairs(self.HUDData.Mats) do
				if self.HUDData.AimEnt._adv_colours and self.HUDData.AimEnt._adv_colours[k+1] then
					local curw = surface.GetTextSize("["..k.."] = "..tostring(self.HUDData.AimEnt._adv_colours[k+1])) + 4
					if curw > MaxW then
						MaxW = curw
					end
				else
					local curw = surface.GetTextSize("["..k.."] = "..tostring(self.HUDData.DefColor)) + 4
					if curw > MaxW then
						MaxW = curw
					end
				end
			end
			
			surface.SetDrawColor( self.HUDData.BGColor )
			surface.DrawRect(OffsetX - MaxW, OffsetY - MaxH/2, MaxW, MaxH)
			
			surface.SetDrawColor( self.HUDData.BGSelColor )
			surface.DrawRect(OffsetX - MaxW, OffsetY - MaxH/2 + TextH * (self.HUDData.Index+1), MaxW, TextH)
			
			surface.SetTextColor( self.HUDData.TextColor )
			surface.SetTextPos(OffsetX - MaxW + 2, OffsetY - MaxH/2)
			surface.DrawText(Text)
			
			surface.SetTextColor( self.HUDData.TextColor )
			surface.SetTextPos(OffsetX - MaxW + 2, OffsetY - MaxH/2 + TextH)
			surface.DrawText(GlobalText)
			
			for k, v in pairs(self.HUDData.Mats) do
				surface.SetTextColor( self.HUDData.TextColor )
				surface.SetTextPos(OffsetX - MaxW + 2, OffsetY - MaxH/2 + TextH * (k+1))
				surface.DrawText("["..(k-1).."] = "..tostring(self.HUDData.AimEnt._adv_colours and self.HUDData.AimEnt._adv_colours[k-1] or self.HUDData.DefColor))
			end			
		end
	end
	
	function TOOL:DrawToolScreen( width, height )
	
		surface.SetFont( "GModToolScreen" )
		DrawScrollingText( "#tool.adv_colour.name", 104, 256 )
		
		local CPanel = controlpanel.Get( "adv_colour" )
		---@cast CPanel AdvColourCPanel
		
		if IsValid(CPanel) and CPanel.Int then
			
			local r, g, b = CPanel.Int:GetRGB()
			local h, s, l = CPanel.Int:GetHSL()
			local a = CPanel.Int:GetA()
			
			local col = Color( r, g, b )
			
			surface.SetDrawColor( (l > 0.4) and Color( 20, 20, 20, 220 ) or Color( 220, 220, 220, 100 ) )
			surface.DrawRect( 0, height/2, width, height/2 )
			
			draw.SimpleText( "R: "..r, "adv_colour_screen", width / 4, height / 2 + 35, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			draw.SimpleText( "G: "..g, "adv_colour_screen", width / 4 * 3, height / 2 + 35, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			draw.SimpleText( "B: "..b, "adv_colour_screen", width / 4, height / 2 + 85, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			draw.SimpleText( "A: "..a, "adv_colour_screen", width / 4 * 3, height / 2 + 85, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	local matGradient = Material( "vgui/gradient-u" )
	local matColors = Material( "gui/colors.png" ) 

	local PANEL = {}

	AccessorFunc( PANEL, "m_Value", "Value" )
	AccessorFunc( PANEL, "m_Hue", "Hue" )
	AccessorFunc( PANEL, "m_HalfBar", "HalfBar" )
	AccessorFunc( PANEL, "m_BarColorBG", "BarColorBG" )
	AccessorFunc( PANEL, "m_BarColorLeft", "BarColorLeft" )
	AccessorFunc( PANEL, "m_BarColorRight", "BarColorRight" )

	function PANEL:Init()
		
		self:SetBarColorBG( Color( 128, 128, 128, 255 ) )
		self:SetBarColorLeft( Color( 255, 255, 255, 255 ) )
		self:SetBarColorRight( Color( 0, 0, 0, 255 ) )
		self:SetSize( 26, 26 )
		self:SetValue( 1 )

	end

	function PANEL:OnCursorMoved( x, y )
		
		if ( !input.IsMouseDown( MOUSE_LEFT ) ) then return end
		
		local fWide = x / self:GetWide()
		
		fWide = math.Clamp( fWide, 0, 1 )
		
		self:SetValue( fWide )
		self:OnChange( fWide )
		
	end

	function PANEL:OnMousePressed( mcode )

		self:MouseCapture( true )
		self:OnCursorMoved( self:CursorPos() );
		
	end

	function PANEL:OnMouseReleased( mcode )

		self:MouseCapture( false )
		self:OnCursorMoved( self:CursorPos() );

	end

	function PANEL:OnChange( val )

	end

	function PANEL:Paint( w, h )
		
		if self:GetHue() then
			surface.SetMaterial( matColors )
			surface.SetDrawColor( self.m_BarColorLeft )
			surface.DrawTexturedRectRotated( w/2, h/2, h, w, 270 )
		else
			local halfbar = self:GetHalfBar()
			
			surface.SetDrawColor( self.m_BarColorBG )
			surface.DrawRect( 0, 0, w, h )
			
			surface.SetMaterial( matGradient )
			surface.SetDrawColor( self.m_BarColorLeft )
			surface.DrawTexturedRectRotated( w/(halfbar and 4 or 2), h/2, h, w/(halfbar and 2 or 1), 90 )
			
			surface.SetDrawColor( self.m_BarColorRight )
			surface.DrawTexturedRectRotated( w/2 + (halfbar and w/4 or 0), h/2, h, w/(halfbar and 2 or 1), 270 )
		end

		surface.SetDrawColor( 0, 0, 0, 250 )
		
		self:DrawOutlinedRect()
		
		surface.DrawRect( self.m_Value * w - 2, 0, 3, h )
		
		surface.SetDrawColor( 255, 255, 255, 250 )
		surface.DrawRect( self.m_Value * w - 1, 0, 1, h )

	end

	derma.DefineControl( "Adv_color_bar", "", PANEL, "DPanel" )
	
	local PANEL = {}
	
	PANEL.SetValue = function( s, val, ignore )

		if ( val == nil ) then return end
		
		local OldValue = val
		val = tonumber( val )
		val = val or 0
		
		if ( s.m_numMax != nil ) then
			val = math.min( s.m_numMax, val )
		end
		
		if ( s.m_numMin != nil ) then
			val = math.max( s.m_numMin, val )
		end
		
		if ( s.m_iDecimals == 0 ) then
		
			val = Format( "%i", val )
		
		elseif ( val != 0 ) then
		
			val = Format( "%."..s.m_iDecimals.."f", val )
			val = string.TrimRight( val, "0" )		
			val = string.TrimRight( val, "." )
			
		end
		
		s._Value = val
		
		if ( !s:HasFocus() ) then
			s:SetText( val )
			s:ConVarChanged( val )
		end
		
		if !ignore then s:OnValueChanged( val ) end

	end
	PANEL.OnTextChanged = function(s, noMenuRemoval)
		
		s.HistoryPos = 0
		
		if ( s:GetUpdateOnType() ) then
			s:UpdateConvarValue()
			s:OnValueChanged( s:GetText() )
		end
		
		if ( IsValid( s.Menu ) and not noMenuRemoval ) then
			s.Menu:Remove()
		end
		
		local tab = s:GetAutoComplete( s:GetText() )
		if ( tab ) then
			s:OpenAutoComplete( tab )
		end
		
		s:OnChange()
		
	end
	PANEL.GetValue = function( s )
		return s._Value or 0
	end
	PANEL.OnValueChanged = function( s, val )
		s:SetValue( val, true )
	end
	PANEL.OnLoseFocus = function( s )
		s:UpdateConvarValue()
		s:SetText( s:GetValue() )
		hook.Call( "OnTextEntryLoseFocus", nil, s )
	end

	derma.DefineControl( "Adv_color_num", "", PANEL, "DNumberWang" )

end

---@param CPanel AdvColourCPanel
function TOOL.BuildCPanel( CPanel )

	---DEPRECATED: Not changing this to keep original functionality
	---@diagnostic disable-next-line
	CPanel:AddControl( "Header", { Description	= "Colour Preview" } )
	
	---CLAIM: CPanel.Int seems guaranteed to be set.
	---Silencing the LuaLS warning unless the above is false.
	---@diagnostic disable-next-line
	CPanel.Int = {}

	local PRE = vgui.Create("DPanel", CPanel)
	PRE:SetPos( 0, 75 )
	PRE:SetSize( 300, 20 )
	PRE.Color = Color( 255, 255, 255 )
	PRE.Paint = function( s, w, h ) 
		surface.SetDrawColor( s.Color )
		surface.DrawRect( 0, 0, w, h )
		
		surface.SetDrawColor( 0, 0, 0, 250 )
		s:DrawOutlinedRect()
	end

	local RGBA = vgui.Create("DPanel", CPanel)
	RGBA:SetPos( 0, 100 )
	RGBA:SetSize( 300, 100 )
	RGBA.Paint = function() end

	local RBar = vgui.Create("Adv_color_bar", RGBA)
	local RNum = vgui.Create("Adv_color_num", RGBA)
	RBar:SetPos( 0, 0 )
	RBar:SetSize( 256, 20 )
	RBar:Dock( FILL )
	RBar:DockMargin( 0, 0, 5, 80 )
	RBar:SetBarColorLeft( Color( 0, 0, 0, 255 ) )
	RBar:SetBarColorRight( Color( 255, 0, 0, 255 ) )
	RBar.OnChange = function( s, val )
		local r, g, b = CPanel.Int:GetRGB()
		RNum:SetValue( math.Round( val * 255 ), true )
		CPanel.Int:UpdateRGB( math.Round( val * 255 ), g, b, false, false, false )
		CPanel.Int:UpdateHSL( math.Round( val * 255 ), g, b )
	end

	RNum:SetPos( 261, 0 )
	RNum:SetSize( 39, 20 )
	RNum:Dock( RIGHT )
	RNum:DockMargin( 0, 0, 0, 80 )
	RNum:SetDecimals( 0 )
	RNum:SetMinMax( 0, 255 )
	RNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local r, g, b = CPanel.Int:GetRGB()
		RBar:SetValue( tonumber(s:GetValue())/255, true )
		CPanel.Int:UpdateRGB( tonumber(s:GetValue()), g, b, false, false, false )
		CPanel.Int:UpdateHSL( tonumber(s:GetValue()), g, b )
	end

	local GBar = vgui.Create("Adv_color_bar", RGBA)
	local GNum = vgui.Create("Adv_color_num", RGBA)
	GBar:SetPos( 0, 25 )
	GBar:SetSize( 256, 20 )
	GBar:Dock( FILL )
	GBar:DockMargin( 0, 25, 5, 55 )
	GBar:SetBarColorLeft( Color( 0, 0, 0, 255 ) )
	GBar:SetBarColorRight( Color( 0, 255, 0, 255 ) )
	GBar.OnChange = function( s, val )
		local r, g, b = CPanel.Int:GetRGB()
		GNum:SetValue( math.Round( val * 255 ), true )
		CPanel.Int:UpdateRGB( r, math.Round( val * 255 ), b, false, false, false )
		CPanel.Int:UpdateHSL( r, math.Round( val * 255 ), b )
	end

	GNum:SetPos( 261, 25 )
	GNum:SetSize( 39, 20 )
	GNum:Dock( RIGHT )
	GNum:DockMargin( 0, 25, -39, 55 )
	GNum:SetDecimals( 0 )
	GNum:SetMinMax( 0, 255 )
	GNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local r, g, b = CPanel.Int:GetRGB()
		GBar:SetValue( tonumber(s:GetValue())/255, true )
		CPanel.Int:UpdateRGB( r, tonumber(s:GetValue()), b, false, false, false )
		CPanel.Int:UpdateHSL( r, tonumber(s:GetValue()), b )
	end

	local BBar = vgui.Create("Adv_color_bar", RGBA)
	local BNum = vgui.Create("Adv_color_num", RGBA)
	BBar:SetPos( 0, 50 )
	BBar:SetSize( 256, 20 )
	BBar:Dock( FILL )
	BBar:DockMargin( 0, 50, 5, 30 )
	BBar:SetBarColorLeft( Color( 0, 0, 0, 255 ) )
	BBar:SetBarColorRight( Color( 0, 0, 255, 255 ) )
	BBar.OnChange = function( s, val )
		local r, g, b = CPanel.Int:GetRGB()
		BNum:SetValue( math.Round( val * 255 ), true )
		CPanel.Int:UpdateRGB( r, g, math.Round( val * 255 ), false, false, false )
		CPanel.Int:UpdateHSL( r, g, math.Round( val * 255 ) )
	end

	BNum:SetPos( 261, 50 )
	BNum:SetSize( 39, 20 )
	BNum:Dock( RIGHT )
	BNum:DockMargin( 0, 50, -39, 30 )
	BNum:SetDecimals( 0 )
	BNum:SetMinMax( 0, 255 )
	BNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local r, g, b = CPanel.Int:GetRGB()
		BBar:SetValue( tonumber(s:GetValue())/255, true )
		CPanel.Int:UpdateRGB( r, g, tonumber(s:GetValue()), false, false, false )
		CPanel.Int:UpdateHSL( r, g, tonumber(s:GetValue()) )
	end

	local ABar = vgui.Create("Adv_color_bar", RGBA)
	local ANum = vgui.Create("Adv_color_num", RGBA)
	ABar:SetPos( 0, 75 )
	ABar:SetSize( 256, 20 )
	ABar:Dock( FILL )
	ABar:DockMargin( 0, 75, 5, 5 )
	ABar:SetBarColorLeft( Color( 0, 0, 0, 255 ) )
	ABar:SetBarColorRight( Color( 255, 255, 255, 255 ) )
	ABar.OnChange = function( s, val )
		local alpha = math.Round( val * 255 )
		ANum:SetValue( math.Round( val * 255 ), true )
		RunConsoleCommand( "adv_colour_a", math.Round( val * 255 ) )
	end

	ANum:SetPos( 261, 75 )
	ANum:SetSize( 39, 20 )
	ANum:Dock( RIGHT )
	ANum:DockMargin( 0, 75, -39, 5 )
	ANum:SetDecimals( 0 )
	ANum:SetMinMax( 0, 255 )
	ANum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		ABar:SetValue( tonumber(s:GetValue())/255, true )
		local alpha = math.Round( tonumber(s:GetValue()) or 255 )
		RunConsoleCommand( "adv_colour_a", alpha )
	end

	local HSL = vgui.Create("DPanel", CPanel)
	HSL:SetPos( 0, 225 )
	HSL:SetSize( 300, 75 )
	HSL.Paint = function() end

	local HBar = vgui.Create("Adv_color_bar", HSL)
	local HNum = vgui.Create("Adv_color_num", HSL)
	HBar:SetPos( 0, 0 )
	HBar:SetSize( 256, 20 )
	HBar:Dock( FILL )
	HBar:DockMargin( 0, 0, 5, 55 )
	HBar:SetBarColorLeft( Color( 255, 255, 255, 255 ) )
	HBar:SetHue( true )
	HBar.OnChange = function( s, val )
		local hue, sat, light = CPanel.Int:GetHSL()
		hue = math.Round(360 * val)
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		HNum:SetValue( hue, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end

	HNum:SetPos( 261, 0 )
	HNum:SetSize( 39, 20 )
	HNum:Dock( RIGHT )
	HNum:DockMargin( 0, 0, 0, 55 )
	HNum:SetDecimals( 1 )
	HNum:SetMinMax( 0, 360 )
	HNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local hue, sat, light = CPanel.Int:GetHSL()
		hue = tonumber(s:GetValue()) or hue
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		HBar:SetValue( hue/360, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end

	local SBar = vgui.Create("Adv_color_bar", HSL)
	local SNum = vgui.Create("Adv_color_num", HSL)
	SBar:SetPos( 0, 25 )
	SBar:SetSize( 256, 20 )
	SBar:Dock( FILL )
	SBar:DockMargin( 0, 25, 5, 30 )
	SBar:SetBarColorLeft( Color( 128, 128, 128, 255 ) )
	SBar:SetBarColorRight( Color( 255, 255, 255, 255 ) )
	SBar.OnChange = function( s, val )
		local hue, sat, light = CPanel.Int:GetHSL()
		sat = val
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		SNum:SetValue( sat * 100, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end

	SNum:SetPos( 261, 25 )
	SNum:SetSize( 39, 20 )
	SNum:Dock( RIGHT )
	SNum:DockMargin( 0, 25, -39, 30 )
	SNum:SetDecimals( 1 )
	SNum:SetMinMax( 0, 100 )
	SNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local hue, sat, light = CPanel.Int:GetHSL()
		sat = tonumber(s:GetValue()) / 100
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		SBar:SetValue( sat, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end

	local LBar = vgui.Create("Adv_color_bar", HSL)
	local LNum = vgui.Create("Adv_color_num", HSL)
	LBar:SetPos( 0, 50 )
	LBar:SetSize( 256, 20 )
	LBar:Dock( FILL )
	LBar:DockMargin( 0, 50, 5, 5 )
	LBar:SetBarColorLeft( Color( 0, 0, 0, 255 ) )
	LBar:SetBarColorRight( Color( 255, 255, 255, 255 ) )
	LBar.OnChange = function( s, val )
		local hue, sat, light = CPanel.Int:GetHSL()
		light = val
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		LNum:SetValue( light * 100, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end

	LNum:SetPos( 261, 50 )
	LNum:SetSize( 39, 20 )
	LNum:Dock( RIGHT )
	LNum:DockMargin( 0, 50, -39, 5 )
	LNum:SetDecimals( 1 )
	LNum:SetMinMax( 0, 100 )
	LNum.OnValueChanged = function( s, val )
		s:SetValue( val, true )
		local hue, sat, light = CPanel.Int:GetHSL()
		light = tonumber( s:GetValue() ) / 100
		
		local r, g, b = 0, 0, 0
		
		local C = (1 - math.abs(2 * light - 1)) * sat
		local X = C * (1 - math.abs((hue / 60) % 2) - 1)
		local M = light - C/2
		
		if hue < 60 then
			r, g, b = C + M, X + M, M
		elseif hue < 120 then
			r, g, b = X + M, C + M, M
		elseif hue < 180 then
			r, g, b = M, C + M, X + M
		elseif hue < 240 then
			r, g, b = M, X + M, C + M
		elseif hue < 300 then
			r, g, b = X + M, M, C + M
		else
			r, g, b = C + M, M, X + M
		end
		
		r = math.Round(r * 255)
		g = math.Round(g * 255)
		b = math.Round(b * 255)
		
		LBar:SetValue( light, true )
		CPanel.Int:UpdateRGB( r, g, b )
		CPanel.Int:UpdateHSL( r, g, b, false, false, false )
	end
	
	local HEX = vgui.Create("DPanel", CPanel)
	HEX:SetPos( 0, 325 )
	HEX:SetSize( 300, 25 )
	HEX.Paint = function() end
	
	local HLabel = vgui.Create("DLabel", HEX)
	HLabel:SetPos( 0, 0 )
	HLabel:SetSize( 100, 20 )
	HLabel:SetTextColor( Color( 0, 0, 0, 255 ) )
	HLabel:SetText( "Hexidecimal:          #" )
	
	local strAllowedNumericCharacters = "1234567890abcdefABCDEF"
	local Hext = vgui.Create( "DTextEntry", HEX )
	Hext:SetPos( 100, 0 )
	Hext:SetSize( 200, 20 )
	Hext:Dock( FILL )
	Hext:DockMargin( 100, 0, 0, 5 )
	Hext:SetText( "" )
	Hext.AllowInput = function( self, strValue )
		if ( self:CheckNumeric( strValue ) ) then return true end
		if #self:GetText() >= 6 then return true end
	end
	Hext.CheckNumeric = function( self, strValue )
		if ( !string.find ( strAllowedNumericCharacters, strValue, 1, true ) ) then
			return true
		end
		return false
	end
	Hext.OnChange = function( s )
		local text = s:GetText()
		
		if #text < 6 then
			for i = 1, 6-#text do
				text = "0"..text
			end
		end
		
		text = string.Right( text, 6 )
		
		local HR, HG, HB = tonumber(text[1]..text[2], 16), tonumber(text[3]..text[4], 16), tonumber(text[5]..text[6], 16)
		
		if HR and HG and HB then
			CPanel.Int:UpdateRGB( HR, HG, HB )
			CPanel.Int:UpdateHSL( HR, HG, HB )
		end
	end
	Hext.OnLoseFocus = function( s )
		
		s:UpdateConvarValue()
		s:OnChange()
		hook.Call( "OnTextEntryLoseFocus", nil, s )
		
	end

	CPanel.Int.UpdateRGB = function( s, r, g, b, ur, ug, ub )		
		RBar:SetBarColorLeft( Color( 0, g, b, 255 ) )
		RBar:SetBarColorRight( Color( 255, g, b, 255 ) )
		
		if ur != false then
			RBar:SetValue( r / 255, true )
			RNum:SetValue( r, true )
		end
		
		RunConsoleCommand( "adv_colour_r", r )
		
		GBar:SetBarColorLeft( Color( r, 0, b, 255 ) )
		GBar:SetBarColorRight( Color( r, 255, b, 255 ) )
		
		if ug != false then
			GBar:SetValue( g / 255, true )
			GNum:SetValue( g, true )
		end
		
		RunConsoleCommand( "adv_colour_g", g )
		
		BBar:SetBarColorLeft( Color( r, g, 0, 255 ) )
		BBar:SetBarColorRight( Color( r, g, 255, 255 ) )
		
		if ub != false then
			BBar:SetValue( b / 255, true )
			BNum:SetValue( b, true )
		end
		
		RunConsoleCommand( "adv_colour_b", b )
		
		CPanel.Int:UpdateHEX(r, g, b)
	end

	CPanel.Int.UpdateHSL = function( s, r, g, b, uh, us, ul )
		
		local cmax, cmin = math.max( r, g, b ), math.min( r, g, b )
		local hue = 0
		
		if cmax == r then
			if (g-b) != 0 and (cmax-cmin) != 0 then
				hue = (g-b)/(cmax-cmin)
			else
				hue = 0
			end
		elseif cmax == g then
			if (b-r) != 0 and (cmax-cmin) != 0 then
				hue = 2 + (b-r)/(cmax-cmin)
			else
				hue = 0
			end
		else
			if (r-g) != 0 and (cmax-cmin) != 0 then
				hue = 4 + (r-g)/(cmax-cmin)
			else
				hue = 0
			end
		end
		
		hue = hue * 60
		if (hue < 0) then hue = hue + 360 end
		
		if uh != false then
			HBar:SetValue( hue / 360, true )
			HNum:SetValue( hue, true )
		end
		
		local delta = (cmax-cmin)/255
		local light = ((cmax+cmin)/2)/255
		local sat = delta/(1 - math.abs(2*light - 1))
		
		if (cmax-cmin) == 0 then delta = 0 end
		if delta == 0 then sat = 0 end
		
		--SBar:SetBarColorRight( Color( r, g, b, 255 ) )
		
		if us != false then
			SBar:SetValue( sat, true )
			SNum:SetValue( sat * 100, true )
		end
		
		--LBar:SetBarColorRight( Color( r, g, b, 255 ) )
		
		if ul != false then
			LBar:SetValue( light, true )
			LNum:SetValue( light * 100, true )
		end
		
		CPanel.Int:UpdateHEX(r, g, b)
	end
	
	CPanel.Int.UpdateAlpha = function( s, a )
		ABar:SetValue( 1 )
		ANum:SetValue( 255 )
	end
	
	CPanel.Int.UpdateHEX = function( s, r, g, b )
		local HR, HG, HB = bit.tohex(r, 2), bit.tohex(g, 2), bit.tohex(b, 2)
		
		if HR and HG and HB then
			Hext:SetValue(HR..HG..HB)
			PRE.Color = Color(r, g, b)
		end
	end

	CPanel.Int.GetRGB = function( s )
		return RNum:GetValue() / 1, GNum:GetValue() / 1, BNum:GetValue() / 1
	end
	CPanel.Int.GetHSL = function( s )
		return HNum:GetValue() / 1, SNum:GetValue() / 100, LNum:GetValue() / 100
	end
	CPanel.Int.GetA = function( s )
		return ANum:GetValue() / 1
	end
	
	CPanel.Int:UpdateRGB( 255, 255, 255 )
	CPanel.Int:UpdateHSL( 255, 255, 255 )
	CPanel.Int:UpdateAlpha( 255 )
	
	CPanel:AddPanel( PRE )
	---DEPRECATED: Not changing this to keep original functionality
	---@diagnostic disable-next-line
	CPanel:AddControl( "Header", { Description	= "Red, Green, Blue, Alpha" } )
	CPanel:AddPanel( RGBA )
	---DEPRECATED: Not changing this to keep original functionality
	---@diagnostic disable-next-line
	CPanel:AddControl( "Header", { Description	= "Hue, Saturation, Lighting" } )
	CPanel:AddPanel( HSL )
	CPanel:AddPanel( HEX )
	
	---DEPRECATED: Not changing this to keep original functionality
	---@diagnostic disable-next-line
	local MODE = CPanel:AddControl( "ComboBox", { Label = "#tool.colour.mode", Options = list.Get( "RenderModes" ) } )
	MODE.OnSelect = function( s, index, value, data )
		RunConsoleCommand("adv_colour_mode", data.colour_mode)
	end
	
	---DEPRECATED: Not changing this to keep original functionality
	---@diagnostic disable-next-line
	local FX = CPanel:AddControl( "ComboBox", { Label = "#tool.colour.fx", Options = list.Get( "RenderFX" ) } )
	FX.OnSelect = function( s, index, value, data )
		RunConsoleCommand("adv_colour_fx", data.colour_fx)
	end

end
