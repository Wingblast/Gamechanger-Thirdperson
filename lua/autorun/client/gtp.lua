AddCSLuaFile()

gtp = gtp or {}
local neweyeangs
local cameratracehitpos
local mouse = {}
local mousemove = {}
mousemove.x = 0
mousemove.y = 0
local mousewheel = 0
local aimtime = 0 
local sideang = (Angle(0,0,0))
local movementanglefinal = (Angle(0,0,0))
local movementangletarget = (Angle(0,0,0))
local movementanglemouse = (Angle(0,0,0))
local playerangles = (Angle(0,0,0))
local IsEnabled = false
local IsAiming = false
local AllowZoom = false
local IsPhysgunRotating = false

local viewzoomset = CreateConVar("gtp_viewdistance","140",FCVAR_ARCHIVE)
local viewheightset = CreateConVar("gtp_viewheight","2",FCVAR_ARCHIVE)
local viewrightset = CreateConVar("gtp_viewright","20",FCVAR_ARCHIVE)
local turnspeedset = CreateConVar("gtp_turnspeed","4",FCVAR_ARCHIVE)
local aimtimeset = CreateConVar("gtp_aimtime","3",FCVAR_ARCHIVE)
local setfov = CreateConVar("gtp_fov","4",FCVAR_ARCHIVE)

local DisabledMoveTypes = {
	[MOVETYPE_FLY] = true,
	[MOVETYPE_FLYGRAVITY] = true,
	[MOVETYPE_OBSERVER] = true,
	[MOVETYPE_NOCLIP] = true
}

concommand.Add("gtp_toggle", function()
	gtp:Toggle()
	local plyeyeangs = LocalPlayer():EyeAngles()
	movementangletarget.y = plyeyeangs.y
	movementanglefinal.y = plyeyeangs.y
	movementanglefinal.x = plyeyeangs.x
	mousemove.x = plyeyeangs.y*-1
	mousemove.y = plyeyeangs.x
end)

