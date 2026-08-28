-- DMS user keybind overrides (edit via Control Center or dms; do not remove this header)

local function focus_workspace_on_monitor(dir)
	local ws = hl.get_active_workspace()
	if not ws then return end
	local base = (ws.monitor.name == "DP-2") and 1 or 6
	local offset = ((ws.id - base + dir) % 5 + 5) % 5
	hl.dispatch(hl.dsp.focus({ workspace = tostring(base + offset) }))
end

hl.unbind("SUPER + I")
hl.bind("SUPER + I", function() focus_workspace_on_monitor(1) end, { description = "focus next workspace on this monitor" })
hl.unbind("SUPER + K")
hl.bind("SUPER + K", function() focus_workspace_on_monitor(-1) end, { description = "focus previous workspace on this monitor" })
hl.unbind("SUPER + mouse:276")
hl.bind("SUPER + mouse:276", function() focus_workspace_on_monitor(1) end, { description = "focus next workspace on this monitor" })
hl.unbind("SUPER + mouse:275")
hl.bind("SUPER + mouse:275", function() focus_workspace_on_monitor(-1) end, { description = "focus previous workspace on this monitor" })
hl.unbind("SUPER + mouse_down")
hl.unbind("SUPER + mouse_up")
hl.unbind("SUPER + ALT + L")
hl.unbind("SUPER + L")
hl.unbind("SUPER + O")
hl.unbind("SUPER + Page_Down")
hl.unbind("SUPER + Page_Up")
hl.unbind("SUPER + SHIFT + W")
hl.unbind("SUPER + U")
hl.unbind("SUPER + comma")

hl.bind("SUPER + L", hl.dsp.exec_cmd("dms ipc call lock lock"), { description = "lock screen" })

hl.bind("F2", hl.dsp.exec_cmd("dms ipc call audio decrement 3"), { locked = true, repeating = true, description = "volume down" })
hl.bind("F3", hl.dsp.exec_cmd("dms ipc call audio increment 3"), { locked = true, repeating = true, description = "volume up" })
