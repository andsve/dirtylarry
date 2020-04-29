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
dirtylarry.slider_fmt = "%.3f"


function dirtylarry.is_enabled(self, node)
    local parent = gui.get_parent(node)
    if parent then
        return dirtylarry.is_enabled(self, parent)
    end
    return gui.is_enabled(node)
end

local function safe_get_node(node)
	if pcall(function() gui.get_node(node) end) then
		return gui.get_node(node)
	else
		return nil
	end
end

local function hit_test(self, node, action_id, action)
    if not dirtylarry.is_enabled(self, node) then
        return false
    end

    local hit = gui.pick_node( node, action.x, action.y )
    local touch = action_id == dirtylarry.action_id_touch
    return touch and hit
end

function dirtylarry.hit(self, node, action_id, action, cb)
    node = type(node) == "string" and gui.get_node(node) or node
    local hit = hit_test(self, node, action_id, action)
    if hit and action.released then
        cb()
    end
    return hit
end


function dirtylarry.button(self, node, action_id, action, cb)

    local node_bg = gui.get_node(node .. "/larrybutton")
    local node_label = gui.get_node(node .. "/larrylabel")

    local label_p = vmath.vector3(0.0)
    local flipbook = "button_normal"
    local hit = hit_test(self, node_bg, action_id, action)
    if hit then
        if action.released then
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

    local hit = hit_test(self, node_bg, action_id, action) or hit_test(self, node_label, action_id, action)
    if hit and action.released then
        checked = not checked
    end

    local flipbook = "checkbox_" .. (checked and "checked_" or "") .. (hit and not action.released and "pressed" or "normal")
    gui.play_flipbook(node_bg, flipbook)
    return checked
end

function dirtylarry.radio(self, node, action_id, action, id, value)

    local node_bg = gui.get_node(node .. "/larryradio")
    local node_label = gui.get_node(node .. "/larrylabel")

    local hit = hit_test(self, node_bg, action_id, action) or hit_test(self, node_label, action_id, action)
    if hit and action.released then
        value = id
    end

    local flipbook = "radio_" .. (value == id and "checked_" or "") .. (hit and not action.released and "pressed" or "normal")
    gui.play_flipbook(node_bg, flipbook)
    return value
end

function dirtylarry.input(self, node, action_id, action, type, empty_text)

    local node_bg = gui.get_node(node .. "/bg")
    local node_inner = gui.get_node(node .. "/inner")
    local node_content = gui.get_node(node .. "/content")
    local node_cursor = gui.get_node(node .. "/cursor")

    -- create a key that is unique to the gui scene
    local url = msg.url()
    local key = tostring(url.socket) .. hash_to_hex(url.path) .. hash_to_hex(url.fragment or hash("")) .. node

    -- create entry in input_nodes table on first call
    if (not dirtylarry.input_nodes[key]) then
        dirtylarry.input_nodes[key] = { id = node, data = gui.get_text(node_content), active = false }
    end

    local input_node = dirtylarry.input_nodes[key]
    if not dirtylarry.is_enabled(self, node_bg) then
        return input_node.data
    end

    -- if we don't have an active node or the active node is other than the current node and
    -- the current node was flagged as active then we need to deactivate it
    -- note that we need to deactivate the previously active input node in the correct gui_script
    -- otherwise we will get the "node used in the wrong scene" error
    if (not dirtylarry.active_node or dirtylarry.active_node ~= input_node) and input_node.active then
        local active_node_bg = gui.get_node(input_node.id .. "/bg")
        local active_node_cursor = gui.get_node(input_node.id .. "/cursor")
        input_node.active = false
        gui.cancel_animation(active_node_bg, "color")
        gui.animate(active_node_bg, "color", dirtylarry.colors.base, gui.EASING_OUTCUBIC, 0.2)
        gui.cancel_animation(active_node_cursor, "color")
        gui.animate(active_node_cursor, "size", vmath.vector3(0, 48, 0), gui.EASING_OUTCUBIC, 0.1)
    end

    -- input/output states
    local text_output = input_node.data
    local text_marked = ""
    local touch = action_id == dirtylarry.action_id_touch

    -- set inner box (clipper) to inner size of input field
    local s = gui.get_size(node_bg)
    s.x = s.x - 4-32
    s.y = s.y - 4
    gui.set_size(node_inner, s)

    -- switch active input node
    if hit_test(self, node_bg, action_id, action) then
            -- change to new entry
            gui.reset_keyboard()
            dirtylarry.active_input_marked = ""
            dirtylarry.active_node = input_node
            dirtylarry.active_node.active = true
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
        elseif (action_id == dirtylarry.action_id_backspace and (action.pressed or action.repeated)) then
            local last_s = 0
            for uchar in string.gmatch(dirtylarry.active_node.data, dirtylarry.utf8_gfind) do
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
        for uchar in string.gmatch(text_output, dirtylarry.utf8_gfind) do
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

    return input_node.data
end

