version_num="0.0.8"
imgScale=480/1024
diffNames={"Easy","Medium","Hard","Expert"}
movequant=10
quants={1/32,1/24,1/16,1/12,1/8,1/6,1/4,1/3,1/2,1,2,4}
--highway rendering vars
midiHash=""
beatHash=""
eventsHash=""
trackSpeed=2
inst=1
diff=4
guitarSoloP = 103
trillP = 127
curOdPhrase = 0
beatLineTimes = false
pR={
	{{60,64},{66,69}},
	{{72,76},{78,81}},
	{{84,88},{90,93}},
	{{96,100},{102,106}}
} --pitch ranges {{notes},{lift markers}} for each difficulty
plasticEventRanges = {
	{{66, 67}},
	{{77,78}},
	{{89,90}},
	{{101,102}}
	-- hopo force 101, strum force 102, solo 103
}

toms = {
	-- yellow, blue, green
	110, 111, 112
}
notes_that_apply_as_tom_markable = {
	{2,3,4},
	{2,3,4},
	{2, 3,4},
	{2,3,4}
}

oP=116 --overdrive pitch
offset=0
notes={}
od_phrases = {}
solo_markers = {}
trills = {}
beatLines={}
eventsData={}
trackRange={0,0}
curTime=0
curTimeLine=1
curEvent=1
curNote=1
nxoff=152 --x offset
nxm=0.05 --x mult of offset
nyoff=192 --y offset
nsm=0.05 --scale multiplier

options = {
	{'Pro Colors for all Parts', true, 'toggle', true},
	{'Enhanced Invalid Chords', true, 'toggle', true},
	{'Enhanced Invalid Chords Thresh', 30, 'stepper', 0, 1, 1},
	{'Invalid Taps Detection', true, 'toggle', true},
	{'Drum Line Pixel Height', 5, 'stepper', 0, 1, 1},
	{'HOPO Ticks Threshold', 170, 'stepper', 0, 1, 1},
	{'Overdrive Lines Pixel Width', 5, 'stepper', 0, 0, 1},
	{'Track Speed', 2.00, 'stepper', 0, 0.25, 0.25},
	{'Offset', 0, 'stepper', 0, -10, 0.01},
	{'Show Beat Line Times', true, 'toggle', true},
	{'Minify UI', false, 'toggle', false}
}
option_curselected = 1

proColorsForAllParts = options[1][2]
enhancedInvalidChords = options[2][2]
enhancedInvalidChordsThresh = options[3][2]
checkForInvalidChords = options[4][2]
checkForExtendedSustains = options[4][2]
pixelsDrumline = options[5][2]
hopothresh = options[6][2] -- ticks
pixelsOdLines = options[7][2]

minifyui = options[11][2]

lastCursorTime=reaper.GetCursorPosition()

showHelp=false

local function rgb2num(r, g, b)
	g = g * 256
	b = b * 256 * 256
	return r + g + b
end

function toFractionString(number)
	if number<1 then
		return string.format('1/%d', math.floor(1/number))
	else
		return string.format('%d',number)
	end
end

function getNoteIndex(time, lane)
	for i, note in ipairs(notes) do
		if note[1] == time and note[3] == lane then
			return i
		end
	end
	return -1
end

function anyOtherAtTime(time)
	for i, note in ipairs(notes) do
		if note[1] == time then
			return i
		end
	end
	return -1
end

function previousNote(take, index, minpitch, maxpitch)
	local _, _, _, lastspos, lastepos, _, lastpitch, _ = reaper.MIDI_GetNote(take, index - 1)
	while lastpitch < minpitch or lastpitch > maxpitch do
	  	index = index - 1
	  	if index < 1 then
			return nil
	  	end
	  	_, _, _, lastspos, lastepos, _, lastpitch, _ = reaper.MIDI_GetNote(take, index - 1)
	end
	return {lastspos, lastepos, lastpitch}
end

function contains(table, element)
	for _, value in pairs(table) do
	  	if value == element then
			return true
	  	end
	end
	return false
end

function findTrack(trackName)
	local numTracks = reaper.CountTracks(0)
	for i = 0, numTracks - 1 do
		local track = reaper.GetTrack(0, i)
		local _, currentTrackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if currentTrackName == trackName then
			return track
		end
	end
	return nil
end

function breakTime()
	if #notes > 2 and curNote > 1 then
		return (notes[curNote][10] - notes[curNote - 1][11]) / 4
	elseif #notes > 0 then
		return notes[1][10] -- break at the start
	end
	return 0
end

gfx.clear = rgb2num(42, 0, 71)
gfx.init("FNFest Preview", 640, 480, 0, 200, 200)




local script_folder = string.gsub(debug.getinfo(1).source:match("@?(.*[\\|/])"),"\\","/")
hwy_emh = gfx.loadimg(0,script_folder.."assets/hwy_emh.png")
hwy_x = gfx.loadimg(1,script_folder.."assets/hwy_x.png")

-- normal purple note
note = gfx.loadimg(2,script_folder.."assets/note.png")
note_o = gfx.loadimg(3,script_folder.."assets/note_o.png")
note_invalid = gfx.loadimg(7,script_folder.."assets/note_invalid.png")

lift = gfx.loadimg(4,script_folder.."assets/lift.png")
lift_o = gfx.loadimg(5,script_folder.."assets/lift_o.png")
lift_invalid = gfx.loadimg(6,script_folder.."assets/lift_invalid.png")

hopo = gfx.loadimg(8,script_folder.."assets/hopo.png") -- do not use
hopo_o = gfx.loadimg(9,script_folder.."assets/hopo_o.png")
hopo_invalid = gfx.loadimg(10,script_folder.."assets/hopo_invalid.png")

