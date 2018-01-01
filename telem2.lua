-- 2017 John Ihlein - Modifed to work with Dronin flight firmware
-- Copyright (c) 2015 dandys.
-- Copyright (c) 2014 Marco Ricci.
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    A copy of the GNU General Public License is available at <http://www.gnu.org/licenses/>.
--    
-- Radar is based on Volke Wolkstein MavLink telemetry script
-- https://github.com/wolkstein/MavLink_FrSkySPort

-- Various local variables
local X1, Y1, X2, Y2, XH, YH
local delta, deltaX, deltaY

local firstPass = 1
local homeSet   = 0
local prevGpss  = 0

-- ************
-- Draw a shape
-- ************

local sinShape, cosShape

local function drawShape(col, row, shape, rotation)
	sinShape = math.sin(rotation)
	cosShape = math.cos(rotation)

	for index, point in pairs(shape) do
	lcd.drawLine(
	             col + (point[1] * cosShape - point[2] * sinShape),
	             row + (point[1] * sinShape + point[2] * cosShape),
	             col + (point[3] * cosShape - point[4] * sinShape),
	             row + (point[3] * sinShape + point[4] * cosShape),
	             SOLID, 
	             FORCE)
	end
end

-- ***************
-- Draw an ellipse
-- ***************

local function drawEllipse( col, row, width, height )
	X1 = col + width
	Y1 = row

	for i = 12, 360, 12 do
		X2 = col + (width  * math.cos(math.rad(i)))
		Y2 = row + (height * math.sin(math.rad(i)))
		lcd.drawLine( X1, Y1, X2, Y2, SOLID, 0 )
		X1 = X2
		Y1 = Y2
	end
end

-- **************
-- Telemetry data
-- **************

local yaw, pitch, roll = 0, 0, 0
local altitude, speed = 0, 0
local heading, direction = 0, 0
local latitude, longitude = 0, 0
local homeLatitude, homeLongitude = 0, 0
local vdop, hdop, sats, verticalSpeed, rssi, cellVoltage = 0, 0, 0, 0, 0, 0
local modeString, gpsString = "", ""
local isArmed = True

-- ***************
-- GPS Calculation
-- ***************

-- Calculated data
local  heading_from, heading_to, distance_2D = 0, 0, 0

-- Working variables
local z1, z2
local pilotLat, sin_pilotLat, cos_pilotLat
local currLat, sin_currLat, cos_currlat
local cos_currLon_pilotLon

local function gpsCalculation()
	if homeSet == 0 then
		heading_from = 0
		heading_to   = 0
		distance_2D  = 0
	else
		pilotLat     = math.rad(homeLatitude)
		sin_pilotLat = math.sin(pilotLat)
		cos_pilotLat = math.cos(pilotLat)
    
		currLat     = math.rad(latitude)
		sin_currLat = math.sin(currLat)
		cos_currlat = math.cos(currLat)
    
		cos_currLon_pilotLon = math.cos(math.rad(longitude - homeLongitude))

		-- Heading_from & heading_to calculation
		z1 = math.sin(math.rad(longitude - homeLongitude)) * cos_currlat
		z2 = cos_pilotLat * sin_currLat - sin_pilotLat * cos_currlat * cos_currLon_pilotLon
		heading_from = (math.deg(math.atan2(z1, z2))) % 360
		heading_to = (heading_from - 180) % 360

		-- Distance_2D calculation (Spherical Law of Cosines)
		distance_2D = 6371009 * math.acos(sin_pilotLat * sin_currLat + cos_pilotLat * cos_currlat * cos_currLon_pilotLon)
	end
end

local colAH  = 54
local rowAH  = 31
local radAH  = 22
local pitchR = radAH / 25
local attAH  = FORCE + GREY(3)
local attBox = FORCE + GREY(3)

local colAlt   = colAH + 31
local colSpeed = colAH - 31