function SetViewDistance( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		viewzoomset:SetFloat( numberinput )
	end
end

concommand.Add( "gtp_viewdistance", SetViewDistance )

function SetTurnSpeed( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		turnspeedset = numberinput
	end
end

concommand.Add( "gtp_turnspeed", SetTurnSpeed )

function SetAimTime( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		aimtimeset = numberinput
	end
end

concommand.Add( "gtp_aimtime", SetAimTime )

function SetViewHeight( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		viewheightset = numberinput
	end
end

concommand.Add( "gtp_viewheight", SetViewHeight )

function SetViewRight( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		viewrightset = numberinput
	end
end

concommand.Add( "gtp_viewright", SetViewRight )

function SetFOV( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		setfov = numberinput
	end
end

concommand.Add( "gtp_fov", SetFOV )

function ConvertAim(from, to)
	local ang = to - from

	return ang:Angle()
end

function GCCalcView( ply, pos, angles, fov )

	local trace = {}
	local view = {}
	local dist = viewzoomset:GetFloat() -- view distance
	local viewheight = viewheightset:GetFloat()
	local viewright = viewrightset:GetFloat()
	
	-- offset calcview camera using player's original view
	angles.y = ( angles.y - playerangles.y - mousemove.x )
	angles.x = ( angles.x - playerangles.x + mousemove.y )
	
	local tmpang = Angle(angles.p, angles.y, angles.r)
	angles:Normalize()
	sideang = angles
	
	trace.start = pos
	trace.endpos = pos - ( angles:Forward() *dist ) + ( angles:Right() *viewright ) + ( angles:Up() *viewheight )
	trace.filter = player.GetAll()
	trace.mins = Vector( -15, -15, -15 )
	trace.maxs = Vector( 15, 15, 15 )
	trace.mask = MASK_SHOT_HULL
	local trace = util.TraceHull( trace )
	
	if( trace.HitPos:Distance( pos ) < dist - 0.05 ) then
		dist = trace.HitPos:Distance( pos ) - 5
	end
	
	trace.start = pos - ( angles:Forward() *dist ) + ( angles:Right() *viewright ) + ( angles:Up() *viewheight )
	trace.endpos = angles:Forward() *2147483647 
	trace.filter = LocalPlayer()
	trace.mask = MASK_SHOT
	cameratracehitpos = util.TraceLine( trace )
	
	view.origin = pos - ( angles:Forward() *dist ) + ( angles:Right() *viewright ) + ( angles:Up() *viewheight )
	view.angles = angles
	view.fov = fov -setfov:GetFloat()
	view.drawviewer = true
	
	return view

end

function GCCreateMove( cmd )
	
	local ply = LocalPlayer()
	
	if ( !ply:Alive() ) then return end
	
	if ( !IsPhysgunRotating ) then
		mouse.x = cmd:GetMouseX()
		mouse.y = cmd:GetMouseY()
	else
		mouse.x = 0
		mouse.y = 0
	end
	
	if ( cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2) ) then
		IsAiming = true
		aimtime = CurTime() + aimtimeset:GetFloat()
	elseif ( aimtime < CurTime() ) then
		IsAiming = false
	end
	
	if ( cmd:KeyDown(IN_WALK) ) then
		AllowZoom = true
	else
		AllowZoom = false
	end
		
	if ( ply:GetActiveWeapon():IsValid() ) and ( ply:GetActiveWeapon():GetClass() == "weapon_physgun" ) and ( cmd:KeyDown(IN_ATTACK) ) and ( cmd:KeyDown(IN_USE) ) then
		IsPhysgunRotating = true
	else
		IsPhysgunRotating = false
	end


	if ( cmd:KeyDown(IN_FORWARD) and !IsAiming ) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1
		movementangletarget.y = movementanglemouse.y
			if ( cmd:KeyDown(IN_MOVERIGHT) ) then
				movementangletarget.y = movementanglemouse.y-45
				cmd:SetSideMove(0)
					cmd:SetForwardMove(1000)
						elseif ( cmd:KeyDown(IN_MOVELEFT) ) then
							movementangletarget.y = movementanglemouse.y+45
							cmd:SetSideMove(0)
							cmd:SetForwardMove(1000)
			end
	end

	if ( cmd:KeyDown(IN_MOVERIGHT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and !IsAiming ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1-90
			movementangletarget.y = movementanglemouse.y
			cmd:SetSideMove(0)
			cmd:SetForwardMove(1000)
	end

	if ( cmd:KeyDown(IN_MOVELEFT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and !IsAiming ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1+90
			movementangletarget.y = movementanglemouse.y
			cmd:SetSideMove(0)
			cmd:SetForwardMove(1000)
	end

	if ( cmd:KeyDown(IN_BACK) and !IsAiming ) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1+180
		movementangletarget.y = movementanglemouse.y
		cmd:SetForwardMove(1000)
			if ( cmd:KeyDown(IN_MOVERIGHT) ) then
				movementangletarget.y = movementanglemouse.y+45
				cmd:SetSideMove(0)
				cmd:SetForwardMove(1000)
					elseif ( cmd:KeyDown(IN_MOVELEFT) ) then
						movementangletarget.y = movementanglemouse.y-45
						cmd:SetSideMove(0)
						cmd:SetForwardMove(1000)
			end
	end

	-- for some reason, having this mouse stuff in here instead of in the calcview function makes it work much better. So don't touch this stuff.
	
	mousemove.x = math.Clamp( mouse.x /35 + mousemove.x, -360, 360)
	if ( mousemove.x == 360 ) or ( mousemove.x == -360 ) then mousemove.x = 0 end
	
	mousemove.y = math.Clamp( mouse.y /35 + mousemove.y, -60, 89 )
	
	if ( AllowZoom ) then 
		mousewheel = cmd:GetMouseWheel()
		viewzoomset:SetFloat( math.Clamp( mousewheel*-10 + viewzoomset:GetFloat(), 20, 800 ) )
	end
	
	if ( IsAiming ) then
		neweyeangs = ConvertAim(ply:GetShootPos(), cameratracehitpos.HitPos)
		neweyeangs:Normalize()
		movementangletarget.x = neweyeangs.x
		movementangletarget.y = neweyeangs.y
		movementanglefinal.y = neweyeangs.y
		movementanglefinal.x = neweyeangs.x
		
		-- allows for the character's movement angles to remain unchanged while aiming
		if ( !DisabledMoveTypes[ply:GetMoveType()] ) then 
			movementvector = Vector( cmd:GetForwardMove(), cmd:GetSideMove(), cmd:GetUpMove() )
			movementvector:Rotate( cmd:GetViewAngles() - sideang )
			cmd:SetForwardMove( movementvector.x )
			cmd:SetSideMove( movementvector.y )
		end
	else
		movementanglefinal.y = math.ApproachAngle( movementanglefinal.y , movementangletarget.y , turnspeedset:GetFloat() )
	end

	if ( playerangles != movementanglefinal ) then
	cmd:SetViewAngles(movementanglefinal)
	end

	playerangles = cmd:GetViewAngles()
	cmd:SetViewAngles(movementanglefinal)
	
	return true
end

function GCCrosshair()

	local p = LocalPlayer():GetEyeTrace().HitPos:ToScreen()
	local x,y = p.x, p.y
	 
	--set the drawcolor
	if ( IsAiming ) then
		surface.SetDrawColor( 255, 255, 255, 0 )
		else 
		surface.SetDrawColor( 255, 255, 255, 0 )
	end
	 
	local gap = 5
	local length = gap + 15
	 
	--draw the crosshair
	surface.DrawLine( x - length, y, x - gap, y )
	surface.DrawLine( x + length, y, x + gap, y )
	surface.DrawLine( x, y - length, x, y - gap )
	surface.DrawLine( x, y + length, x, y + gap )
	
end

function GCBindPress( ply, bind, pressed )
	if ( ply:KeyDown(IN_WALK) ) then
		if ( string.find( bind, "invnext" ) ) or ( string.find( bind, "invprev" ) ) then return true 
		end
	end
end

function gtp:Enable()
	IsEnabled = true
	print("attempting to create gtp hooks")
	hook.Add( "CreateMove", "GCCreateMove", GCCreateMove )
	hook.Add( "CalcView", "GCCalcView", GCCalcView )
	hook.Add( "HUDPaint","Crosshair", GCCrosshair )
	hook.Add( "PlayerBindPress", "GCBindPress", GCBindPress )
end

function gtp:Disable()
	IsEnabled = false
	print("attempting to remove gtp hooks")
	hook.Remove( "CreateMove", "GCCreateMove", GCCreateMove )
	hook.Remove( "CalcView", "GCCalcView", GCCalcView )
	hook.Remove( "HUDPaint","Crosshair", GCCrosshair )
	hook.Remove( "PlayerBindPress", "GCBindPress", GCBindPress )
end

function gtp:Toggle()
	if ( IsEnabled ) then
			gtp:Disable()
	else
			gtp:Enable()
	end
end

if CLIENT then

	local function SettingsPanel( Panel )
	
		Panel:Button("Toggle Thirdperson","gtp_toggle")
		
		local params = {}
		params.Label = "Offset X:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_viewright"
		Panel:AddControl( "Slider", params )

		local params = {}
		params.Label = "Offset Z:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_viewheight"
		Panel:AddControl( "Slider", params )
		
		local params = {}
		params.Label = "Camera View Distance:"
		params.Type = "Float" 
		params.Min = 0
		params.Max = 1000
		params.Command = "gtp_viewdistance"
		Panel:AddControl( "Slider", params )
		
		local params = {}
		params.Label = "Turning Speed:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_turnspeed"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the amount of time it takes for your player character to turn (in seconds)")
		
		local params = {}
		params.Label = "Aiming Time:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_aimtime"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the amount of time your player character aims for (in seconds)")
		
		local params = {}
		params.Label = "Field of View:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_fov"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the thirdperson FOV (current numbers are dumb, I know, will be fixed later)")
		
	end

	local function creategtpmenu()
		spawnmenu.AddToolMenuOption("Utilities", "Gamechanger", "gtpsettings", "Thirdperson Settings", "", "", SettingsPanel)
	end
	
	hook.Add( "PopulateToolMenu", "gtpmenus", creategtpmenu)
	
end
