_addon.author = "Icy"
_addon.name = "Time Trigger"
_addon.version = "1.0.0"
_addon.language = 'English'
_addon.commands = {'timetrigger','tt'}

require('luau')
require('GUI')

pname = windower.ffxi.get_player().name
defaults = {
	x = 800, -- 1400
	y = 100,  -- 800
	language = 'en',
	log_on_trigger = false, -- when true, outputs a msg to the chat window
	wav_filename = 'doublebass', -- chime
	
	header_font_size = 12,
	header_color = {255, 255, 195, 92}, -- alpha, r, g, b
	header_stroke_color = {255, 0, 0, 0},
	
	header_button_alignment = 'mid', -- valid strings are: mid, left, right
	
	header_time_font_size = 12,
	header_time_color = {255, 255, 195, 92},
	header_time_stroke_color = {255, 0, 0, 0},
	
	trigger_font_size = 10,
	trigger_active_color = {255, 117, 255, 186},
	trigger_active_stroke_color = {255, 0, 0, 0},
	trigger_inactive_color = {255, 255, 107, 107},
	trigger_inactive_stroke_color = {255, 0, 0, 0},
}
settings = config.load('data/'..pname..'.xml', defaults)

enabled = false
timestr = '0:00'
gui_items = T{}
if not settings.triggers then
	settings.triggers = T{
		['example'] = { at = '6:00', cmd = 'input /echo To remove this trigger use: //tt remove example', enabled = false, alert = true },
	}
end

windower.register_event('addon command', function(...)
    local commands = {...}
    local command = commands[1] and commands[1]:lower() or nil
	
	if not command or command == 'help' or command == 'h' then
		print_command_help()
		
	elseif command == 'eval' then
        assert(loadstring(table.concat(commands, ' ', 2)))()
	
	elseif not command or command == 'pos' or command == 'x' or command == 'y' then
		if command == 'pos' and tonumber(commands[2]) and tonumber(commands[3]) then
			settings.x = tonumber(commands[2])
			settings.y = tonumber(commands[3])
		elseif command == 'x' and tonumber(commands[2]) then
			settings.x = tonumber(commands[2])
		elseif command == 'y' and tonumber(commands[2]) then
			settings.y = tonumber(commands[2])
		else
			print_command_help('pos', 'Invalid command: '..commands:concat(' '))
			return
		end
		log('Updated Position:', settings.x, settings.y, '\n Notice: Remember to "//tt save" after settling on a position.')
		redraw_gui()
		
	elseif command == 'save' then
        settings:save('all')
		
	elseif command == 'start' or command == 'on' then
		enabled = true
		
	elseif command == 'stop' or command == 'off' then
		enabled = false
		
	elseif command == 'list' or command == 'l' then
		windower.add_to_chat(10, '[TRIGGER NAME]  [RUN AT]  [STATUS]')
		for t in pairs(settings.triggers) do
			local status = settings.triggers[t].enabled and 'on' or 'off'
			windower.add_to_chat(100, '['..t..']    ['..settings.triggers[t].at..']    ['..status..']\n'..'    CMD: '..settings.triggers[t].cmd)
			windower.add_to_chat(100,' ')
		end
		
	elseif command == 'edit' or command == 'e' then
		if not commands[2] or not commands[3] or not commands[4] then 
			print_command_help('edit')
			return
		end
		
		local trig_name = commands[2]:lower()
		local trig_field = commands[3]:lower()
		if trig_field == 'time' then trig_field = 'at' end
		local trig_to = commands[4]:lower()
		if tonumber(trig_to) then trig_to = tonumber(trig_to) end
		
		local valid_fields = S{'time', 'at', 'cmd', 'enabled', 'alert'}
		if not valid_fields:contains(trig_field) then
			print_command_help('edit', 'Invalid field argument')
			return
		end
		
		for t in pairs(settings.triggers) do
			if t:lower() == trig_name then
				settings.triggers[t][trig_field] = trig_to
			end
		end
		redraw_gui()
		
	elseif command == 'toggle' or command == 't' then 
		local trig_name = commands[2]
		if not trig_name then 
			print_command_help('toggle')
			return
		end
		
		if trig_name == 'all' or trig_name == 'a' then
			local state = true
			if commands[3] and commands[3]:lower() == 'off' then state = false end
			for t in pairs(settings.triggers) do
				settings.triggers[t].enabled = state
			end
		else
			if not settings.triggers[trig_name] then
				print_command_help('toggle', 'Could not find trigger: '..trig_name)
				return 
			end
			settings.triggers[trig_name].enabled = not settings.triggers[trig_name].enabled
		end
		settings:save('all')
		
	elseif command == 'remove' or command == 'r' or command == 'delete' or command == 'del' or command == 'd' then
		if not commands[2] then
			print_command_help('remove')
			return
		end
		
		if commands[2] == 'all' or commands[2] == 'a' then
			settings.triggers:clear()
			enabled = false
		else
			local removed = false
			for t in pairs(settings.triggers) do
				if t:lower() == commands[2]:lower() then 
					settings.triggers[t] = nil
					removed = true
					break
				end
			end
			if not removed then 
				print_command_help('remove', 'Could not find trigger: '..commands[2]) 
				return
			end
		end
		redraw_gui()
		
	elseif command:find(':') then -- //tt [time] [name] [cmd] {enabled} {alert}
		if #commands > 5 or #commands < 3 then 
			print_command_help('add', 'Invalid number of arguments. Tip: wrap the [cmd] in quotes')
			return
		end
		
		-- ie: //tt 18:00 NightAlert "input /echo It's night time!" false true
		local time_splat = commands[1]:split(':')
		local h = time_splat[1]
		local m = time_splat[2]
		if not tonumber(h) or not tonumber(m) then 
			print_command_help('add', 'Invalid time argument: '..commands[1]) 
			return
		end
		
		local trig_at = command
		local trig_name = commands[2]:gsub(' ', '_'):lower()
		local trig_cmd = commands[3]
		local trig_enabled = true
		local trig_alert = false
		if commands[4] and commands[4] == 'false' then trig_enabled = false end -- defaults as enabled.
		if commands[5] and commands[5] == 'true' then trig_alert = true end -- default is false.
		
		settings.triggers[commands[2]] = { at = trig_at, cmd = trig_cmd, enabled = trig_enabled, alert = trig_alert }
		settings:save('all')
		redraw_gui()
		
	else
		print_command_help(nil, 'Unknown command.')
		
	end
end)

