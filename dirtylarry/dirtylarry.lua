local dirtylarry = {}

dirtylarry.action_id_touch       = hash("touch")
dirtylarry.action_id_text        = hash("text")
dirtylarry.action_id_marked_text = hash("marked_text")
dirtylarry.action_id_backspace   = hash("backspace")

dirtylarry.active_input_marked = ""
dirtylarry.active_node = nil
dirtylarry.input_nodes = {}
dirtylarry.colors = {
	base = vmath.vector4(1,1,1,1),
	active = vmath.vector4(1,1,1,1),
	enabled = vmath.vector4(1,1,1,1),
	disabled = vmath.vector4(1,1,1,0.2),
	mark = vmath.vector4(255/255,40/255,40/255,1)
}
dirtylarry.utf8_gfind = "([%z\1-\127\194-\244][\128-\191]*)"


function dirtylarry.is_enabled(self, node)
	local parent = gui.get_parent(node)
	if parent then
		return dirtylarry.is_enabled(self, parent)
	end
	return gui.is_enabled(node)
end


function dirtylarry.button(self, node, action_id, action, cb)

	local node_bg = gui.get_node(node .. "/larrybutton")
	local node_label = gui.get_node(node .. "/larrylabel")
	
	if not dirtylarry.is_enabled(self, node_bg) then
		return
	end

    local hit = gui.pick_node( node_bg, action.x, action.y )
	local touch = action_id == dirtylarry.action_id_touch
    
    local label_p = vmath.vector3(0.0)
    local flipbook = "button_normal"

    if (touch and hit) then
        if (action.released) then
            cb()
        else
        	label_p.y = -2.0
    		flipbook = "button_pressed"
        end
    end

    gui.play_flipbook(node_bg, flipbook)
    gui.set_position(node_label, label_p)

end


function dirtylarry.checkbox(self, node, action_id, action, value)

	local checked = value

	local node_bg = gui.get_node(node .. "/larrycheckbox")
	local node_label = gui.get_node(node .. "/larrylabel")	

	if not dirtylarry.is_enabled(self, node_bg) then
		return checked
	end

	local touch = action_id == dirtylarry.action_id_touch
    local hit = gui.pick_node( node_bg, action.x, action.y )
    if (node_label) then
    	hit = hit or gui.pick_node( node_label, action.x, action.y )
    end
    

    if (touch and hit) then
        if (action.released) then
            checked = not checked
        end
    end
    
    local append_str = ""
	if (checked) then
		append_str = "checked_"
	end
	
	local flipbook = "checkbox_" .. append_str .. "normal"
    if (touch and hit and not action.released) then
    	flipbook = "checkbox_" .. append_str .. "pressed"
    end
	
	gui.play_flipbook(node_bg, flipbook)
	return checked
end

function dirtylarry.radio(self, node, action_id, action, id, value)
	
	local node_bg = gui.get_node(node .. "/larryradio")
	local node_label = gui.get_node(node .. "/larrylabel")	

	if not dirtylarry.is_enabled(self, node_bg) then
		return value
	end

	local touch = action_id == dirtylarry.action_id_touch
    local hit = gui.pick_node( node_bg, action.x, action.y )
	if (node_label) then
		hit = hit or gui.pick_node( node_label, action.x, action.y )
	end

    if (touch and hit) then
        if (action.released) then
            value = id
        end
    end
    
    local append_str = ""
	if (value == id) then
		append_str = "checked_"
	end

	local flipbook = "radio_" .. append_str .. "normal"
    if (touch and hit and not action.released) then
    	flipbook = "radio_" .. append_str .. "pressed"
    end

	gui.play_flipbook(node_bg, flipbook)
	return value
end

