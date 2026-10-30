local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local GestureRange   = require("ui/gesturerange")
local Geom           = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local Screen         = require("device").screen
local UIManager      = require("ui/uimanager")
local _              = require("i18n")

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

-- Font:getFace() scales its size argument by DPI; this takes a pixel
-- size instead so the glyphs can be fitted to the boxes they sit in.
local function face_px(px)
    local scale = Screen:scaleBySize(1000) / 1000
    return Font:getFace("smallinfofont", math.max(6, math.floor(px / scale)))
end

-- Render text centred on (cx, cy).
local function draw_centered(bb, face, text, cx, cy, color)
    local m = RenderText:sizeUtf8Text(0, 9999, face, text, true, false)
    local tx = cx - math.floor(m.x / 2)
    local ty = cy + math.floor((m.y_top - m.y_bottom) / 2)
    RenderText:renderUtf8Text(bb, tx, ty, face, text, true, false, color)
end

local TILE_COLS = 8   -- 16 tiles laid out as two rows of eight

function PicominoBoardWidget:init()
    local w = self.max_width
    local h = self.max_height
    local nd = self.board.NUM_DICE
    local tile_count = self.board.TILE_MAX - self.board.TILE_MIN + 1
    local tile_rows  = math.ceil(tile_count / TILE_COLS)

    -- Everything is sized from the width first, then shrunk to fit the
    -- height: dice row, "Kept" line, then the tile rows.
    local gap      = math.max(2, math.floor(w / 80))
    local die_size = math.min(math.floor((w - (nd + 1) * gap) / nd),
                              math.floor(h * 0.22))
    local tile_w   = math.floor((w - (TILE_COLS + 1) * gap) / TILE_COLS)
    local kept_h   = math.floor(die_size * 0.55)
    local tile_h   = math.floor(tile_w * 1.3)
    local avail_tile_h = math.floor((h - die_size - kept_h
                                     - (tile_rows + 3) * gap) / tile_rows)
    tile_h   = math.max(12, math.min(tile_h, avail_tile_h))
    die_size = math.max(10, die_size)

    self.gap        = gap
    self.die_size   = die_size
    self.kept_h     = kept_h
    self.tile_w     = tile_w
    self.tile_h     = tile_h
    self.tile_rows  = tile_rows
    -- Shrink to the content so the surrounding frame hugs it.
    h = math.min(h, die_size + kept_h + tile_rows * tile_h + (tile_rows + 3) * gap)

    self.w = w
    self.h = h
    self.dimen      = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = w, h = h }

    self.die_face  = face_px(die_size * 0.55)
    self.kept_face = face_px(kept_h * 0.65)
    self.tile_face = face_px(math.min(tile_w * 0.38, tile_h * 0.4))

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
    local w     = self.w
    local gap   = self.gap

    bb:paintRect(x, y, w, self.h, C_BG)

    local nd       = board.NUM_DICE
    local die_size = self.die_size
    local die_gap  = math.max(2, math.floor((w - nd * die_size) / (nd + 1)))
    local die_y    = y + gap

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
        local bw = math.max(1, math.floor(die_size / 40))
        bb:paintRect(dx, die_y, die_size, bw, C_DIE_BDR)
        bb:paintRect(dx, die_y + die_size - bw, die_size, bw, C_DIE_BDR)
        bb:paintRect(dx, die_y, bw, die_size, C_DIE_BDR)
        bb:paintRect(dx + die_size - bw, die_y, bw, die_size, C_DIE_BDR)

        -- face text
        local fc = (face == board.FACE_WORM and not d.kept) and Blitbuffer.COLOR_WHITE or C_TEXT
        draw_centered(bb, self.die_face, label,
            dx + math.floor(die_size / 2), die_y + math.floor(die_size / 2), fc)

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
    local kv_y    = die_y + die_size + gap
    local kv_label = _("Kept: ")
    local kv_parts = {}
    local FACE_WORM = board.FACE_WORM
    for face in pairs(board.kept_values) do
        local lbl = (face == FACE_WORM) and "W" or tostring(face)
        kv_parts[#kv_parts + 1] = lbl
    end
    table.sort(kv_parts, function(a, b)
        local na = (a == "W") and 6 or tonumber(a)
        local nb = (b == "W") and 6 or tonumber(b)
        return na < nb
    end)
    local kv_text = kv_label .. (#kv_parts > 0 and table.concat(kv_parts, " ") or "-")
    draw_centered(bb, self.kept_face, kv_text,
        x + math.floor(w / 2), kv_y + math.floor(self.kept_h / 2), C_TEXT)

    -- Tile rows (21-36), two rows of eight, each with its worm count
    local tile_area_y = kv_y + self.kept_h + gap
    local tile_count  = board.TILE_MAX - board.TILE_MIN + 1
    local tile_w, tile_h = self.tile_w, self.tile_h
    local tile_gap    = math.max(1, math.floor((w - TILE_COLS * tile_w) / (TILE_COLS + 1)))
    local dot_r       = math.max(2, math.floor(math.min(tile_w / 15, tile_h / 14)))

    for ti = 1, tile_count do
        local val = board.TILE_MIN + ti - 1
        local col = (ti - 1) % TILE_COLS
        local row = math.floor((ti - 1) / TILE_COLS)
        local tx  = x + tile_gap + col * (tile_w + tile_gap)
        local ty2 = tile_area_y + row * (tile_h + gap)
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

        local tc  = player_owns and Blitbuffer.COLOR_WHITE or C_TEXT
        local tcx = tx + math.floor(tile_w / 2)
        draw_centered(bb, self.tile_face, tostring(val),
            tcx, ty2 + math.floor(tile_h * 0.36), tc)

        -- Worm count as a row of dots in the lower part of the tile
        local worms  = board.wormsForTile(val)
        local step   = dot_r * 3
        local dot_x0 = tcx - math.floor((worms - 1) * step / 2)
        local dot_y  = ty2 + math.floor(tile_h * 0.76)
        for k = 0, worms - 1 do
            bb:paintCircle(dot_x0 + k * step, dot_y, dot_r, tc)
        end
    end
end

return PicominoBoardWidget