function print_command_help(command, reason)
	if not command and reason then
		error(reason) -- Unknown command msg
	end
	if command == 'pos' or not command then
		if reason then error(reason) end
		log('WINDOW POSITIONING')
		log('//tt pos [x] [y]')
		log('  ie: //tt pos 800 500')
		log('//tt [x] <num>')
		log('  ie: //tt x 800')
		log('//tt [y] <num>')
		log('  ie: //tt y 500')
	end
	if command == 'add' or not command then
		if reason then error(reason) end
		log('ADDING TRIGGERS')
		log('  //tt [time] [name] [cmd] {enabled}(default: true) {alert}(default: false)')
		log('    ie 1: //tt 6:00 day_time "input /echo Good morning..."')
		log('    ie 2: //tt 18:00 night_time "input /echo It\'s night time! Let\'s party!!" false')
		log('    ie 3: //tt 3:00 Yawn "input /echo WAKE UP!!!" true true')
	end
	if command == 'edit' or not command then
		if reason then error(reason) end
		log('EDITING TRIGGERS')
		log('  //tt edit [name] time|cmd|enabled|alert [to]')
		log('    ie 1: //tt edit my_trigger cmd "input /echo yahooo!"')
		log('    ie 2: //tt edit multi_cmd_trigger cmd "input /echo ya....;input /echo hooo!!!!"')
		log('    ie 3: //tt edit night_time time 18:00')
		log('    ie 4: //tt edit trigger_1 enabled false')
		log('    ie 5: //tt edit trigger_1 alert true')
	end
	if command == 'remove' or not command then
		if reason then error(reason) end
		log('REMOVING TRIGGERS')
		log('  //tt remove|r [trigger_name|all]')
		log('    ie 1: //tt remove my_trigger')
		log('    ie 2: //tt remove all')
	end
	if command == 'toggle' or not command then
		if reason then error(reason) end
		log('TOGGLING TRIGGERS')
		log('  //tt toggle [trigger_name] - toggles specified triggers enabled state.')
		log('  //tt toggle all - enables all triggers.')
		log('  //tt toggle all off - disables all triggers.')
	end
	if not command then
		if reason then error(reason) end
		log('START / STOP / SAVE / LIST')
		log('  //tt start|on - begins monitoring triggers that are enabled')
		log('  //tt stop|off - stops monitoring triggers')
		log('  //tt list - lists all triggers, also includes the triggers cmd')
		log('  //tt save - saves all settings to {character}.xml')
	end
