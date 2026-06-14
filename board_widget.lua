local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local GestureRange   = require("ui/gesturerange")
local Geom           = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local C_BG       = Blitbuffer.COLOR_WHITE
local C_DIE_ACT  = Blitbuffer.COLOR_WHITE
local C_DIE_KEPT = Blitbuffer.COLOR_GRAY_D
local C_DIE_BDR  = Blitbuffer.COLOR_BLACK
local C_WORM_BG  = Blitbuffer.COLOR_GRAY_9
local C_TEXT     = Blitbuffer.COLOR_BLACK
local C_TILE_AV  = Blitbuffer.COLOR_GRAY_E
local C_TILE_TKN = Blitbuffer.COLOR_GRAY_B
local C_TILE_BDR = Blitbuffer.COLOR_GRAY_9

-- ---------------------------------------------------------------------------
-- PicominoBoardWidget
-- ---------------------------------------------------------------------------

local PicominoBoardWidget = InputContainer:extend{
    board       = nil,
    max_width   = 200,
    max_height  = 150,
    onFaceTap   = nil,
}

function PicominoBoardWidget:init()
    local w = self.max_width
    local h = self.max_height
    self.w = w
    self.h = h
    self.dimen      = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = w, h = h }

    local die_sz = math.max(7, math.floor(h * 0.09))
    self.die_face = Font:getFace("smallinfofont", die_sz)

    local tile_sz = math.max(6, math.floor(h * 0.06))
    self.tile_face = Font:getFace("smallinfofont", tile_sz)

    self.ges_events = {
        DieTap = {
            GestureRange:new{
                ges   = "tap",
                range = function() return self.paint_rect end,
            }
        },
    }
end

function PicominoBoardWidget:onDieTap(_, ges)
    if not (ges and ges.pos) then return false end
    local rect = self.paint_rect
    local lx   = ges.pos.x - rect.x
    local ly   = ges.pos.y - rect.y
    if lx < 0 or ly < 0 or lx >= rect.w or ly >= rect.h then return false end
    if not self._die_zones then return false end
    for _, zone in ipairs(self._die_zones) do
        if lx >= zone.x and lx < zone.x + zone.w
                and ly >= zone.y and ly < zone.y + zone.h then
            if self.onFaceTap then self.onFaceTap(zone.face) end
            return true
        end
    end
    return false
end

function PicominoBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

function PicominoBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local w, h  = self.w, self.h

    bb:paintRect(x, y, w, h, C_BG)

    local nd       = board.NUM_DICE
    local die_area_h = math.floor(h * 0.50)
    local die_size   = math.min(
        math.floor(w / (nd + 1)),
        math.floor(die_area_h * 0.80)
    )
    die_size = math.max(die_size, 10)
    local die_gap  = math.floor((w - nd * die_size) / (nd + 1))
    die_gap = math.max(die_gap, 2)

    local die_y    = y + math.floor((die_area_h - die_size) / 2)

    self._die_zones = {}

    -- Group dice by face value for tap zones
    local face_zones = {}  -- face → {x, y, w, h}

    for i = 1, nd do
        local d     = board.dice[i]
        local dx    = x + die_gap + (i - 1) * (die_size + die_gap)
        local bg    = d.kept and C_DIE_KEPT or C_DIE_ACT
        local face  = d.face
        local label = (face == board.FACE_WORM) and "W" or tostring(face)
        if face == board.FACE_WORM then bg = d.kept and C_DIE_KEPT or C_WORM_BG end

        bb:paintRect(dx, die_y, die_size, die_size, bg)
        -- border
        local bw = 1
        bb:paintRect(dx, die_y, die_size, bw, C_DIE_BDR)
        bb:paintRect(dx, die_y + die_size - bw, die_size, bw, C_DIE_BDR)
        bb:paintRect(dx, die_y, bw, die_size, C_DIE_BDR)
        bb:paintRect(dx + die_size - bw, die_y, bw, die_size, C_DIE_BDR)

        -- face text
        local m  = RenderText:sizeUtf8Text(0, die_size, self.die_face, label, true, false)
        local tx = dx + math.floor((die_size - m.x) / 2)
        local ty = die_y + math.floor((die_size - (m.y_bottom - m.y_top)) / 2) + m.y_bottom
        local fc = (face == board.FACE_WORM and not d.kept) and Blitbuffer.COLOR_WHITE or C_TEXT
        RenderText:renderUtf8Text(bb, tx, ty, self.die_face, label, true, false, fc)

        -- register tap zone by face (non-kept only)
        if not d.kept then
            if not face_zones[face] then
                face_zones[face] = { x = dx - x, y = die_y - y, w = die_size, h = die_size, face = face }
                self._die_zones[#self._die_zones + 1] = face_zones[face]
            else
                -- extend zone width to cover this die too
                local z = face_zones[face]
                local new_x2 = dx - x + die_size
                local old_x2 = z.x + z.w
                if new_x2 > old_x2 then z.w = new_x2 - z.x end
            end
        end
    end

    -- Kept values summary row
    local kv_y    = y + die_area_h + math.floor(h * 0.02)
    local kv_label = _("Kept: ")
    local kv_parts = {}
    local FACE_WORM = board.FACE_WORM
    for face, _ in pairs(board.kept_values) do
        local lbl = (face == FACE_WORM) and "W" or tostring(face)
        kv_parts[#kv_parts + 1] = lbl
    end
    table.sort(kv_parts, function(a, b)
        local na = (a == "W") and 6 or tonumber(a)
        local nb = (b == "W") and 6 or tonumber(b)
        return na < nb
    end)
    local kv_text = kv_label .. (#kv_parts > 0 and table.concat(kv_parts, " ") or "-")
    local kv_m = RenderText:sizeUtf8Text(0, w, self.tile_face, kv_text, true, false)
    RenderText:renderUtf8Text(bb, x + 4, kv_y + kv_m.y_bottom, self.tile_face, kv_text, true, false, C_TEXT)

    -- Tile row (21-36)
    local tile_area_y = kv_y + math.floor(h * 0.12)
    local tile_count  = board.TILE_MAX - board.TILE_MIN + 1
    local tile_w      = math.max(math.floor((w - 4) / tile_count) - 1, 8)
    local tile_h      = math.max(math.floor(h * 0.18), 12)
    local tile_gap    = math.floor((w - 4 - tile_count * tile_w) / (tile_count + 1))
    tile_gap = math.max(tile_gap, 1)

    for ti = 1, tile_count do
        local val = board.TILE_MIN + ti - 1
        local tx  = x + 2 + tile_gap + (ti - 1) * (tile_w + tile_gap)
        local ty2 = tile_area_y
        local available = board.available[val]
        -- check if player owns this tile
        local player_owns = false
        for _, pt in ipairs(board.player_tiles) do
            if pt == val then player_owns = true; break end
        end

        local bg
        if player_owns then
            bg = C_DIE_BDR  -- black = owned
        elseif available then
            bg = C_TILE_AV
        else
            bg = C_TILE_TKN
        end
        bb:paintRect(tx, ty2, tile_w, tile_h, bg)
        bb:paintRect(tx, ty2, tile_w, 1, C_TILE_BDR)
        bb:paintRect(tx, ty2 + tile_h - 1, tile_w, 1, C_TILE_BDR)
        bb:paintRect(tx, ty2, 1, tile_h, C_TILE_BDR)
        bb:paintRect(tx + tile_w - 1, ty2, 1, tile_h, C_TILE_BDR)

        local lbl   = tostring(val)
        local lbl_m = RenderText:sizeUtf8Text(0, tile_w, self.tile_face, lbl, true, false)
        local lx2   = tx + math.floor((tile_w - lbl_m.x) / 2)
        local ly2   = ty2 + math.floor((tile_h - (lbl_m.y_bottom - lbl_m.y_top)) / 2) + lbl_m.y_bottom
        local tc    = player_owns and Blitbuffer.COLOR_WHITE or C_TEXT
        RenderText:renderUtf8Text(bb, lx2, ly2, self.tile_face, lbl, true, false, tc)
    end
end

return PicominoBoardWidget