function dirtylarry.input(self, node, action_id, action, type, empty_text)
	
	local node_bg = gui.get_node(node .. "/bg")
	local node_inner = gui.get_node(node .. "/inner")
	local node_content = gui.get_node(node .. "/content")
	local node_cursor = gui.get_node(node .. "/cursor")
	
	-- create entry in input_nodes table on first call
	if (not dirtylarry.input_nodes[node]) then
		dirtylarry.input_nodes[node] = { id = node, data = gui.get_text(node_content) }
	end

	if not dirtylarry.is_enabled(self, node_bg) then
		return dirtylarry.input_nodes[node].data
	end
	
	-- input/output states
	local text_output = dirtylarry.input_nodes[node].data
	local text_marked = ""
	local input_node = dirtylarry.input_nodes[node]
	local touch = action_id == dirtylarry.action_id_touch
	
	-- set inner box (clipper) to inner size of input field
	local s = gui.get_size(node_bg)
	s.x = s.x - 4-32
	s.y = s.y - 4
	gui.set_size(node_inner, s)
	
	-- keep track of current active input field
	local active_node_bg      = nil
	local active_node_content = nil
	local active_node_cursor  = nil
	if (dirtylarry.active_node) then
		active_node_bg = gui.get_node(dirtylarry.active_node.id .. "/bg")
		active_node_content = gui.get_node(dirtylarry.active_node.id .. "/content")
		active_node_cursor = gui.get_node(dirtylarry.active_node.id .. "/cursor")
	end
	
	-- switch active input node
	if (action_id == dirtylarry.action_id_touch and action.released and
		gui.pick_node(node_bg, action.x, action.y)) then
		
			-- kill previous active
			if (dirtylarry.active_node) then
				dirtylarry.active_input_marked = ""
				gui.cancel_animation(active_node_bg, "color")
				gui.animate(active_node_bg, "color", dirtylarry.colors.base, gui.EASING_OUTCUBIC, 0.2)
				gui.cancel_animation(active_node_cursor, "color")
				gui.animate(active_node_cursor, "size", vmath.vector3(0, 48, 0), gui.EASING_OUTCUBIC, 0.1)
				
				gui.reset_keyboard()
			end
			
			-- change to new entry
			dirtylarry.active_node = input_node
			gui.animate(node_bg, "color", dirtylarry.colors.active, gui.EASING_OUTCUBIC, 0.2)
			gui.animate(node_cursor, "size", vmath.vector3(4, 32, 0), gui.EASING_OUTCUBIC, 0.2)
			
			-- show keyboard for mobile devices
			gui.show_keyboard(type, true)
	end
	
	-- handle new input if current input node is active
	if (dirtylarry.active_node == input_node) then
	
		-- new raw text input
		if (action_id == dirtylarry.action_id_text) then
			dirtylarry.active_node.data = dirtylarry.active_node.data .. action.text
			dirtylarry.active_input_marked = ""
		
		-- new marked text input (uncommitted text)	
		elseif (action_id == dirtylarry.action_id_marked_text) then
			dirtylarry.active_input_marked = action.text
		
		-- input deletion
		elseif (action_id == dirtylarry.action_id_backspace and action.pressed) then
			local last_s = 0
			for uchar in string.gfind(dirtylarry.active_node.data, dirtylarry.utf8_gfind) do
	          last_s = string.len(uchar)
	        end
		
			dirtylarry.active_node.data = string.sub(dirtylarry.active_node.data, 1, string.len(dirtylarry.active_node.data) - last_s)
		end
		
		-- set text color
		gui.set_color(node_content, dirtylarry.colors.enabled)
		
		-- if current input is active, include marked text in output
		text_output = dirtylarry.active_node.data .. dirtylarry.active_input_marked
		
		-- get text metrics for both raw input data and marked text
		local m_t = gui.get_text_metrics(gui.get_font(node_content), dirtylarry.active_node.data, 0, false, 0, 0)
		local m_m = gui.get_text_metrics(gui.get_font(node_content), dirtylarry.active_input_marked, 0, false, 0, 0)
		
		-- set cursor (and marked text bg)
		gui.set_position(node_cursor, vmath.vector3(4 + m_t.width, 0, 0))
		if (dirtylarry.active_input_marked and #dirtylarry.active_input_marked) then
			gui.animate(node_cursor, "size", vmath.vector3(4 + m_m.width, 32, 0), gui.EASING_OUTCUBIC, 0.2)
		else
			gui.animate(node_cursor, "size", vmath.vector3(4, 32, 0), gui.EASING_OUTCUBIC, 0.2)
		end
		
	end
	
	-- if input field is a password, mask the text output
	if (type == gui.KEYBOARD_TYPE_PASSWORD) then
		local masked_text = ""
		for uchar in string.gfind(text_output, dirtylarry.utf8_gfind) do
          masked_text = masked_text .. "*"
        end
        text_output = masked_text
	end
	
	gui.set_text(node_content, text_output)
	
	-- show grayed out label/text if input is empty
	if (empty_text and string.len(text_output) == 0) then
		gui.set_color(node_content, dirtylarry.colors.disabled)
		gui.set_text(node_content, empty_text)
	end
	
	return dirtylarry.input_nodes[node].data
end

return dirtylarry