local colHeading  = colAH
local rowHeading  = rowAH - radAH
local rowDistance = rowAH + radAH + 3

local homeShape = {
	{ 0, -5, -4,  4},
	{-4,  4,  0,  2},
	{ 0,  2,  4,  4},
	{ 4,  4,  0, -5}
}

-- ***********************
-- Draw artificial horizon
-- ***********************

local tanRoll, cosRoll, sinRoll
local dPitch_1, dPitch_2, mapRatio

local function drawHorizon()
	dPitch_1 = pitch % 180

	if dPitch_1 > 90 then 
		dPitch_1 = 180 - dPitch_1 
	end

	cosRoll = math.cos(math.rad(roll == 90 and 89.99 or (roll == 270 and 269.99 or roll)))

	if pitch > 270 then
		dPitch_1 = -dPitch_1 * pitchR / cosRoll
		dPitch_2 = radAH / cosRoll
	elseif pitch > 180 then
		dPitch_1 = dPitch_1 * pitchR / cosRoll
		dPitch_2 = -radAH / cosRoll
	elseif pitch > 90 then
		dPitch_1 = -dPitch_1 * pitchR / cosRoll
		dPitch_2 = -radAH / cosRoll
	else
		dPitch_1 = dPitch_1 * pitchR / cosRoll
		dPitch_2 = radAH / cosRoll
	end
  
	tanRoll = -math.tan(math.rad(roll == 90 and 89.99 or (roll == 270 and 269.99 or roll)))
  
	for i = -radAH, radAH, 1 do
		YH = i * tanRoll
		Y1 = YH + dPitch_1

		if Y1 > radAH then
			Y1 = radAH
		elseif Y1 < -radAH then
			Y1 = -radAH
		end
    
		Y2 = YH + 1.5 * dPitch_2

		if Y2 > radAH then
			Y2 = radAH 
		elseif Y2 < -radAH then
			Y2 = -radAH
		end

		X1 = colAH + i

		if Y1 < Y2 then
			lcd.drawLine(X1, rowAH + Y1, X1, rowAH + Y2, SOLID, attAH)
		elseif Y1 > Y2 then
			lcd.drawLine(X1, rowAH + Y2, X1, rowAH + Y1, SOLID, attAH)
		end
	end

	lcd.drawLine(colAH - radAH - 1, rowAH - radAH - 1, colAH - radAH - 1, rowAH + radAH + 1, SOLID, attBox)
	lcd.drawLine(colAH + radAH + 1, rowAH - radAH - 1, colAH + radAH + 1, rowAH + radAH + 1, SOLID, attBox)
	lcd.drawLine(colAH - radAH - 1, rowAH + radAH + 1, colAH + radAH + 1, rowAH + radAH + 1, SOLID, attBox)
end

-- **************************
-- Draw pitch line indication
-- **************************