note_green = gfx.loadimg(11,script_folder.."assets/note_pgre.png")
note_red = gfx.loadimg(12,script_folder.."assets/note_pred.png")
note_yellow = gfx.loadimg(13,script_folder.."assets/note_pyel.png")
note_blue = gfx.loadimg(14,script_folder.."assets/note_pblu.png")
note_orange = gfx.loadimg(15,script_folder.."assets/note_pora.png")

hopo_green = gfx.loadimg(16,script_folder.."assets/hopo_green.png")
hopo_red = gfx.loadimg(17,script_folder.."assets/hopo_red.png")
hopo_yellow = gfx.loadimg(18,script_folder.."assets/hopo_yellow.png")
hopo_blue = gfx.loadimg(19,script_folder.."assets/hopo_blue.png")
hopo_orange = gfx.loadimg(20,script_folder.."assets/hopo_orange.png")

drum_line = gfx.loadimg(21,script_folder.."assets/drums_line.png")

tom_yellow = gfx.loadimg(22,script_folder.."assets/note_dtomyel.png")
tom_blue = gfx.loadimg(23,script_folder.."assets/note_dtomblu.png")
tom_green = gfx.loadimg(24,script_folder.."assets/note_dtomgre.png")
tom_o = gfx.loadimg(25,script_folder.."assets/note_tom_o.png")
tom_invalid = gfx.loadimg(26,script_folder.."assets/tom_invalid.png")

cymbal_yellow = gfx.loadimg(27,script_folder.."assets/note_dcymyel.png")
cymbal_blue = gfx.loadimg(28,script_folder.."assets/note_dcymblu.png")
cymbal_green = gfx.loadimg(29,script_folder.."assets/note_dcymgre.png")
cymbal_o = gfx.loadimg(30,script_folder.."assets/cym_o.png")
cymbal_invalid = gfx.loadimg(31,script_folder.."assets/cym_invalid.png")

lift_green = gfx.loadimg(32,script_folder.."assets/lift_green.png")
lift_red = gfx.loadimg(33,script_folder.."assets/lift_red.png")
lift_yellow = gfx.loadimg(34,script_folder.."assets/lift_yellow.png")
lift_blue = gfx.loadimg(35,script_folder.."assets/lift_blue.png")
lift_orange = gfx.loadimg(36,script_folder.."assets/lift_orange.png")

toggleswitch_on = gfx.loadimg(37,script_folder.."assets/toggle/on.png")
toggleswitch_off = gfx.loadimg(38,script_folder.."assets/toggle/off.png")
toggleswitch_selected = gfx.loadimg(39,script_folder.."assets/toggle/selected.png")

stepper = gfx.loadimg(40,script_folder.."assets/toggle/stepper.png")
stepper_left = gfx.loadimg(41,script_folder.."assets/toggle/left.png")
stepper_right = gfx.loadimg(43,script_folder.."assets/toggle/right.png")
stepper_left_s = gfx.loadimg(42,script_folder.."assets/toggle/left_selected.png")
stepper_right_s = gfx.loadimg(44,script_folder.."assets/toggle/right_selected.png")
stepper_selected = gfx.loadimg(45,script_folder.."assets/toggle/stepper_selected.png")

keybind1 = gfx.loadimg(46,script_folder.."assets/toggle/brackets.png")
keybind2 = gfx.loadimg(47,script_folder.."assets/toggle/quotes.png")
keybind3 = gfx.loadimg(48,script_folder.."assets/toggle/arrows.png")
keybind4 = gfx.loadimg(49,script_folder.."assets/toggle/arrows_ud.png")
keybind5 = gfx.loadimg(50,script_folder.."assets/toggle/eight_five.png")
keybind7 = gfx.loadimg(52,script_folder.."assets/toggle/enter.png")
keybind8 = gfx.loadimg(53,script_folder.."assets/toggle/f1.png")
keybind6 = gfx.loadimg(51,script_folder.."assets/toggle/four_siz.png")

instrumentTracks={
	{"Drums",findTrack("PART DRUMS")},
	{"Bass",findTrack("PART BASS")},
	{"Guitar",findTrack("PART GUITAR")},
	{"Vocals",findTrack("PART VOCALS")},
	{"Plastic Drums",findTrack("PLASTIC DRUMS")},
	{"Plastic Bass", findTrack("PLASTIC BASS")},
	{"Plastic Guitar", findTrack("PLASTIC GUITAR")}
}

eventTracks={
	findTrack("EVENTS"),
	findTrack("BEAT")
}
local function notesCompare(a, b)
    if a[1] < b[1] then
        return true
    elseif a[1] > b[1] then
        return false
    else
        return a[3] < b[3]
    end
end
local function notesCompareFlip(a, b)
    if a[1] < b[1] then
        return true
    elseif a[1] > b[1] then
        return false
    else
        return a[3] > b[3]
    end
