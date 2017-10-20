AddCSLuaFile()

gtp = gtp or {}
local mouse = {}
local mousemove = {}
mousemove.x = 0
mousemove.y = 0
local mousewheel = 0
local viewzoom = 140 -- view distance defaults to this when the script loads
local viewheightset = 2 -- view height defaults to this when the script loads
local turnspeed = 0
local turnspeedset = 4 -- character turning speed defaults to this when the script loads
local aimtime = 0 
local aimtimeset = 3 -- aiming time defaults to this when the script loads
local movementanglefinal = (Angle(0,0,0))
local movementangletarget = (Angle(0,0,0))
local movementanglemouse = (Angle(0,0,0))
local playerangles = (Angle(0,0,0))
local IsEnabled = false
local IsAiming = false
local AllowZoom = false

concommand.Add("gtp_toggle", function()
	gtp:Toggle()
end)

function SetViewDistance( ply, cmd, args )
	if args[1] then
	local numberinput = tonumber( args[1] )
		viewzoom = numberinput
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


function GCCalcView( ply, pos, angles, fov )

	local view = {}
	local dist = viewzoom -- view distance
	local trace = {}


	-- offset calcview camera using player's original view
	angles.y = ( angles.y - playerangles.y - mousemove.x )
	angles.x = ( angles.x - playerangles.x + mousemove.y )
	
	trace.start = pos
	trace.endpos = pos - ( angles:Forward() *dist ) + ( angles:Right() *20 ) + ( angles:Up() *-4 )
	trace.filter = LocalPlayer()
	local trace = util.TraceLine( trace )

	if( trace.HitPos:Distance( pos ) < dist - 0.05 ) then
		dist = trace.HitPos:Distance( pos ) - 5
	end
	
	view.origin = pos - ( angles:Forward() *dist ) + ( angles:Right() *20 ) + ( angles:Up() *viewheightset )
	view.angles = angles
	view.fov = fov -4
	view.drawviewer = true
	
	return view

end

function GCCreateMove( cmd )
	
	local ply = LocalPlayer()
	
	mousewheel = cmd:GetMouseWheel()
	mouse.x = cmd:GetMouseX()
	mouse.y = cmd:GetMouseY()

	if (IsAiming == true) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1
		movementangletarget.y = movementanglemouse.y
		turnspeed = 9999
		else 
		turnspeed = turnspeedset
	end

	if (cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)) then
		IsAiming = true
		aimtime = CurTime() + aimtimeset
	elseif (aimtime < CurTime()) then
		IsAiming = false
	end
	
	if (cmd:KeyDown(IN_WALK)) then
		AllowZoom = true
	else
		AllowZoom = false
	end
		

	if (cmd:KeyDown(IN_FORWARD) and IsAiming == false) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1
		movementangletarget.y = movementanglemouse.y
			if (cmd:KeyDown(IN_MOVERIGHT)) then
				movementangletarget.y = movementanglemouse.y-45
				cmd:SetSideMove(0)
					cmd:SetForwardMove(1000)
						elseif (cmd:KeyDown(IN_MOVELEFT)) then
							movementangletarget.y = movementanglemouse.y+45
							cmd:SetSideMove(0)
							cmd:SetForwardMove(1000)
			end
	end

	if (cmd:KeyDown(IN_MOVERIGHT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and IsAiming == false ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1-90
			movementangletarget.y = movementanglemouse.y
			cmd:SetSideMove(0)
			cmd:SetForwardMove(1000)
	end

	if (cmd:KeyDown(IN_MOVELEFT) and not cmd:KeyDown(IN_FORWARD) and not cmd:KeyDown(IN_BACK) and IsAiming == false ) then
			movementanglefinal.x = mousemove.y
			movementanglemouse.y = mousemove.x*-1+90
			movementangletarget.y = movementanglemouse.y
			cmd:SetSideMove(0)
			cmd:SetForwardMove(1000)
	end

	if (cmd:KeyDown(IN_BACK) and IsAiming == false ) then
		movementanglefinal.x = mousemove.y
		movementanglemouse.y = mousemove.x*-1+180
		movementangletarget.y = movementanglemouse.y
		cmd:SetForwardMove(1000)
			if (cmd:KeyDown(IN_MOVERIGHT)) then
				movementangletarget.y = movementanglemouse.y+45
				cmd:SetSideMove(0)
				cmd:SetForwardMove(1000)
					elseif (cmd:KeyDown(IN_MOVELEFT)) then
						movementangletarget.y = movementanglemouse.y-45
						cmd:SetSideMove(0)
						cmd:SetForwardMove(1000)
			end
	end

	-- for some reason, having this mouse stuff in here (createmove func) instead of in the calcview function makes it work much better. So don't move this stuff.
	
	mousemove.x = math.Clamp( mouse.x /35 + mousemove.x, -360, 360)
	if ( mousemove.x == 360 ) or ( mousemove.x == -360 ) then mousemove.x = 0 end
	
	mousemove.y = math.Clamp( mouse.y /35 + mousemove.y, -60, 89 )
	
	if ( AllowZoom == true ) then 
		viewzoom = math.Clamp( mousewheel*-10 + viewzoom, 20, 800 )
	end


	movementanglefinal.y = math.ApproachAngle( movementanglefinal.y , movementangletarget.y , turnspeed)

	if (playerangles != movementanglefinal) then
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
	if (IsAiming == true) then
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
	hook.Add( "HUDPaint","Crosshair", GCCrosshair)
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

	if IsEnabled == true then

			gtp:Disable()
	else
			gtp:Enable()
	end

end