local function drawPitch()
	sinRoll = math.sin(math.rad(-roll))
	cosRoll = math.cos(math.rad(-roll))
  
	delta = pitch % 15
  
	for i =  delta - 30 , 30 + delta, 15 do
		XH = pitch == i % 360 and 23 or 13
		YH = pitchR * i

		X1 = -XH * cosRoll - YH * sinRoll
		Y1 = -XH * sinRoll + YH * cosRoll
		X2 = (XH - 2) * cosRoll - YH * sinRoll
		Y2 = (XH - 2) * sinRoll + YH * cosRoll

		if not ( -- test if not out of the box
		        (X1 < -radAH and X2 < -radAH)   -- The line is to far left
		     or (X1 >  radAH and X2 >  radAH)   -- The line is to far right
		     or (Y1 < -radAH and Y2 < -radAH)   -- The line is to high
		     or (Y1 >  radAH and Y2 >  radAH)   -- The line is to low
		        ) then  -- Adjusts X and Y not to get out of the frame (it's a little better, improve)

			mapRatio = (Y2 - Y1) / (X2 - X1)

			if X1 < -radAH then  
				Y1 = (-radAH - X1) * mapRatio + Y1 
				X1 = -radAH 
			end
			
			if X2 < -radAH then  
				Y2 = (-radAH - X1) * mapRatio + Y1 
				X2 = -radAH 
			end
			
			if X1 > radAH then  
				Y1 = (radAH - X1) * mapRatio + Y1 
				X1 = radAH 
			end
			
			if X2 > radAH then  
				Y2 = (radAH - X1) * mapRatio + Y1 
				X2 = radAH 
			end

			mapRatio = 1 / mapRatio

			if Y1 < -radAH then  
				X1 = (-radAH - Y1) * mapRatio + X1 
				Y1 = -radAH 
			end
			
			if Y2 < -radAH then  
				X2 = (-radAH - Y1) * mapRatio + X1 
				Y2 = -radAH 
			end
			
			if Y1 > radAH then  
				X1 = (radAH - Y1) * mapRatio + X1 
				Y1 = radAH 
			end
			
			if Y2 > radAH then  
				X2 = (radAH - Y1) * mapRatio + X1 
				Y2 = radAH 
			end

			lcd.drawLine(colAH + X1, rowAH + Y1, colAH + X2, rowAH + Y2, SOLID, FORCE)
		end
	end
end

-- **********************
-- Draw heading indicator
-- **********************

local parmHeading = {
	{  0, 2, "N"}, { 30, 5}, { 60, 5},
	{ 90, 2, "E"}, {120, 5}, {150, 5},
	{180, 2, "S"}, {210, 5}, {240, 5},
	{270, 2, "W"}, {300, 5}, {330, 5}
}

local wrkHeading = 0

local function drawHeading()
	lcd.drawLine(colHeading - 34, rowHeading, colHeading + 34, rowHeading, SOLID, FORCE)
  
	for index, point in pairs(parmHeading) do
		wrkHeading = point[1] - yaw

		if wrkHeading >  180 then 
			wrkHeading = wrkHeading - 360 
		end

		if wrkHeading < -180 then 
			wrkHeading = wrkHeading + 360 
		end

		delatX = (wrkHeading / 3.3) - 1

		if delatX >= -31 and delatX <= 31 then
			if point[3] then
				lcd.drawText(colHeading + delatX - 1, rowHeading - 8, point[3], SMLSIZE + BOLD)
			end

			if point[2] > 0 then
				lcd.drawLine(colHeading + delatX, rowHeading - point[2], colHeading + delatX, rowHeading, SOLID, FORCE)
			end

		end
	end

	lcd.drawFilledRectangle(colHeading - 34, rowHeading - 9, 3, 10, ERASE)
	lcd.drawFilledRectangle(colHeading + 32, rowHeading - 9, 3, 10, ERASE)

	lcd.drawFilledRectangle(colHeading -8, 1, 16, 8, ERASE)

	lcd.drawLine(colHeading - 9, 0, colHeading - 9, 8, SOLID, FORCE)
	lcd.drawLine(colHeading + 8, 0, colHeading + 8, 8, SOLID, FORCE)

	local heading10  = yaw % 100
	local heading100 = (yaw - heading10) / 100
  
	local heading1 = yaw % 10
  
	heading10 = (heading10 - heading1) / 10

	lcd.drawNumber(colHeading - 7,   2, heading100, LEFT+SMLSIZE)
	lcd.drawNumber(lcd.getLastPos(), 2, heading10,  LEFT+SMLSIZE)
	lcd.drawNumber(lcd.getLastPos(), 2, heading1,   LEFT+SMLSIZE)
end

local function drawDistance()
	deltaX = (distance_2D < 10 and 6) or (distance_2D < 100 and 8 or (distance_2D < 1000 and 10 or 12))
	lcd.drawNumber(colAH + 3 - deltaX, rowAH + 10 , distance_2D, LEFT+SMLSIZE+INVERS)
	lcd.drawText(lcd.getLastPos(), rowAH + 10, "m", SMLSIZE+INVERS)
	drawShape(colAH, rowAH, homeShape, math.rad(heading_to - heading + 180))
end

local function drawMode()
	if not isArmed then
		lcd.drawText(colAH - 19, rowAH - 20, "DISARMED", SMLSIZE+INVERS)
	end

	lcd.drawText(colAH - 8, rowAH + 25, modeString, SMLSIZE)  
end

-- *****************************************************
-- Vertical line parameters (to improve or even supress)
-- *****************************************************

local parmLine = {
	{rowAH - 36, 5,  30},  -- +30
	{rowAH - 30, 3},       -- +25
	{rowAH - 24, 5,  20},  -- +20
	{rowAH - 18, 3},       -- +15
	{rowAH - 12, 5,  10},  -- +10
	{rowAH -  6, 3},       --  +5
	{rowAH,   5, 0},       --   0
	{rowAH +  6, 3},       --  -5
	{rowAH + 12, 5, -10},  -- -10
	{rowAH + 18, 3},       -- -15
	{rowAH + 24, 5, -20},  -- -20
	{rowAH + 30, 3},       -- -25
	{rowAH + 36, 5, -30}   -- -30
}

-- ***********************
-- Draw altitude indicator
-- ***********************

local function drawAltitude()
	delta = altitude % 10
	deltaY = 1 + (1.2 * delta)
  
	lcd.drawLine(colAlt, -1, colAlt, 64, SOLID, FORCE)
  
	for index, line in pairs(parmLine) do
		lcd.drawLine(colAlt - line[2] - 1, line[1] + deltaY, colAlt - 1, line[1] + deltaY, SOLID, FORCE)

		if line[3] then
			lcd.drawNumber(colAlt + 4, line[1] + deltaY - 3, altitude + line[3] - delta, LEFT+SMLSIZE)
		end
	end

	lcd.drawFilledRectangle(colAlt - 5, 0,  5, 10, ERASE)
	lcd.drawFilledRectangle(colAlt + 1, 0, 18,  9, ERASE)

	lcd.drawNumber(colAlt + 4, 1 + rowAH - 3, altitude, LEFT+SMLSIZE+INVERS)
	lcd.drawText(colAlt + 5, 1, "m", SMLSIZE+FIXEDWIDTH)
end


-- ********************
-- Draw speed indicator
-- ********************

local function drawSpeed()
	delta = speed % 10
	deltaY = 1 + (1.2 * delta)

	lcd.drawLine(colSpeed, -1, colSpeed, 64, SOLID, FORCE)

	for index, line in pairs(parmLine) do
		lcd.drawLine(colSpeed, line[1] + deltaY, colSpeed + line[2], line[1] + deltaY, SOLID, FORCE)
		
		if line[3] then
			lcd.drawNumber(colSpeed - 3, line[1] + deltaY - 3, speed + line[3] - delta, SMLSIZE)
		end
	end

	lcd.drawFilledRectangle(colSpeed +  1, 0,  5, 10, ERASE)
	lcd.drawFilledRectangle(colSpeed - 18, 0, 18,  9, ERASE)

	lcd.drawNumber(colSpeed - 3, 1 + rowAH - 3, speed, SMLSIZE+INVERS)
	lcd.drawText(colSpeed - 20, 1, "kts", SMLSIZE+FIXEDWIDTH)
end

-- ***************
-- Draw radar area
-- ***************

local colRadar, rowRadar = 134, 27

--local radarShape1 = {
--	{-4, 5, 0, -4},
--	{-3, 5, 0, -3},
--	{3, 5, 0, -3},
--	{4, 5, 0, -4}
--}

local radarShape2 = {
	{-3, 3, 0, -3},
	{-2, 3, 0, -2},
	{ 2, 3, 0, -2},
	{ 3, 3, 0, -3}
}

local wrkDistance, radTmp

local function drawRadar()
	local direction     = getValue("s2") * 180 / 1024
	local directionRads = math.rad(direction)
	local cosDirection  = math.cos(directionRads)
	local sinDirection  = math.sin(directionRads)

	lcd.drawText(colRadar - 2, rowRadar - 4 ,"o" ,0)     

	drawEllipse(colRadar, rowRadar, 24, 24)

	local iCosDirection
	local iSinDirection
  
	for i=7, 24, 4 do
		iCosDirection = i * cosDirection
		iSinDirection = i * sinDirection
	
		lcd.drawPoint(colRadar + iCosDirection, rowRadar - iSinDirection)
		lcd.drawPoint(colRadar - iCosDirection, rowRadar + iSinDirection)
	
		lcd.drawPoint(colRadar + iSinDirection, rowRadar + iCosDirection)
		lcd.drawPoint(colRadar - iSinDirection, rowRadar - iCosDirection) 
	end

	lcd.drawText(colRadar - (24 * sinDirection) - 1, rowRadar - (24 * cosDirection) - 3, "N", SMLSIZE)

	local distanceRange = 0
	local firstRange = 100
  
	for i=0,10,1 do
		distanceRange = 2 ^ i * firstRange
		wrkDistance = -distance_2D / distanceRange * 28

		if distance_2D < distanceRange then
			if i > 0 then
				drawEllipse(colRadar, rowRadar, 12, 12)
			end
			break
		end
	end

	radTmp = math.rad(direction - heading_from)
	drawShape(colRadar + wrkDistance * math.sin(radTmp), rowRadar + wrkDistance * math.cos(radTmp), radarShape2, math.rad(heading - direction))

	deltaX = (distanceRange < 10 and 6) or (distanceRange < 100 and 8 or (distanceRange < 1000 and 10 or 12))
	lcd.drawNumber(colRadar + 3 - deltaX, rowDistance , distanceRange, LEFT+SMLSIZE)
	lcd.drawText(lcd.getLastPos(), rowDistance, "m", SMLSIZE)

	lcd.drawText(colRadar - 17, rowRadar + 5, gpsString, SMLSIZE+INVERS)
end

-- ***************************
-- Draw textual telemetry data
-- ***************************

local textualRow = 164

local function drawTextualTelemetry()
	-- VDOP / HDOP
	local y = 0
  
	lcd.drawText(textualRow, y, "HDP:", SMLSIZE)

	if hdop > 250 then
		lcd.drawText(lcd.getLastPos(), y, "xxxx", SMLSIZE)
	else
		lcd.drawNumber(lcd.getLastPos(), y, hdop, SMLSIZE+PREC2+LEFT)
	end

	y = y + 8
	lcd.drawText(textualRow, y, "VDP:", SMLSIZE)
	
	if vdop > 250 then
		lcd.drawText(lcd.getLastPos(), y, "xxxx", SMLSIZE)
	else
		lcd.drawNumber(lcd.getLastPos(), y, vdop, SMLSIZE+PREC2+LEFT)
	end

	y = y + 8
	lcd.drawText(textualRow, y, "SAT:", SMLSIZE)
	lcd.drawNumber(lcd.getLastPos(), y, sats, SMLSIZE+LEFT)
  
	y = y + 8
	lcd.drawNumber(textualRow + 3, y, cellVoltage * 100, PREC2+LEFT+MIDSIZE)
	lcd.drawText(lcd.getLastPos(), y, "V", MIDSIZE)

	y = y + 13
	lcd.drawNumber(textualRow + 0, y, rssi, LEFT+MIDSIZE)
	lcd.drawText(lcd.getLastPos(), y + 2, "RSSI", SMLSIZE)

	y = y + 13

	local arrowSymbol = (verticalSpeed > 0 and "\192") or "\193"

	lcd.drawText(textualRow - 5, y + 2, arrowSymbol, SMLSIZE)
	lcd.drawNumber(lcd.getLastPos() + 3, y, math.abs(verticalSpeed), PREC2+LEFT+MIDSIZE)
	lcd.drawText(lcd.getLastPos(), y + 2, "m/s", SMLSIZE)

end

-- *************
-- Main function
-- *************

local function getTelemetryValues()
	altitude      =  getValue("altitude")
	cellVoltage   =  getValue("vfas")
	heading       =  getValue("heading")
	latitude      =  getValue("latitude")
	longitude     =  getValue("longitude")
	roll          =  getValue("accx") * 10
	pitch         =  getValue("accy") * 10
	yaw           =  getValue("accz") * 10
	rssi          =  getValue("rssi")
	speed         =  getValue("gps-speed")
	verticalSpeed =  getValue("vertical-speed")
	
	if pitch < 0 then 
		pitch = 360 + pitch 
	end 
	
	if yaw < 0 then 
		yaw = 360 + yaw 
	end 
	
	local gprc = getValue("temp2")
	
	if gprc < 0 then
		gprc = gprc + 65536
	end
	
	hdop = math.fmod(gprc, 256)
	vdop = (gprc - hdop) / 256

	local gpss = getValue("temp1")

	sats = gpss % 100

	if gpss >= 500 then 
	  gpsString = ""
	elseif gpss >= 400 and gpss < 500 then
	  gpsString = "3D  Fix"
	elseif gpss >= 300 and gpss < 400 then
	  gpsString = "2D  Fix"
	elseif gpss >= 200 and gpss < 300 then
	  gpsString = "No  Fix"
	elseif gpss >= 100 and gpss < 200 then
	  gpsString = "No  GPS"
    else
      gpsString = "-------"
    end

	if (prevGpss < 500 and gpss >=500) or (gpss >= 500 and firstPass) then
		homeSet = 1
		gpsString = ""
		homeLatitude  = latitude
		homeLongitude = longitude
	end
	
	if firstPass == 1 then
		firstPass = 0
	end
	
	prevGpss = gpss

	local mode = getValue("rpm")

	if mode >= 100 and mode < 200 then isArmed = false else isArmed = true end

	local modeNumber = mode % 100

	if(mode % 100) ==  0 then 
		modeString = "Man"
	elseif modeNumber ==  1 then 
		modeString = "Acro"
	elseif modeNumber ==  2 then 
		modeString = "Lvl"
	elseif modeNumber ==  3 then 
		modeString = "Horz"
	elseif modeNumber ==  4 then 
		modeString = "Axis"
	elseif modeNumber ==  5 then 
		modeString = "Vbr"
	elseif modeNumber ==  6 then 
		modeString = "Stb1"
	elseif modeNumber ==  7 then 
		modeString = "Stb2"
	elseif modeNumber ==  8 then 
		modeString = "Stb3"
	elseif modeNumber ==  9 then 
		modeString = "Atune"
	elseif modeNumber == 10 then 
		modeString = "AltH"
	elseif modeNumber == 11 then 
		modeString = "PosH"
	elseif modeNumber == 12 then 
		modeString = "Rth"
	elseif modeNumber == 13 then 
		modeString = "Path"
	elseif modeNumber == 14 then 
		modeString = "Tctl"
	elseif modeNumber == 15 then 
		modeString = "APlus"
	elseif modeNumber == 16 then 
		modeString = "Ttune"
	elseif modeNumber == 17 then 
		modeString = "Fail"
	else
		modeString = "-----"
	end
end

local function runTask()
	getTelemetryValues()

	if rssi < 0 then
		rssi = 0
	elseif rssi > 100 then
		rssi = 100
	end

	if rssi > 35 then
		gpsCalculation()

		drawAltitude()
		drawSpeed()
		drawHeading()
		drawPitch()
		drawDistance()  
		drawHorizon()
		drawMode()
		drawRadar()
		drawTextualTelemetry()
	else
		lcd.drawText(32, 25, "No Connection...", BLINK+DBLSIZE)
	end
end

return {run=runTask}