end

time_display = nil
windower.register_event('time change', function(new, old)
	local h = (new / 60):floor()
	local m = new % 60
	if m < 10 then m = '0'..m end
	timestr = h..':'.. m
	
	if time_display then time_display:undraw() end
	time_display = PassiveText{
		x = settings.x + 200,
		y = settings.y,
		text = timestr,
		align = 'right',
		color = settings.header_time_color,
		font_size = settings.header_time_font_size,
		stroke_color = settings.header_time_stroke_color,
	}
	time_display:draw()
	
	if enabled then
		local cmds = S{}
		local play_sound = false
		for t in pairs(settings.triggers) do
			if settings.triggers[t].enabled and settings.triggers[t].at == timestr then
				cmds:add(settings.triggers[t].cmd)
				if not play_sound and settings.triggers[t].alert then play_sound = true end
			end
		end
		
		if cmds:length() > 0 then
			if play_sound then
				windower.play_sound(windower.addon_path..'sounds/'..settings.wav_filename..'.wav')
			end
			
			local combined = cmds:concat(';')
			if settings.log_on_trigger then log(timestr, '!!! Command(s):', combined) end
			windower.send_command(combined)
		end
	end
end)

function redraw_gui(x, y) -- Redraws gui, x & y are optional
	for i, ele in ipairs(gui_items) do
		ele.label:undraw()
		gui_items[i] = nil
	end
	
	build_gui()
end

function build_gui()
	if header_dividor then header_dividor:undraw() end
	header_dividor = Divider({
		x = settings.x - 5,
		y = settings.y + 22,
		size = 210
	})
	header_dividor:draw()

	if addon_label then addon_label:undraw() end
	addon_label = PassiveText({
		x = settings.x + 5,
		y = settings.y,
		text = _addon.name:upper(),
		color = enabled and settings.trigger_active_color or settings.header_color,
		font_size = settings.header_font_size,
		stroke_color = settings.header_stroke_color,
	})
	addon_label:draw()

	local button_mid_x = 111
	local button_mid_y = -15
	
	local button_left_x = -40
	local button_left_y = -9
	
	local button_right_x = 200
	local button_right_y = -9
	
	-- default the pos to mid
	local button_x = settings.x + button_mid_x
	local button_y = settings.y + button_mid_y
	if settings.header_button_alignment == 'right' then
		button_x = settings.x + button_right_x
		button_y = settings.y + button_right_y
	elseif settings.header_button_alignment == 'left' then
		button_x = settings.x + button_left_x
		button_y = settings.y + button_left_y
	end
	
	if enable_button then enable_button:undraw() end
	enable_button = ToggleButton{
		x = button_x,
		y = button_y,
		var = 'enabled',
		iconUp = 'power_off.png',
		iconDown = 'power_on.png',
		command = nil
	}
	enable_button:draw()
	
	for t in pairs(settings.triggers) do create_trigger_button(t, settings.triggers[t]) end
	gui_items:foreachi(function(i, ele) ele.label:draw() end)	
end

function create_trigger_button(trig_name, trig)
	local button_x = settings.x + 55
	local label_x = settings.x + 200
	
	local incr = 25
	local button_y = settings.y
	local label_y = settings.y + 3
	
	local num_of_buttons = gui_items:length()
	if num_of_buttons > 0 then incr = incr * (num_of_buttons + 1) end
	label_y = label_y + incr
	button_y = button_y + incr
	
	local at = trig.at
	if trig.at:len() < 5 then at = '  '..trig.at end
		
	gui_items:insert({
		name = trig_name,
		label = PassiveText({
				x = label_x,
				y = label_y,
				font_size = settings.trigger_font_size,
				--text = trig_name..'   '..at..'    '..(trig.alert and '♪' or '   '),
				text = trig_name..'   '..at..'    '..(trig.alert and '♫' or '    '),
				align = 'right',
				bold = settings.triggers[trig_name].enabled,
				color = settings.triggers[trig_name].enabled and settings.trigger_active_color or settings.trigger_inactive_color,
				stroke_color = settings.triggers[trig_name].enabled and settings.trigger_active_stroke_color or settings.trigger_inactive_stroke_color,
			}
		),
	})
end

windower.register_event('load', function()
	log('To change the position use: //tt pos <x> <y>  - ie: //tt pos 1000 800  - note: x at 0 is far left, y at 0 is the very top.')
	build_gui()
end)

windower.register_event('unload','logout', function()
	settings:save('all')
end)