end
function parseNotes(take)
	notes = {}
	od_phrases={}
	hopo_forces = {}
	strum_forces = {}

	solo_markers = {}
	trills = {}

	od=false
	cur_od_phrase=1
	cur_hopo_force = 1
	cur_strum_force = 1

	_, notecount = reaper.MIDI_CountEvts(take)

	tom_yellow_forces = {}
	cur_tom_yellow_force = 1

	tom_blue_forces = {}
	cur_tom_blue_force = 1

	tom_green_forces = {}
	cur_tom_green_force = 1

	isplastic = inst >= 5
	isriffmaster = inst >= 6

	for i = 0, notecount - 1 do
		_, _, _, spos, epos, _, pitch, _ = reaper.MIDI_GetNote(take, i)
		ntime = reaper.MIDI_GetProjTimeFromPPQPos(take, spos)
		nend = reaper.MIDI_GetProjTimeFromPPQPos(take, epos)
		ntimebeats = reaper.MIDI_GetProjQNFromPPQPos(take, spos)
		nendbeats = reaper.MIDI_GetProjQNFromPPQPos(take, epos)
		if pitch == oP then
			table.insert(od_phrases, {ntime,nend})
		elseif pitch >= pR[diff][1][1] and pitch <= pR[diff][1][2] then
			valid=true
			hopo = false
			lane = pitch - pR[diff][1][1]

			if i > 1 and not isplastic and enhancedInvalidChords then -- sub invalid chord detection
				local prevNote = previousNote(take, i, pR[diff][1][1], pR[diff][1][2])

				if prevNote ~= nil then
					if (contains({0, 1}, prevNote[3] - pR[diff][1][1]) and contains({0, 1}, lane)) 
					or (contains({2, 3, 4}, prevNote[3] - pR[diff][1][1]) and contains({2, 3, 4}, lane)) then
						if spos - prevNote[1] < enhancedInvalidChordsThresh then -- ticks
							valid = false
						end
					end
				end
			end

			noteIndex = getNoteIndex(ntime, lane)
			if noteIndex ~= -1 then
				if nendbeats-ntimebeats<0.33 and notes[noteIndex][2]==nend-ntime then
					notes[noteIndex][6] = valid
				end
			else
				-- hopo logic
				if i > 1 and isriffmaster then
					previousnote = previousNote(take, i, pR[diff][1][1], pR[diff][1][2])
					
					if previousnote ~= nil then
						lastspos = previousnote[1]
						lastepos = previousnote[2]
						lastpitch = previousnote[3]
						-- hopo threshold
	
						ischord = anyOtherAtTime(ntime) ~= -1
	
						if lastpitch >= pR[diff][1][1] and lastpitch <= pR[diff][1][2] then
							if lastpitch ~= pitch and not ischord then
								if spos - lastspos <= hopothresh then
									hopo = true
								end
							end
						end
					end
				end

				-- check again for chords
				otherAtTime = anyOtherAtTime(ntime)
				if otherAtTime ~= -1 then
					notes[otherAtTime][8] = hopo
				end

				-- hopo, tom
				table.insert(notes, { ntime, nend - ntime, lane, false, false, valid , nendbeats- ntimebeats, hopo, false, ntimebeats, nendbeats}) 
			end
		elseif pitch >= pR[diff][2][1] and pitch <= pR[diff][2][2] and not isplastic then
			lane = pitch - pR[diff][2][1]
			noteIndex = getNoteIndex(ntime, lane)
			if noteIndex ~= -1 then
				notes[noteIndex][4] = true
				if nendbeats-ntimebeats>0.33 or notes[noteIndex][2]~=nend-ntime then
					notes[noteIndex][6] = false
				end
			else -- lifts cant be hopos or toms
				table.insert(notes, { ntime, nend - ntime, lane, true, false, false, nendbeats- ntimebeats, false, false, ntimebeats, nendbeats})
			end
		elseif pitch == plasticEventRanges[diff][1][1] and isplastic then -- hopo force
			table.insert(hopo_forces, {ntime, nend})
		elseif pitch == plasticEventRanges[diff][1][2] and isplastic then -- strum force
			table.insert(strum_forces, {ntime, nend})
		elseif pitch == toms[1] and isplastic then -- TOM YELLOW
			table.insert(tom_yellow_forces, {ntime, nend})
		elseif pitch == toms[2] and isplastic then -- TOM BLUE
			table.insert(tom_blue_forces, {ntime, nend})
		elseif pitch == toms[3] and isplastic then -- TOM GREEN
			table.insert(tom_green_forces, {ntime, nend})
		elseif pitch == guitarSoloP and isriffmaster then -- solo marker
			table.insert(solo_markers, {ntime, nend})
		elseif pitch == trillP and isriffmaster then
			table.insert(trills, {ntime, nend})
		end
	end
	if #od_phrases~=0 then
		for i=1,#notes do
			if notes[i][1]>od_phrases[cur_od_phrase][2] then
				if cur_od_phrase<#od_phrases then cur_od_phrase=cur_od_phrase+1 end
			end
			if notes[i][1]>=od_phrases[cur_od_phrase][1] and notes[i][1]<od_phrases[cur_od_phrase][2] then
				notes[i][5]=true
			end
		end
	end

	if isplastic then
		if #hopo_forces ~= 0 then
			for i=1,#notes do
				if notes[i][1]>hopo_forces[cur_hopo_force][2] then
					if cur_hopo_force<#hopo_forces then cur_hopo_force=cur_hopo_force+1 end
				end
				if notes[i][1]>=hopo_forces[cur_hopo_force][1] and notes[i][1]<hopo_forces[cur_hopo_force][2] then
					notes[i][8]=true
				end
			end
		end
	
		if #strum_forces ~= 0 then
			for i=1,#notes do
				if notes[i][1]>strum_forces[cur_strum_force][2] then
					if cur_strum_force<#strum_forces then cur_strum_force=cur_strum_force+1 end
				end
				if notes[i][1]>=strum_forces[cur_strum_force][1] and notes[i][1]<strum_forces[cur_strum_force][2] then
					notes[i][8]=false -- reset hopo to false
				end
			end
		end
	
		if #tom_yellow_forces ~= 0 then
			for i=1,#notes do
				if notes[i][1] > tom_yellow_forces[cur_tom_yellow_force][2] then if cur_tom_yellow_force < #tom_yellow_forces then cur_tom_yellow_force = cur_tom_yellow_force + 1 end end
				if notes[i][1] >= tom_yellow_forces[cur_tom_yellow_force][1] and notes[i][1] < tom_yellow_forces[cur_tom_yellow_force][2] then
					if notes[i][3] == notes_that_apply_as_tom_markable[diff][1] then
						notes[i][9]=true
					end
				end
			end
		end
	
		if #tom_blue_forces ~= 0 then
			for i=1,#notes do
				if notes[i][1] > tom_blue_forces[cur_tom_blue_force][2] then if cur_tom_blue_force < #tom_blue_forces then cur_tom_blue_force = cur_tom_blue_force + 1 end end
				if notes[i][1] >= tom_blue_forces[cur_tom_blue_force][1] and notes[i][1] < tom_blue_forces[cur_tom_blue_force][2] then
					if notes[i][3] == notes_that_apply_as_tom_markable[diff][2] then
						notes[i][9]=true
					end
				end
			end
		end
	
		if #tom_green_forces ~= 0 then
			for i=1,#notes do
				if notes[i][1] > tom_green_forces[cur_tom_green_force][2] then if cur_tom_green_force < #tom_green_forces then cur_tom_green_force = cur_tom_green_force + 1 end end
				if notes[i][1] >= tom_green_forces[cur_tom_green_force][1] and notes[i][1] < tom_green_forces[cur_tom_green_force][2] then
					if notes[i][3] == notes_that_apply_as_tom_markable[diff][3] then
						notes[i][9]=true
					end
				end
			end
		end
	end

	table.sort(notes,notesCompare)

	--illegal chords check
	if checkForInvalidChords and not isplastic then
		for i=1,#notes do
			ntime=notes[i][1]
			lane=notes[i][3]
			if lane==0 or lane==1 then
				for f = 0,1 do
					invalidIndex = getNoteIndex(ntime, f)
					if invalidIndex~=-1 and f~=lane then
						notes[i][6]=false
						notes[invalidIndex][6]=false
					end
				end
			elseif lane==2 or lane==3 or lane==4 then
				for f = 2,4 do
					invalidIndex = getNoteIndex(ntime, f)
					if invalidIndex~=-1 and f~=lane then
						notes[i][6]=false
						notes[invalidIndex][6]=false
					end
				end
			end
		end
	end
	--extended sustain check
	if checkForExtendedSustains then
		sustain=false
		sustain_idx=-1
		sustain_start=-1
		sustain_end=-1
		for i=1,#notes do
			ntime=notes[i][1]
			if ntime>=sustain_end then 
				sustain=false
				sustain_idx=-1
				sustain_start=-1
				sustain_end=-1
			end
			nlen=notes[i][2]
			nlenbeats=notes[i][7]
			nend=ntime+notes[i][2]
			lane=notes[i][3]
			if sustain==true then
				if ntime<sustain_end then
					if ntime~=sustain_start or nend~=sustain_end then
						notes[i][6]=false
						notes[sustain_idx][6]=false
					end
				end
			else
				if nlenbeats>=0.33 then
					sustain=true
					sustain_start=ntime
					sustain_end=nend
					sustain_idx=i
				end
			end
			
		end
		table.sort(notes,notesCompareFlip)
		sustain=false
		sustain_idx=-1
		sustain_start=-1
		sustain_end=-1
		for i=1,#notes do
			ntime=notes[i][1]
			if ntime>=sustain_end then 
				sustain=false
				sustain_idx=-1
				sustain_start=-1
				sustain_end=-1
			end
			nlen=notes[i][2]
			nlenbeats=notes[i][7]
			nend=ntime+notes[i][2]
			lane=notes[i][3]
			if sustain==true then
				if ntime<sustain_end then
					if ntime~=sustain_start or nend~=sustain_end then
						notes[i][6]=false
						notes[sustain_idx][6]=false
					end
				end
			else
				if nlenbeats>=0.33 then
					sustain=true
					sustain_start=ntime
					sustain_end=nend
					sustain_idx=i
				end
			end
			
		end
	end
	--set all notes at time to invalid if one is
	for i=1,#notes do
		ntime=notes[i][1]
		lane=notes[i][3]
		for f = 0,4 do
			invalidIndex = getNoteIndex(ntime, f)
			if invalidIndex~=-1 then
				if notes[invalidIndex][6]==false then notes[i][6]=false end
			end
		end
	end
	if inst == 5 then
		table.sort(notes, notesCompare) -- sort again, fixes drum line over other notes
	end
