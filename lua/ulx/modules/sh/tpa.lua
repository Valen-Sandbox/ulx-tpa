local CATEGORY_NAME = "Teleport"

-- Utility function originally used for bring, goto, and send
local function playerSend( from, to, force )
	if not to:IsInWorld() and not force then return false end -- No way we can do this one

	local yawForward = to:EyeAngles().yaw
	local directions = { -- Directions to try
		math.NormalizeAngle( yawForward - 180 ), -- Behind first
		math.NormalizeAngle( yawForward + 90 ), -- Right
		math.NormalizeAngle( yawForward - 90 ), -- Left
		yawForward,
	}

	local t = {}
	t.start = to:GetPos() + Vector( 0, 0, 32 ) -- Move them up a bit so they can travel across the ground
	t.filter = { to, from }

	local i = 1
	t.endpos = to:GetPos() + Angle( 0, directions[ i ], 0 ):Forward() * 47 -- (33 is player width, this is sqrt( 33^2 * 2 ))
	local tr = util.TraceEntity( t, from )
	while tr.Hit do -- While it's hitting something, check other angles
		i = i + 1
		if i > #directions then	 -- No place found
			if force then
				from.ulx_prevpos = from:GetPos()
				from.ulx_prevang = from:EyeAngles()
				return to:GetPos() + Angle( 0, directions[ 1 ], 0 ):Forward() * 47
			else
				return false
			end
		end

		t.endpos = to:GetPos() + Angle( 0, directions[ i ], 0 ):Forward() * 47

		tr = util.TraceEntity( t, from )
	end

	from.ulx_prevpos = from:GetPos()
	from.ulx_prevang = from:EyeAngles()
	return tr.HitPos
end

--[[---------------------------------------------------------------------------
TPRequest
By velkon or something
-----------------------------------------------------------------------------]]

local expire = 30 -- How many seconds the tpr lasts

if SERVER then
	local function doTeleport( ply, to )
		if to.TPPending == ply then
			local pos = playerSend( ply, to, false )
			if not pos then
				ULib.tsayError( ply, "Cannot find a place to put you!", true )
				ULib.tsayError( to, "Cannot find a place to put player!", true )

				to.TPPending = nil

				return
			end
			local newang = ( ply:GetPos() - pos ):Angle()

			ply:SetPos( pos )
			ply:SetEyeAngles( newang )
			ply:SetLocalVelocity( vector_zero )
			to.TPPending = nil
		end
	end

	hook.Add("PlayerSay", "ULX_TeleportRequest", function(ply, txt)
		if not ply.TPPending then return end

		if txt:match( "^[!/]tpaccept$" ) then

			ULib.tsay( ply.TPPending, ply:Nick() .. " has accepted your teleport request. Teleporting...", true )
			doTeleport( ply.TPPending, ply )

			return ""
		elseif txt:match( "^[!/]tpdeny$" ) then

			ULib.tsayError( ply, "You have denied the teleport request!", true )
			ply.TPPending = nil

			return ""
		end
	end)
end

function ulx.tpa( ply, target )
	if not SERVER then return end

	if target.TPPending then
		ULib.tsayError( ply, "Target already has a teleport request pending!", true )
		return
	end

	target.TPPending = ply
	ULib.tsay( ply, "Teleport request sent to " .. target:Nick() .. "!", true )
	ULib.tsay( target, ply:Nick() .. " would like to teleport to you; you can type !tpaccept or !tpdeny to accept or deny. Expires in " .. expire .. " seconds.", true )

	timer.Simple( expire, function()
		if ply and target and target.TPPending == ply then
			target.TPPending = nil
			ULib.tsayError( ply, "Teleport request has expired...", true )
		end
	end )
end

local tpa = ulx.command( CATEGORY_NAME, "ulx tpa", ulx.tpa, "!tpa" )
tpa:addParam{ type = ULib.cmds.PlayerArg, target = "!^" }
tpa:defaultAccess( ULib.ACCESS_ALL )
tpa:help( "Send a teleport request to the target player." )