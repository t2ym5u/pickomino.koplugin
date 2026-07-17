local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local PluginBase       = require("plugin_base")
local _                = require("gettext")

require("i18n").extend(lrequire("i18n_fr"))
local PickominoScreen  = lrequire("screen")

local Pickomino = PluginBase:extend{
    name      = "pickomino",
    menu_text = _("Pickomino"),
    menu_hint = "tools",
}

function Pickomino:createScreen()
    return PickominoScreen:new{ plugin = self }
end

return Pickomino