end

function updateMidi()
	instrumentTracks={
		{"Drums",findTrack("PART DRUMS")},
		{"Bass",findTrack("PART BASS")},
		{"Guitar",findTrack("PART GUITAR")},
		{"Vocals",findTrack("PART VOCALS")},
		{"Plastic Drums",findTrack("PLASTIC DRUMS")},
		{"Plastic Bass", findTrack("PLASTIC BASS")},
		{"Plastic Guitar", findTrack("PLASTIC GUITAR")}
	}
	if instrumentTracks[inst][2] then
		local numItems = reaper.CountTrackMediaItems(instrumentTracks[inst][2])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(instrumentTracks[inst][2], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,true)
			if midiHash~=hash then
				parseNotes(take)
				curNote=1
				for i=1,#notes do
					curNote=i
					if notes[i][1]+notes[i][2]>=curTime then
						break
					end
					
				end
				midiHash=hash
			end
		end
	else
		midiHash=""
		notes={}
	end
end

function updateEvents()
	eventTracks[1]=findTrack("EVENTS")
	if eventTracks[1] then
		local numItems = reaper.CountTrackMediaItems(eventTracks[1])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(eventTracks[1], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,false)
			if eventsHash~=hash then
				eventsData={}
				_,_,_,textcount = reaper.MIDI_CountEvts(take)
				for i = 0, textcount - 1 do
					_,_,_,epos,etype,msg = reaper.MIDI_GetTextSysexEvt(take, i)
					etime = reaper.MIDI_GetProjTimeFromPPQPos(take, epos)
					if etype==1 then
						table.insert(eventsData,{epos,msg})
						if msg=="[music_start]" then trackRange[1]=etime
						elseif msg=="[end]" then trackRange[2]=etime
						end
					end
				end
				eventsHash=hash
			end
		end
	else
		eventsHash=""
		eventsData={}
	end