function dirtylarry.scrollarea(self, node_str, action_id, action, scroll, cb)

    local node = gui.get_node(node_str)
    local parent = gui.get_parent(node)
    local touch = action_id == dirtylarry.action_id_touch
    
    local scroll = scroll
    if not scroll then
    	-- assume initial call
    	local p = gui.get_position(node)
    	local s = gui.get_size(node)
    	scroll = {drag=false,started=false,dx=0,dy=0,ox=p.x,oy=p.y,ow=s.x,oh=s.y}
    	
    	scroll.bar_x = safe_get_node(node_str .. "_barx")
    	scroll.bar_y = safe_get_node(node_str .. "_bary")
    end
    
    local hit = false
	if parent then
		hit = hit_test(self, parent, action_id, action)
	else
		hit = hit_test(self, node, action_id, action)
	end
    
    local consumed_input = false
	if touch then
	    
	    -- end scroll/drag
    	if scroll.drag and action.released then
    		scroll.drag = false
    		scroll.started = false
    		consumed_input = true
    		
    	-- potentially start scroll/drag
    	elseif hit and action.pressed then
    		scroll.started = true
    		
    	-- start scroll/drag
    	elseif scroll.started and hit and (action.dx ~= 0 or action.dy ~= 0) then
    		scroll.drag = true
    		scroll.started = false
    		consumed_input = true
    	end
    	
    	if scroll.drag then
	    	consumed_input = true
	
    		scroll.dx = scroll.dx - action.dx
    		scroll.dy = scroll.dy + action.dy
    		
    		if parent then
    			local s = gui.get_size(parent)
	    		local min_x = 0
	    		local min_y = 0
    			local max_x = math.max(0, scroll.ow - s.x)
    			local max_y = math.max(0, scroll.oh - s.y)
    			
    			if scroll.dx < min_x then scroll.dx = min_x end	
	    		if scroll.dx > max_x then scroll.dx = max_x end
	    		if scroll.dy < min_y then scroll.dy = min_y end
	    		if scroll.dy > max_y then scroll.dy = max_y end
	    		
	    		if scroll.bar_x and max_x > 0 then
	    			local delta_x = scroll.dx / max_x
	    			local bar_s = gui.get_size(scroll.bar_x)
	    			local p = vmath.vector3((s.x-bar_s.x) * delta_x, -s.y, 0)
	    			gui.set_position(scroll.bar_x, p)
	    		end
	    		if scroll.bar_y and max_y > 0 then
	    			local delta_y = scroll.dy / max_y
	    			local bar_s = gui.get_size(scroll.bar_y)
	    			local p = vmath.vector3(s.x, -(s.y-bar_s.y) * delta_y, 0)
	    			gui.set_position(scroll.bar_y, p)
	    		end
    		end
    		
    		gui.set_position(node, vmath.vector3(scroll.ox-scroll.dx, scroll.oy+scroll.dy, 0))
	    	
    	end
    end
	    
	if not consumed_input and ((touch and hit) or not touch) then
    	cb(self, action_id, action)
    end

	return scroll
end

local function clamp(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    end
    return v
end

function dirtylarry.slider(self, node_str, action_id, action, min_value, max_value, value)
    local node_sa = gui.get_node(node_str .. "/larrysafearea")
    local node_bg = gui.get_node(node_str .. "/larryslider")
    local node_cursor = gui.get_node(node_str .. "/larrycursor")
    local node_value = gui.get_node(node_str .. "/larryvalue")

    local hit = hit_test(self, node_sa, action_id, action) or hit_test(self, node_value, action_id, action)

    if action.released and action_id == dirtylarry.action_id_touch and dirtylarry.active_node == node_sa then
        dirtylarry.active_node = nil
    elseif hit and action.pressed and dirtylarry.active_node == nil then
        dirtylarry.active_node = node_sa
    end

    local sliding = hit and not action.released

    local sa_pos = gui.get_position(node_sa)
    local bg_pos = gui.get_position(node_bg)
    local bg_size = gui.get_size(node_bg)
    local cursor_size = gui.get_size(node_cursor)

    local slider_width = bg_size.x - cursor_size.x
    local slider_start = sa_pos.x + bg_pos.x + cursor_size.x * 0.5

    local unit_value = (value - min_value) / (max_value - min_value)
    unit_value = clamp(unit_value, min_value, max_value)

    if dirtylarry.active_node ~= node_sa then
        local pos = gui.get_position(node_cursor)
        pos.x = unit_value * (bg_size.x - cursor_size.x)
        gui.set_position(node_cursor, pos)
    elseif not action.released and dirtylarry.active_node == node_sa then
        local pos = gui.get_position(node_cursor)
        unit_value = (action.x - slider_start) / slider_width
        unit_value = clamp(unit_value, 0.0, 1.0)

        local pos = gui.get_position(node_cursor)
        pos.x = unit_value * (bg_size.x - cursor_size.x)
        gui.set_position(node_cursor, pos)
    end

    local slider_value = min_value * (1.0 - unit_value) + max_value * unit_value

    gui.set_text(node_value, string.format(dirtylarry.slider_fmt, slider_value))

    --local flipbook = "radio_" .. (sliding and "checked_" or "") .. (hit and not action.released and "pressed" or "normal")
    local flipbook = "radio_checked_" .. (hit and not action.released and "pressed" or "normal")
    gui.play_flipbook(node_cursor, flipbook)

    return slider_value
end

return dirtylarry
