-- ---------------------------------------------------------------------------
-- PickominoBoard — Pickomino (Regenwormen) solo game logic
-- ---------------------------------------------------------------------------

local PickominoBoard = {}
PickominoBoard.__index = PickominoBoard

local NUM_DICE  = 8
local FACE_WORM = "W"

-- Pip values per face
local PIPS = { [1]=1, [2]=2, [3]=3, [4]=4, [5]=5, [FACE_WORM]=5 }

-- Tile worm counts: 21-24 → 1, 25-28 → 2, 29-32 → 3, 33-36 → 4
local function worms_for_tile(v)
    if v >= 33 then return 4
    elseif v >= 29 then return 3
    elseif v >= 25 then return 2
    else return 1 end
end

local TILE_MIN = 21
local TILE_MAX = 36

local function make_tiles()
    local t = {}
    for v = TILE_MIN, TILE_MAX do
        t[v] = true
    end
    return t
end

function PickominoBoard:new(opts)
    opts = opts or {}
    local o = setmetatable({}, self)
    o.max_rounds    = opts.max_rounds or 5
    o.round         = 1
    o.score         = 0
    o.available     = make_tiles()
    o.player_tiles  = {}
    o.dice          = {}
    o.kept_values   = {}
    o.turn_sum      = 0
    o.has_worm      = false
    o.turn_state    = "rolling"
    o.last_roll     = {}
    o.busted        = false
    o.game_over     = false
    o:_init_dice()
    return o
end

function PickominoBoard:_init_dice()
    self.dice = {}
    for i = 1, NUM_DICE do
        self.dice[i] = { face = 1, kept = false }
    end
end

function PickominoBoard:_roll_face()
    local r = math.random(6)
    if r == 6 then return FACE_WORM end
    return r
end

-- Roll all non-kept dice. Returns false if bust (all rolled values already kept).
function PickominoBoard:rollDice()
    if self.turn_state ~= "rolling" then return false end
    self.last_roll = {}
    local rolled_faces = {}
    for i = 1, NUM_DICE do
        if not self.dice[i].kept then
            local f = self:_roll_face()
            self.dice[i].face = f
            rolled_faces[f] = true
        end
    end
    -- check if any new value can be kept
    local can_keep = false
    for face, _ in pairs(rolled_faces) do
        if not self.kept_values[face] then
            can_keep = true
            break
        end
    end
    self.turn_state = "deciding"
    if not can_keep then
        self:_bust()
        return false
    end
    return true
end