end

function updateBeatLines()
	eventTracks[2]=findTrack("BEAT")
	if eventTracks[2] then
		local numItems = reaper.CountTrackMediaItems(eventTracks[2])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(eventTracks[2], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,true)
			if beatHash~=hash then
				beatLines={}
				_, notecount = reaper.MIDI_CountEvts(take)
				for i = 0, notecount - 1 do
					_, _, _, spos, _, _, pitch, _ = reaper.MIDI_GetNote(take, i)
					btime = reaper.MIDI_GetProjTimeFromPPQPos(take, spos)
					db=true
					if pitch==13 then
						db=false
					end
					if btime>=trackRange[1] and btime<trackRange[2] then
						table.insert(beatLines,{btime,db})
					end
				end
				beatHash=hash
			end
		end
	else
		beatHash=""
		beatLines={}
	end
end

function drawNotes()
	isplastic = inst >= 5
	isprodrums = inst == 5
	isexpert = diff == 4
	isriffmaster = inst >= 6
	for i=curNote,#notes do
		invalid=false
		ntime=notes[i][1]
		nlen=notes[i][2]
		nlenbeats=notes[i][7]
		if notes[i][6]==false then
			invalid=true
		end
		lane=notes[i][3]
		notedata=notes[i][3]
		lift=notes[i][4]
		curend=((notes[curNote][1]+notes[curNote][2])-curTime)*(trackSpeed+2)
		od=notes[i][5]
		hopo=notes[i][8]
		tom = notes[i][9]
		if ntime>curTime+(4/(trackSpeed+2)) then break end
		rtime=((ntime-curTime)*(trackSpeed+2))
		rend=(((ntime+nlen)-curTime)*(trackSpeed+2))
		if nlenbeats<=0.27 then
			rend=rtime
		end
		
		if rtime<0 then rtime=0 end
		
		if rend<=0 and curNote~=#notes and curend<=0 then
			curNote=i+1
		end

		if rend>4 then
			rend=4
		end
		
		noteScale=imgScale*(1-(nsm*rtime))
		noteScaleEnd=imgScale*(1-(nsm*rend))
		-- not plastic case
			-- not pro drums case

		startlinex = ((gfx.w/2)-(64*noteScale)+((nxoff*(1-(nxm*rtime)))*noteScale*(0.5-2)))
		endlinex = ((gfx.w/2)-(64*noteScale)+((nxoff*(1-(nxm*rtime)))*noteScale*(3.5-2))) + (128 * noteScale)

		if diff<4 and (not isplastic) or isprodrums then
			if notedata ~= 0 and isprodrums then
				lane = lane-1
			elseif notedata == 0 and isprodrums then
				lane = 0.5
			end
			lane=lane+0.5
		end
		notex=((gfx.w/2)-(64*noteScale)+((nxoff*(1-(nxm*rtime)))*noteScale*(lane-2)))
		notey=gfx.h-(32*noteScale)-(248*noteScale)-((nyoff*rtime)*noteScale)
		susx=((gfx.w/2)+((nxoff*(1-(nxm*rtime)))*noteScale*(lane-2)))
		susy=gfx.h-(248*noteScale)-((nyoff*rtime)*noteScale)
		endx=((gfx.w/2)+((nxoff*(1-(nxm*rend)))*noteScaleEnd*(lane-2)))
		endy=gfx.h-(248*noteScaleEnd)-((nyoff*rend)*noteScaleEnd)
		
		if rend>=-0.05 then
			gfxid=2

			if isplastic or proColorsForAllParts then gfxid = 11 + notedata end

			if notedata == 0 and isprodrums then
				gfxid = 21
				gfx.r, gfx.g, gfx.b=0.78,.63,.16
				if od then
					gfx.r, gfx.g, gfx.b=.53,.6,.77
				end
				drumliney = notey + (36 * noteScale)
				for i = 0, pixelsDrumline do
					gfx.line(startlinex - math.floor(i * 0.3),drumliney + i,endlinex + math.floor(i * 0.3),drumliney + i)
				end
			end

			if notedata == 4 and isprodrums then
				gfxid = 11
			end

			if lift then gfxid= proColorsForAllParts and (32 + notedata) or 4 end 
			if hopo then gfxid = 16 + notedata end

			if isprodrums then
				if notedata == 2 then -- yellow
					gfxid = tom and 22 or 27
				elseif notedata == 3 then -- blue
					gfxid = tom and 23 or 28
				elseif notedata == 4 then -- green
					gfxid = tom and 24 or 29
				end
			--else
				--gfxid= 4
			end

			if od then 
				if not (isplastic or proColorsForAllParts) then
					gfxid=gfxid+1
				else
					-- this is a plastic instrument
					gfxid = 3
					if lift then
						gfxid = 5
					elseif hopo then
						gfxid = 9
					elseif tom then
						gfxid = 25
					elseif isprodrums and notedata > 1 and not tom then
						gfxid = 30
					end
				end
				gfx.r, gfx.g, gfx.b=.53,.6,.77
			else
				-- non overdrive sustain
				-- add plastic case here
				gfx.r, gfx.g, gfx.b=0.72,.3,1

				if isplastic or proColorsForAllParts then
					if notedata == 0 then -- green lane
						gfx.r, gfx.g, gfx.b=0.14,.59,.34
					elseif notedata == 1 then -- red lane
						gfx.r, gfx.g, gfx.b=0.57,0,.16
					elseif notedata == 2 then -- yellow lane
						gfx.r, gfx.g, gfx.b=0.77,.65,.2
					elseif notedata == 3 then -- blue lane
						gfx.r, gfx.g, gfx.b=0.18,.3,.83
					elseif notedata == 4 then -- orange lane
						gfx.r, gfx.g, gfx.b=0.78,.55,.16
						if isprodrums then -- green if pro drums is active, anyway
							gfx.r, gfx.g, gfx.b=0.14,.59,.34
						end
					end
				end
			end
			if od and notedata == 0 and isprodrums then -- ignore overdrive on the first lane pro drums
				gfxid = 21
			end
			-- invalid 5th lane note
			if notedata == 4 and (not isplastic and not isexpert) then invalid = true end
			if invalid then
				gfx.r, gfx.g, gfx.b=1,0,0
			end
			-- draws sustain with the appropiate color
			if rend>rtime then
				gfx.line(susx-1,susy,endx-1,endy)
				gfx.line(susx,susy,endx,endy)
				gfx.line(susx+1,susy,endx+1,endy)
			end
			-- invalid lift
			if invalid and lift then gfxid=6 end
			-- invalid note
			if invalid and not lift then gfxid=7 end
			-- invalid hopo
			if invalid and hopo then gfxid = 10 end	
			-- invalid tom
			if invalid and tom then gfxid = 26 end
			if isprodrums and invalid and notedata > 1 and not tom then
				gfxid = 27 + (notedata - 2)
			end

			-- since it wasnt a sustain reset it back to 1 and draw the image
			gfx.r, gfx.g, gfx.b=1,1,1
			-- also draw a normal note at the start

			widthNote = 128

			gfx.blit(gfxid,noteScale,0,0,0,widthNote,64,notex,notey)
		end
	end

	for i=curOdPhrase,#od_phrases do
		local ntime=od_phrases[i][1]
		local nlen=od_phrases[i][2]-ntime

		if not (ntime+nlen<curTime) then
			if ntime>curTime+(4/(trackSpeed+2)) then break end
			rtime=((ntime-curTime)*(trackSpeed+2))
			rend=(((ntime+nlen)-curTime)*(trackSpeed+2))
			if rtime<0 then rtime=0 end
			if rend>4 then
				rend=4
			end
			lane = -0.75
			if not isexpert then
				lane = 0
			end
			if isriffmaster then
				lane = -0.75
			end
			if isprodrums then
				lane = 0
			end
			
			noteScale=imgScale*(1-(nsm*rtime))
			noteScaleEnd=imgScale*(1-(nsm*rend))
			-- not plastic case
				-- not pro drums case

			notex=((gfx.w/2)-(64*noteScale)+((nxoff*(1-(nxm*rtime)))*noteScale*(lane-2)))
			notey=gfx.h-(32*noteScale)-(248*noteScale)-((nyoff*rtime)*noteScale)
			susx=((gfx.w/2)+((nxoff*(1-(nxm*rtime)))*noteScale*(lane-2)))
			susy=gfx.h-(248*noteScale)-((nyoff*rtime)*noteScale)
			endx=((gfx.w/2)+((nxoff*(1-(nxm*rend)))*noteScaleEnd*(lane-2)))
			endy=gfx.h-(248*noteScaleEnd)-((nyoff*rend)*noteScaleEnd)
			lane = 4.75
			if not isexpert then
				lane = 4
			end
			if isriffmaster then
				lane = 4.75
			end
			if isprodrums then
				lane = 4
			end
			susx2=((gfx.w/2)+((nxoff*(1-(nxm*rtime)))*noteScale*(lane-2)))
			susy2=gfx.h-(248*noteScale)-((nyoff*rtime)*noteScale)
			endx2=((gfx.w/2)+((nxoff*(1-(nxm*rend)))*noteScaleEnd*(lane-2)))
			endy2=gfx.h-(248*noteScaleEnd)-((nyoff*rend)*noteScaleEnd)
			
			if rend>=-0.05 then
				gfx.r, gfx.g, gfx.b=.53,.6,.77
				-- draws sustain with the appropiate color
				for i=0,pixelsOdLines do
					gfx.line(susx+i,susy,endx+i,endy)
					gfx.line(susx2+i,susy2,endx2+i,endy2)
				end

				gfx.r, gfx.g, gfx.b=1,1,1

				gfx.blit(21,noteScale,0,0,0,128,64,notex,notey)
			end
		end
	end
