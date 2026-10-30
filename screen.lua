local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local FrameContainer     = require("ui/widget/container/framecontainer")
local HorizontalGroup    = require("ui/widget/horizontalgroup")
local HorizontalSpan     = require("ui/widget/horizontalspan")
local Size               = require("ui/size")
local UIManager          = require("ui/uimanager")
local VerticalGroup      = require("ui/widget/verticalgroup")
local VerticalSpan       = require("ui/widget/verticalspan")
local _                  = require("i18n")
local T                  = require("ffi/util").template

local ScreenBase           = require("screen_base")
local PickominoBoard       = lrequire("board")
local PicominoBoardWidget  = lrequire("board_widget")

local GAME_RULES_EN = _([[
Pickomino (Heckmeck) — Rules

Collect worm tiles by rolling dice to reach their values.

On each turn:
1. Roll all 8 dice.
2. Set aside all dice showing one face value of your choice.
3. Re-roll the remaining dice and set aside another face value (must be new).
4. Repeat until you decide to stop, or until no new face value can be set aside.
5. Your score is the sum of all set-aside dice.
   • Your total must include at least one worm (⚕) face.
   • Claim the worm tile whose value matches your total (or the nearest lower available tile).
6. If your total has no worm, or no tile is claimable, you lose your top tile.

The player with the most worm symbols on their collected tiles wins!
]])

local GAME_RULES_FR = [[
Pickomino (Heckmeck) — Règles

Récoltez des tuiles "vers" en lançant des dés pour atteindre leurs valeurs.

À chaque tour :
1. Lancez les 8 dés.
2. Mettez de côté tous les dés affichant une valeur de face de votre choix.
3. Relancez les dés restants et mettez de côté une nouvelle valeur de face (différente des précédentes).
4. Répétez jusqu'à décider de vous arrêter, ou jusqu'à ne plus pouvoir mettre de côté une nouvelle valeur.
5. Votre score est la somme de tous les dés mis de côté.
   • Votre total doit inclure au moins une face "ver" (⚕).
   • Réclamez la tuile dont la valeur correspond à votre total (ou la plus proche inférieure disponible).
6. Si votre total n'inclut pas de face ver, ou si aucune tuile n'est disponible, vous perdez votre tuile du dessus.

Le joueur ayant le plus de symboles vers sur ses tuiles gagne !
]]

local PickominoScreen = ScreenBase:extend{}

function PickominoScreen:init()
    local state = self.plugin:loadState()
    self.board  = PickominoBoard:new{}
    if not self.board:load(state) then
        self.board:newGame()
    end
    ScreenBase.init(self)
end

function PickominoScreen:serializeState()
    return self.board:serialize()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function PickominoScreen:buildLayout()
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Pickomino"), function()
        return {
            { text = _("New game"), callback = function() self:onNewGame() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    self.status_text:setMaxWidth(self:getControlsWidth())
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar({
            { text = _("Roll"),  callback = function() self:onRoll() end },
            { text = _("Stop"),  callback = function() self:onStop() end },
        }),
    }

    local padding     = Size.padding.large
    local frame_extra = 2 * (padding + Size.border.window)
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)

    self.board_widget = PicominoBoardWidget:new{
        board      = self.board,
        max_width  = budget_w - frame_extra,
        max_height = budget_h - frame_extra,
        onFaceTap  = function(face) self:onFaceTap(face) end,
    }

    local board_frame = FrameContainer:new{
        padding = padding,
        margin  = 0,
        self.board_widget,
    }

    if is_landscape then
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Dice interaction
-- ---------------------------------------------------------------------------

function PickominoScreen:onFaceTap(face)
    if self.board.turn_state ~= "deciding" then
        self:updateStatus(_("Roll the dice first."))
        return
    end
    local ok = self.board:keepValue(face)
    if not ok then
        local lbl = (face == PickominoBoard.FACE_WORM) and "W" or tostring(face)
        -- Return here: falling through to updateStatus() would overwrite the
        -- message before it was ever seen.
        self:updateStatus(T(_("Cannot keep %1 — already set aside or not rolled."), lbl))
        return
    end
    self.board_widget:refresh()
    self:updateStatus()
    self:refreshActionBar()
    self.plugin:saveState(self.board:serialize())
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function PickominoScreen:onRoll()
    local board = self.board
    if board.game_over then
        self:updateStatus(_("Game over. Start a new game."))
        return
    end
    if board.turn_state ~= "rolling" then
        self:updateStatus(_("Keep a die face first."))
        return
    end
    local ok = board:rollDice()
    self.board_widget:refresh()
    if not ok then
        self:updateStatus(_("Bust! No new values available."))
    else
        self:updateStatus()
    end
    self:refreshActionBar()
    self.plugin:saveState(board:serialize())
end

function PickominoScreen:onStop()
    local board = self.board
    if board.game_over then
        self:updateStatus(_("Game over. Start a new game."))
        return
    end
    if board.turn_state == "rolling" and board.turn_sum == 0 then
        self:updateStatus(_("Nothing to stop yet. Roll first."))
        return
    end
    local ok = board:stopTurn()
    self.board_widget:refresh()
    if not ok then
        self:updateStatus(_("Need at least one worm and total >= 21 to stop."))
    else
        self:updateStatus()
    end
    self:refreshActionBar()
    self.plugin:saveState(board:serialize())
end

function PickominoScreen:isRoundOver()
    return self.board.game_over and true or false
end

function PickominoScreen:onNewGame()
    self.board = PickominoBoard:new{}
    self.board:newGame()
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function PickominoScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    else
        local board = self.board
        if board.game_over then
            status = T(_("Game over! Final score: %1 worms"), board.score)
        else
            local state_label
            if board.turn_state == "rolling" then
                state_label = _("Roll dice")
            elseif board.turn_state == "deciding" then
                state_label = _("Choose a face to keep")
            else
                state_label = _("Done")
            end
            local worm_str = board.has_worm and " W" or ""
            status = self:joinStatus(
                T(_("Round: %1/%2"), board.round, board.max_rounds),
                T(_("Sum: %1"), board.turn_sum .. worm_str),
                T(_("Score: %1"), board.score),
                state_label)
        end
    end
    ScreenBase.updateStatus(self, status)
end

return PickominoScreen
