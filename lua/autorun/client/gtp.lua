AddCSLuaFile()

if SERVER then
	resource.AddFile( "materials/crosshair/gtp_crosshair.vmt" )
end

gtp = gtp or {}

-- Not sure if having this many variables is healthy. Should look into a better method of managing values without contracting visual cancaids.
local neweyeangs
local cameratracehitpos
local mouse = {}
local mousemove = {}
mousemove.x = 0
mousemove.y = 0
local mousewheel = 0
local aimtime = 0 
local aimfov = 20
local aimfovtemp = 0
local aimdist = 0
local aimdisttemp = 0
local gcvdist = 0
local autoturn = 0
local autoturntimer = 0
local sideang = (Angle(0,0,0))
local movementanglefinal = (Angle(0,0,0))
local movementangletarget = (Angle(0,0,0))
local movementanglemouse = (Angle(0,0,0))
local playerangles = (Angle(0,0,0))
local gcvang = (Angle(0,0,0))
local gcvpos = (Vector(0,0,0))
local IsEnabled = false
local IsAiming = false
local AllowZoom = false
local IsPhysgunRotating = false
local AimIsToggled = false
local LastKeyRight = false
local viewzoomset = CreateConVar("gtp_viewdistance","140",FCVAR_ARCHIVE)
local viewheightset = CreateConVar("gtp_viewheight","2",FCVAR_ARCHIVE)
local viewrightset = CreateConVar("gtp_viewright","20",FCVAR_ARCHIVE)
local turnspeedset = CreateConVar("gtp_turnspeed","4",FCVAR_ARCHIVE)
local aimtimeset = CreateConVar("gtp_aimtime","3",FCVAR_ARCHIVE)
local setfov = CreateConVar("gtp_fov","4",FCVAR_ARCHIVE)
local setaimfov = CreateConVar("gtp_aimfov","20",FCVAR_ARCHIVE)
local setaimdist = CreateConVar("gtp_aimdist","50",FCVAR_ARCHIVE)
local toggleaim = CreateConVar("gtp_toggleaim","false",FCVAR_ARCHIVE)
local togglecrosshair = CreateConVar("gtp_togglecrosshair","false",FCVAR_ARCHIVE)

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
		
function SetToggleAim( ply, cmd, args )
	if args[1] then
		local boolinput = tobool( args[1] )
		toggleaim:SetBool( boolinput )
	end
end

concommand.Add("gtp_toggleaim", SetToggleAim )

function SetToggleCrosshair( ply, cmd, args )
	if args[1] then
		local boolinput = tobool( args[1] )
		togglecrosshair:SetBool( boolinput )
	end
end

concommand.Add("gtp_togglecrosshair", SetToggleCrosshair )
	
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
		turnspeedset:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_turnspeed", SetTurnSpeed )