end

function drawBeats()
	width=300
	isplastic = inst >= 5
	isexpert = diff == 4
	isprodrums = inst == 5
	if diff==4 or isplastic then
		if not isprodrums then
			width=425
		end
	end
	for i=curTimeLine,#beatLines do
		btime=beatLines[i][1]
		if btime>curTime+(4/(trackSpeed+2)) then break end
		if curTime>btime+2 then
			curTimeLine=i
		end
		rtime=((btime-curTime)*(trackSpeed+2))-0.08
		beatScale=imgScale*(1-(nsm*rtime))
		
		sx=((gfx.w/2)-((width*(1-(nxm*rtime)))*beatScale))
		ex=((gfx.w/2)+((width*(1-(nxm*rtime)))*beatScale))
		y=gfx.h-(248*beatScale)-((nyoff*rtime)*beatScale)
		gfx.r,gfx.g,gfx.b=0.52,.3,0.55
		gfx.line(sx,y,ex,y)
		if beatLines[i][2] then
			gfx.line(sx+1,y-1,ex-1,y-1)
			gfx.line(sx-1,y+1,ex+1,y+1)
		end
		gfx.r,gfx.g,gfx.b=1,1,1
		if beatLineTimes then
			gfx.setfont(1, "Arial", 15)
			strx,stry = gfx.measurestr(btime)

			gfx.x = sx - (strx + 10)
			gfx.y = y - 7
			gfx.drawstr(btime)
		end
	end
end