function PickominoBoard:_bust()
    self.busted = true
    -- remove top player tile if any
    if #self.player_tiles > 0 then
        local top = self.player_tiles[#self.player_tiles]
        self.player_tiles[#self.player_tiles] = nil
        -- return tile to available if still valid range
        if top >= TILE_MIN and top <= TILE_MAX then
            self.available[top] = true
        end
    end
    self:_end_turn()
end

-- Keep all dice showing face_val. Returns false if not valid.
function PickominoBoard:keepValue(face_val)
    if self.turn_state ~= "deciding" then return false end
    if self.kept_values[face_val] then return false end
    -- check at least one un-kept die shows this face
    local found = false
    for i = 1, NUM_DICE do
        if not self.dice[i].kept and self.dice[i].face == face_val then
            found = true; break
        end
    end
    if not found then return false end
    -- mark all matching dice as kept
    local pips = PIPS[face_val] or 0
    for i = 1, NUM_DICE do
        if not self.dice[i].kept and self.dice[i].face == face_val then
            self.dice[i].kept = true
            self.turn_sum = self.turn_sum + pips
        end
    end
    self.kept_values[face_val] = true
    if face_val == FACE_WORM then self.has_worm = true end
    -- check if all dice kept (forced stop)
    local all_kept = true
    for i = 1, NUM_DICE do
        if not self.dice[i].kept then all_kept = false; break end
    end
    if all_kept then
        self:stopTurn()
        return true
    end
    -- back to rolling state
    self.turn_state = "rolling"
    return true
end

-- Player chooses to stop
function PickominoBoard:stopTurn()
    if not self.has_worm or self.turn_sum < TILE_MIN then
        self:_bust()
        return false
    end
    -- Take highest available tile <= turn_sum
    local taken = nil
    for v = self.turn_sum, TILE_MIN, -1 do
        if self.available[v] then
            taken = v; break
        end
    end
    if taken then
        self.available[taken] = nil
        self.player_tiles[#self.player_tiles + 1] = taken
        self.score = self.score + worms_for_tile(taken)
    end
    self:_end_turn()
    return true
end

function PickominoBoard:_end_turn()
    self.round = self.round + 1
    if self.round > self.max_rounds then
        self.game_over  = true
        self.turn_state = "done"
    else
        self:_start_turn()
    end
end

function PickominoBoard:_start_turn()
    self:_init_dice()
    self.kept_values = {}
    self.turn_sum    = 0
    self.has_worm    = false
    self.busted      = false
    self.turn_state  = "rolling"
end

function PickominoBoard:newGame()
    self.round         = 1
    self.score         = 0
    self.available     = make_tiles()
    self.player_tiles  = {}
    self.game_over     = false
    self:_start_turn()
end

-- Available face values that can still be kept this deciding phase
function PickominoBoard:availableKeepFaces()
    local faces = {}
    local seen  = {}
    for i = 1, NUM_DICE do
        local d = self.dice[i]
        if not d.kept then
            local f = d.face
            if not seen[f] and not self.kept_values[f] then
                seen[f] = true
                faces[#faces + 1] = f
            end
        end
    end
    return faces
end

function PickominoBoard:serialize()
    local dice_s = {}
    for i, d in ipairs(self.dice) do
        dice_s[i] = { face = d.face, kept = d.kept }
    end
    local kv = {}
    for k, v in pairs(self.kept_values) do kv[tostring(k)] = v end
    local av = {}
    for k, v in pairs(self.available) do av[tostring(k)] = v end
    local pt = {}
    for i, v in ipairs(self.player_tiles) do pt[i] = v end
    return {
        max_rounds   = self.max_rounds,
        round        = self.round,
        score        = self.score,
        available    = av,
        player_tiles = pt,
        dice         = dice_s,
        kept_values  = kv,
        turn_sum     = self.turn_sum,
        has_worm     = self.has_worm,
        turn_state   = self.turn_state,
        busted       = self.busted,
        game_over    = self.game_over,
    }
end

function PickominoBoard:load(data)
    if type(data) ~= "table" or not data.dice then return false end
    self.max_rounds   = data.max_rounds  or 5
    self.round        = data.round       or 1
    self.score        = data.score       or 0
    self.turn_sum     = data.turn_sum    or 0
    self.has_worm     = data.has_worm    or false
    self.turn_state   = data.turn_state  or "rolling"
    self.busted       = data.busted      or false
    self.game_over    = data.game_over   or false
    -- dice
    self.dice = {}
    for i, d in ipairs(data.dice or {}) do
        local face = d.face
        -- numeric faces stored as numbers
        if type(face) == "number" then face = face end
        self.dice[i] = { face = face, kept = d.kept or false }
    end
    for i = #self.dice + 1, NUM_DICE do
        self.dice[i] = { face = 1, kept = false }
    end
    -- kept_values
    self.kept_values = {}
    for k, v in pairs(data.kept_values or {}) do
        local key = tonumber(k) or k
        self.kept_values[key] = v
    end
    -- available
    self.available = {}
    for k, v in pairs(data.available or {}) do
        self.available[tonumber(k)] = v
    end
    -- player_tiles
    self.player_tiles = data.player_tiles or {}
    return true
end

PickominoBoard.FACE_WORM = FACE_WORM
PickominoBoard.NUM_DICE  = NUM_DICE
PickominoBoard.TILE_MIN  = TILE_MIN
PickominoBoard.TILE_MAX  = TILE_MAX

return PickominoBoard