function SetAimTime( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		aimtimeset:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_aimtime", SetAimTime )

function SetViewHeight( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		viewheightset:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_viewheight", SetViewHeight )

function SetViewRight( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		viewrightset:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_viewright", SetViewRight )

function SetFOV( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		setfov:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_fov", SetFOV )

function SetAimFOV( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		setaimfov:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_aimfov", SetAimFOV)

function SetAimDist( ply, cmd, args )
	if args[1] then
		local numberinput = tonumber( args[1] )
		setaimdist:SetFloat(numberinput)
	end
end

concommand.Add( "gtp_aimdist", SetAimDist )


function ConvertAim(from, to)
	local ang = to - from

	return ang:Angle()
end

function CLerp(start, endval, amount)
    local max = 360.0
    local half = 180
    local retval = 0.0
    local diff = 0.0
    
    if ((endval - start) < -180) then   
        diff = ((360 - start)+endval)*amount
        retval =  start+diff    
    elseif ((endval - start) > half) then
        diff = -((360 - endval)+start)*amount
        retval =  start+diff    
    else
        retval =  start+(endval-start)*amount
    end
    
    return retval
end

local function GCCalcView( ply, pos, angles, fov )

	local trace = {}
	local view = {}
	local dist = ( viewzoomset:GetFloat() ) -aimdist -- view distance
	
	if ( !ply:Alive() ) then return end
	
	-- offset calcview camera using player's original view
	angles.y = ( angles.y - playerangles.y - mousemove.x )
	angles.x = ( angles.x - playerangles.x + mousemove.y )
	
	local tmpang = Angle(angles.p, angles.y, angles.r)
	angles:Normalize()
	sideang = angles
	
	trace.start = pos
	trace.endpos = pos - ( angles:Forward() *dist ) + ( angles:Right() *viewrightset:GetFloat() ) + ( angles:Up() *viewheightset:GetFloat() )
	trace.filter = player.GetAll()
	trace.mins = Vector( -15, -15, -15 )
	trace.maxs = Vector( 15, 15, 15 )
	trace.mask = MASK_SHOT_HULL
	local trace = util.TraceHull( trace )
	
	if( trace.HitPos:Distance( pos ) < dist ) then
		dist = trace.HitPos:Distance( pos ) - 5
	end
	
	view.origin = pos - ( angles:Forward() *dist ) + ( angles:Right() *viewrightset:GetFloat() ) + ( angles:Up() *viewheightset:GetFloat() )
	view.angles = angles
	view.fov = fov -setfov:GetFloat() -aimfov
	view.drawviewer = true
	
	gcvang = angles
	gcvpos = pos
	gcvdist = dist

	return view

end

local function GCCreateMove( cmd )
	
	local ply = LocalPlayer()
	local trace = {}
	
	if ( !ply:Alive() ) then return end
	
	aimfov = Lerp(0.1, aimfov, aimfovtemp)
	aimdist = Lerp(0.1, aimdist, aimdisttemp)
	
	-- The crosshair hitpos trace is in here because it is less responsive in the calcview function.
	
	trace.start = gcvpos - ( gcvang:Forward() *gcvdist ) + ( gcvang:Right() *viewrightset:GetFloat() ) + ( gcvang:Up() *viewheightset:GetFloat() )
	trace.endpos = gcvang:Forward() *2147483647 
	trace.filter = LocalPlayer()
	trace.mask = MASK_SHOT
	cameratracehitpos = util.TraceLine( trace )
	
	if ( !IsPhysgunRotating ) then
		mouse.x = cmd:GetMouseX()
		mouse.y = cmd:GetMouseY()
	else
		mouse.x = 0
		mouse.y = 0
	end
	
	-- ((((((parentheses hell)))))))	
	if ( !AimIsToggled and cmd:KeyDown(IN_ATTACK) ) then
		IsAiming = true
		aimtime = CurTime() + aimtimeset:GetFloat()
	elseif ( !AimIsToggled ) and ( aimtime < CurTime() ) then
		IsAiming = false
	end
	
	if ( AimIsToggled ) then
		aimfovtemp = setaimfov:GetFloat()
		aimdisttemp = setaimdist:GetFloat()
	elseif ( !AimIsToggled ) then
		aimfovtemp = 0
		aimdisttemp = 0
	end
	
	if ( !AimIsToggled and cmd:KeyDown(IN_ATTACK2) and !toggleaim:GetBool() ) then
		aimfovtemp = setaimfov:GetFloat()
		aimdisttemp = setaimdist:GetFloat()
		IsAiming = true
	elseif ( !AimIsToggled ) and ( aimtime < CurTime() and !toggleaim:GetBool() ) then
		IsAiming = false
	end
	
	if ( !toggleaim:GetBool() and AimIsToggled and IsAiming ) then
		AimIsToggled = false
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
				cmd:SetForwardMove(cmd:GetSideMove())
				cmd:SetSideMove(0)
				autoturn = math.ApproachAngle( autoturn, mousemove.x+(25/turnspeedset:GetFloat()), 0.15)
					if autoturn > 360 then 
						autoturn = autoturn -360
					end
						elseif ( cmd:KeyDown(IN_MOVELEFT) ) then
							movementangletarget.y = movementanglemouse.y+45
							cmd:SetForwardMove(cmd:GetSideMove()*-1)
							cmd:SetSideMove(0)
							autoturn = math.ApproachAngle( autoturn, mousemove.x-(25/turnspeedset:GetFloat()), 0.15)
							if autoturn < -360 then 
								autoturn = autoturn +360
							end
			end
	end

	if ( cmd:KeyDown(IN_MOVERIGHT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and !IsAiming ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1-90
			movementangletarget.y = movementanglemouse.y
			cmd:SetForwardMove(cmd:GetSideMove())
			cmd:SetSideMove(0)
			autoturn = math.ApproachAngle( autoturn, mousemove.x+(80/turnspeedset:GetFloat()), 0.3)
			if autoturn > 360 then 
				autoturn = autoturn -360
			end
	end

	if ( cmd:KeyDown(IN_MOVELEFT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and !IsAiming ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1+90
			movementangletarget.y = movementanglemouse.y
			cmd:SetForwardMove(cmd:GetSideMove()*-1)
			cmd:SetSideMove(0)
			autoturn = math.ApproachAngle( autoturn, mousemove.x-(80/turnspeedset:GetFloat()), 0.3)
			if autoturn < -360 then 
				autoturn = autoturn +360
			end
	end

	if ( cmd:KeyDown(IN_BACK) and !IsAiming ) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1+180
		movementangletarget.y = movementanglemouse.y
		cmd:SetForwardMove(cmd:GetForwardMove()*-1)
		if not ( cmd:KeyDown(IN_MOVELEFT) or cmd:KeyDown(IN_MOVERIGHT) ) then
			if ( LastKeyRight ) then
			autoturn = math.ApproachAngle( autoturn, mousemove.x+(80/turnspeedset:GetFloat()), 0.3)
				if autoturn > 360 then 
					autoturn = autoturn -360
				end
			else
			autoturn = math.ApproachAngle( autoturn, mousemove.x-(80/turnspeedset:GetFloat()), 0.3)
				if autoturn > 360 then 
					autoturn = autoturn -360
				end
			end
		end
			if ( cmd:KeyDown(IN_MOVERIGHT) ) then
				LastKeyRight = true
				movementangletarget.y = movementanglemouse.y+45
				cmd:SetForwardMove(cmd:GetSideMove())
				cmd:SetSideMove(0)
				autoturn = math.ApproachAngle( autoturn, mousemove.x+(25/turnspeedset:GetFloat()), 0.15)
					if autoturn > 360 then 
						autoturn = autoturn -360
					end
					elseif ( cmd:KeyDown(IN_MOVELEFT) ) then
						LastKeyRight = false
						movementangletarget.y = movementanglemouse.y-45
						cmd:SetForwardMove(cmd:GetSideMove()*-1)
						cmd:SetSideMove(0)
						autoturn = math.ApproachAngle( autoturn, mousemove.x-(25/turnspeedset:GetFloat()), 0.15)
							if autoturn > 360 then 
								autoturn = autoturn -360
							end
			end
	end

	-- for some reason, having this mouse stuff in here instead of in the calcview function makes it work much better. So don't touch this stuff.
	-- TODO: add variables to change mouse sensitiviy in these (currently dictated by the /35's)
	mousemove.x = math.Clamp( mouse.x /(35+aimfov) + mousemove.x, -360, 360)
	if ( mousemove.x == 360 ) or ( mousemove.x == -360 ) then mousemove.x = 0 end
	mousemove.x = CLerp( mousemove.x, autoturn, 0.03 )
	
	mousemove.y = math.Clamp( mouse.y /(35+aimfov) + mousemove.y, -60, 89 )
	
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
	
	-- these two lines below seem redundant, but they're actually necessary. Without one another the camera will sometimes refuse to update fast enough, causing it to "flick" randomly. Dunno why this happens.
	if ( playerangles != movementanglefinal ) then
	cmd:SetViewAngles(movementanglefinal)
	end

	playerangles = cmd:GetViewAngles()
	cmd:SetViewAngles(movementanglefinal)
	
	return true
end

function GCCrosshair()
	
	if ( IsAiming and togglecrosshair:GetBool() ) then
		surface.SetDrawColor( 255, 255, 255, 255 )
	else
		surface.SetDrawColor( 255, 255, 255, 0 )
	end
	
	surface.SetTexture(surface.GetTextureID("crosshair/gtp_crosshair"))
	surface.DrawTexturedRect( ScrW()/2 - 7, ScrH()/2 - 5, 12, 12 )
	
end

function HideDefaultCrosshair(element)
	if ( element == "CHudCrosshair" ) and ( togglecrosshair:GetBool() ) then
		return false
	elseif ( element == "CHudCrosshair" ) and ( !togglecrosshair:GetBool() ) then
		return true
	end
end

local function GCBindPress( ply, bind, pressed )
	if ( ply:KeyDown(IN_WALK) ) then
		if ( string.find( bind, "invnext" ) ) or ( string.find( bind, "invprev" ) ) then return true 
		end
	end
end

local function GCKeyPress( ply, key )
	if !game.SinglePlayer() and !IsFirstTimePredicted() then return end
	if !IsValid( ply ) or ply != LocalPlayer() then return end
	
	if  ( key == IN_ATTACK2 ) and ( toggleaim:GetBool() ) and ( !AimIsToggled ) then
			IsAiming = true
			AimIsToggled = true
	elseif ( key == IN_ATTACK2 ) and ( toggleaim:GetBool() ) and ( AimIsToggled ) then
			IsAiming = false
			AimIsToggled = false
			aimfov = Lerp(0.5, 0, aimfov)
	end
end

-- TODO: Add hook checks for health & safety reasons. Also add hook checks for CTP and STP and maybe the PAC camera for compatibility.
function gtp:Enable()
	IsEnabled = true
	print("attempting to create gtp hooks")
	hook.Add( "CreateMove", "GCCreateMove", GCCreateMove )
	hook.Add( "CalcView", "GCCalcView", GCCalcView )
	hook.Add( "PlayerBindPress", "GCBindPress", GCBindPress )
	hook.Add( "KeyPress" , "GCKeyPress", GCKeyPress )
	hook.Add( "HUDPaint","Crosshair", GCCrosshair )
	hook.Add( "HUDShouldDraw", "HideDefaultCrosshair", HideDefaultCrosshair )
end

function gtp:Disable()
	IsEnabled = false
	print("attempting to remove gtp hooks")
	hook.Remove( "CreateMove", "GCCreateMove", GCCreateMove )
	hook.Remove( "CalcView", "GCCalcView", GCCalcView )
	hook.Remove( "HUDPaint","Crosshair", GCCrosshair )
	hook.Remove( "PlayerBindPress", "GCBindPress", GCBindPress )
	hook.Remove( "KeyPress" , "GCKeyPress", GCKeyPress )
	hook.Remove( "HUDShouldDraw", "HideDefaultCrosshair", HideDefaultCrosshair )
end

function gtp:Toggle()
	if ( IsEnabled ) then
			gtp:Disable()
	else
			gtp:Enable()
	end
end


-- Spawnmenu GUI
-- TODO: Make the GUI less cancer
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
		Panel:ControlHelp("Hint: You can also use Alt+Scrollwheel to change the view distance on the fly")
		
		local params = {}
		params.Label = "Turning Speed:"
		params.Type = "Float" 
		params.Min = 0
		params.Max = 10
		params.Command = "gtp_turnspeed"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the player character turning rate (higher is faster)")
		
		local params = {}
		params.Label = "Aiming Time:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_aimtime"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the amount of time your player character aims for (in seconds)")
		
		local params = {}
		params.Label = "Aiming Distance:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_aimdist"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the aiming distance")
		
		local params = {}
		params.Label = "Aiming Field of View:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_aimfov"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the aiming FoV")
		
		Panel:CheckBox("Toggle Aim on RMB Click:","gtp_toggleaim")
		Panel:ControlHelp("Aim is toggled on click instead of operating on a timer")
		
		Panel:CheckBox("Use custom crosshair:","gtp_togglecrosshair")
		Panel:ControlHelp("Use GTP's crosshair instead of default; only appears when aiming")
		
		local params = {}
		params.Label = "Field of View:"
		params.Type = "Float" 
		params.Min = -100
		params.Max = 100
		params.Command = "gtp_fov"
		Panel:AddControl( "Slider", params )
		Panel:ControlHelp("Sets the overall thirdperson FOV (current numbers are dumb, I know, will be fixed later)")
		
	end

	local function creategtpmenu()
		spawnmenu.AddToolMenuOption("Utilities", "Gamechanger", "gtpsettings", "GTP Settings", "", "", SettingsPanel)
	end
	
	hook.Add( "PopulateToolMenu", "gtpmenus", creategtpmenu)
	
end