function moveCursorByBeats(increment)
    local currentPosition = reaper.GetCursorPosition()
    local currentBeats = reaper.TimeMap2_timeToQN(reaper.EnumProjects(-1), currentPosition)

    -- Calculate the new position in beats
	local newBeats = currentBeats + increment
	newBeats=math.floor(newBeats*(1/quants[movequant])+0.5)/(1/quants[movequant])
	-- Convert the new beats position to seconds
    local newPosition = reaper.TimeMap2_QNToTime(reaper.EnumProjects(-1), newBeats)
    -- Move the edit cursor to the new position
    reaper.SetEditCurPos2(0, newPosition, true, true)
end

updateMidi()
updateEvents()
updateBeatLines()

keyBinds={
	[52]=function()
		if options[option_curselected][3] == 'stepper' and showHelp then
			options[option_curselected][4] = 0
		end
	end,
	[54]=function()
		if options[option_curselected][3] == 'stepper' and showHelp then
			options[option_curselected][4] = 1
		end
	end,
	[53]=function()
		if showHelp then
			option_curselected = option_curselected+1
			if option_curselected>#options then option_curselected = 1 end
		end
	end,
	[56]=function()
		if showHelp then
			option_curselected = option_curselected-1
			if option_curselected<1 then option_curselected = #options end
		end
	end,
	[13]=function()
		curoption = options[option_curselected]
		if curoption[3] == 'toggle' and showHelp then
			options[option_curselected][2] = not options[option_curselected][2]
		elseif curoption[3] == 'stepper' and showHelp then
			if curoption[4] == 1 then
				options[option_curselected][2] = options[option_curselected][2] + options[option_curselected][6]
			else
				options[option_curselected][2] = options[option_curselected][2] - options[option_curselected][6]
				if options[option_curselected][2] < options[option_curselected][5] then
					options[option_curselected][2] = options[option_curselected][5]
				end
			end
		end
	end,
	[59]=function()
		if diff==1 then diff=4 else diff=diff-1 end
		midiHash=""
		updateMidi()
	end,
	[39]=function()
		if diff==4 then diff=1 else diff=diff+1 end
		midiHash=""
		updateMidi()
	end,
	[91]=function()
		if inst==1 then inst=7 else inst=inst-1 end
		midiHash=""
		updateMidi()
	end,
	[93]=function()
		if inst==7 then inst=1 else inst=inst+1 end
		midiHash=""
		updateMidi()
	end,
	[32]=function()
		if reaper.GetPlayState()==1 then
			reaper.OnStopButton()
		else
			reaper.OnPlayButton()
		end
	end,
	[30064]=function()
		moveCursorByBeats(quants[movequant])
	end,
	[1685026670]=function()
		moveCursorByBeats(-quants[movequant])
	end,
	[1818584692.0]=function() 
		if movequant==1 then movequant=#quants else movequant=movequant-1 end
	end,
	[1919379572.0]=function() 
		if movequant==#quants then movequant=1 else movequant=movequant+1 end
	end,
	[26161.0]=function() showHelp = not showHelp end,
	[48] = function()
		hopothresh = hopothresh + 1
		midiHash=""
		updateMidi()
	end,
	[40] = function()
		hopothresh = hopothresh - 10
		midiHash=""
		updateMidi()
	end,
	[57] = function()
		if hopothresh > 1 then hopothresh = hopothresh - 1 end
		midiHash=""
		updateMidi()
	end,
	[41] = function()
		if hopothresh > 1 then hopothresh = hopothresh + 10 end
		if hopothresh < 1 then hopothresh = 1 end
		midiHash=""
		updateMidi()
	end
}

local function Main()
	imgScale=math.min(gfx.w,gfx.h)/1024
	local char = gfx.getchar()
	if char ~= -1 then
		reaper.defer(Main)
	end
	playState=reaper.GetPlayState()
	if keyBinds[char] then
        keyBinds[char]()
    end
	-- if char~=0 then
	-- 	reaper.ShowConsoleMsg(tostring(char).."\n")
	-- end	
	isplastic = inst >= 5
	isriffmaster = inst >= 6
	isexpert = diff == 4
	isprodrums = inst == 5
	soloactive = false
	trillactive = false

	if (isexpert or isplastic) and not isprodrums then
		gfx.blit(1,imgScale,0,0,0,1024,1024,(gfx.w/2)-(imgScale*512),gfx.h-(1024*imgScale)); 
	else
		gfx.blit(0,imgScale,0,0,0,1024,1024,(gfx.w/2)-(imgScale*512),gfx.h-(1024*imgScale));   
	end 
	if playState==1 then
		curTime=reaper.GetPlayPosition()-offset
	end
	curCursorTime=reaper.GetCursorPosition()
	if playState~=1  then
		curTime=curCursorTime
	end
	if curCursorTime~=lastCursorTime then
		lastCursorTime=curCursorTime
	end
	curNote=1
	for i=1,#notes do
		curNote=i
		if notes[i][1]+notes[i][2]>=curTime then
			break
		end
	end
	curOdPhrase=1
	for i=1,#od_phrases do
		if od_phrases[i][1] <= curTime then
			curOdPhrase = i
		end
	end

	curTimeLine=1
	for i=1,#beatLines do
		curTimeLine=i
		if beatLines[i][1]>=curTime-2 then
			break
		end
	end

	for i = 1, #solo_markers do
		if solo_markers[i][1] <= curTime and solo_markers[i][2] >= curTime then
			soloactive = true
		end
	end

	for i = 1, #trills do
		if trills[i][1] <= curTime and trills[i][2] >= curTime then
			trillactive = true
		end
	end

	updateEvents()
	updateMidi()
	updateBeatLines()
	drawBeats()
	drawNotes()
	gfx.x,gfx.y=0,0
	gfx.setfont(1, "Arial", 20)
	if not minifyui then
			gfx.drawstr(string.format(
			[[%s %s
			Note: %d/%d
			Current Time: %.03f
			Snap: %s
			Track Speed: %.02f
			Offset: %.02f
			]],
			diffNames[diff],
			instrumentTracks[inst][1],
			curNote,
			tostring(#notes),
			curTime,
			toFractionString(quants[movequant]),
			trackSpeed,
			offset
		))
	else
		gfx.drawstr(string.format(
			[[%s %s
			]],
			diffNames[diff],
			instrumentTracks[inst][1]
		))
	end
	if minifyui then gfx.setfont(1, "Arial", 15) end
	gfx.x,gfx.y=0,gfx.h-15
	versionstr = string.format("Version %s",version_num)
	if minifyui then versionstr = string.format("v%s",version_num) end
	gfx.drawstr(versionstr)
	gfx.setfont(1, "Arial", 20)
	if not minifyui then
		strx,stry=gfx.measurestr("Press F1 for controls")
		gfx.x,gfx.y=gfx.w-strx,gfx.h-stry
		gfx.drawstr("Press F1 for controls")
	end

	if isriffmaster and not minifyui then
		hopostr = "HOPO Thresh: "..hopothresh..' ticks'
		strx,stry=gfx.measurestr(hopostr)
		gfx.x,gfx.y=(gfx.w/2)-(strx/2),0
		gfx.drawstr(hopostr)
	end

	if soloactive or trillactive then
		solostr = 'SOLO, TRILL ACTIVE'
		if soloactive and not trillactive then
			solostr = 'SOLO ACTIVE'
		elseif trillactive and not soloactive then
			solostr = 'TRILL ACTIVE'
		end
		
		strx,stry=gfx.measurestr(solostr)
		gfx.x,gfx.y=(gfx.w/2)-(strx/2),0
		if isriffmaster then gfx.y = 20 end
		gfx.drawstr(solostr)
	end

	local btime = breakTime()
	if btime > 3 then
		local measuresNextNote = reaper.TimeMap2_timeToQN(0, curTime) / 4
		local toMeasureTime = notes[curNote][10] / 4

		local measuresLeft = math.floor((toMeasureTime-measuresNextNote))
		if measuresLeft < 0 then
			measuresLeft = 0
		end

		strx,stry=gfx.measurestr(measuresLeft)

		gfx.x,gfx.y=(gfx.w/2)-(strx/2),gfx.h - 100
		gfx.drawstr(measuresLeft)
	end

	proColorsForAllParts = options[1][2]
	enhancedInvalidChords = options[2][2]
	enhancedInvalidChordsThresh = options[3][2]
	checkForInvalidChords = options[4][2]
	checkForExtendedSustains = options[4][2]
	pixelsDrumline = options[5][2]
	hopothresh = options[6][2]
	pixelsOdLines = options[7][2]
	trackSpeed = options[8][2]
	offset = options[9][2]
	beatLineTimes = options[10][2]
	minifyui = options[11][2]

	if showHelp then
		gfx.mode=0
		gfx.r,gfx.g,gfx.b,gfx.a=0,0,0,0.75
		gfx.rect(0,0,gfx.w,gfx.h)
		gfx.r,gfx.g,gfx.b,gfx.a=1,1,1,1
		gfx.x,gfx.y=0,320*imgScale

		for i=1, #options do
			--if options[i][3] == 'stepper' then break end

			initialY = 20

			if option_curselected == i and options[i][3] == 'stepper' then
				gfx.blit(51, 1, 0, 0, 0, 128, 128, 235, 425)
				gfx.x = 294
				gfx.y = 425 + 16
				gfx.drawstr('Stepper: Change Direction')
			end

			gfx.x = 30
			gfx.y = initialY + (30 * (i - 1))

			optx = gfx.w - (30 + 53)
			opty = (initialY - 18) + (30 * (i - 1))

			gfx.drawstr(options[i][1])

			if options[i][3] == 'toggle' then
				gfx.blit(options[i][2] and 37 or 38, 1, 0, 0, 0, 128,128, optx, opty)

				if option_curselected == i then
					gfx.blit(39, 1, 0, 0, 0, 128,128, optx, opty)
				end
			elseif options[i][3] == 'stepper' then
				optx = optx + 38
				gfx.blit(((options[i][4] == 1) and (option_curselected==i)) and 44 or 43, 1, 0, 0, 0, 128,128, optx, opty)

				optx = optx - 53
				gfx.blit((option_curselected == i) and 45 or 40, 1, 0, 0, 0, 128,128, optx, opty)

				strx,stry = gfx.measurestr(options[i][2])
				gfx.x = (optx + math.floor(53 / 2)) - math.floor(strx/2)
				gfx.drawstr(options[i][2])

				optx = optx - 53
				gfx.blit(((options[i][4] == 0) and (option_curselected==i)) and 42 or 41, 1, 0, 0, 0, 128,128, optx, opty)
			end
		end

		keybindrow1 = {
			{46, 'Change Instrument'},
			{47, 'Change Difficulty'},
			{48, 'Change Snap'},
			{49, 'Scroll Up/Down'}
		}

		keybindrow2 = {
			{50, 'Scroll Through Options'},
			{52, 'Change Option'},
			{53, 'Show/Hide'}
		}

		for i=1, #keybindrow1 do
			x = 30 - 5
			y = 335 + (30 * (i - 1))

			gfx.x = x
			gfx.y = y + 16

			gfx.blit(keybindrow1[i][1], 1, 0, 0, 0, 128, 128, x, y)
			gfx.x = x + 59
			gfx.drawstr(keybindrow1[i][2])
		end

		for i=1, #keybindrow2 do
			x = 240 - 5
			y = 335 + (30 * (i - 1))

			gfx.x = x
			gfx.y = y + 16

			gfx.blit(keybindrow2[i][1], 1, 0, 0, 0, 128, 128, x, y)
			gfx.x = x + 59
			gfx.drawstr(keybindrow2[i][2])
		end
	end
	gfx.update()
end

Main()
