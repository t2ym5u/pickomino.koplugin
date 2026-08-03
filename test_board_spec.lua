local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

describe("PickominoBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    describe("new", function()
        it("starts round 1 with 8 fresh dice, ready to roll", function()
            local b = Board:new()
            assert.are.equal(1, b.round)
            assert.are.equal(0, b.score)
            assert.are.equal(8, #b.dice)
            assert.are.equal("rolling", b.turn_state)
            for v = 21, 36 do
                assert.is_true(b.available[v])
            end
        end)
    end)

    describe("rollDice", function()
        it("rolls every un-kept die to a face in {1..5, worm}", function()
            math.randomseed(42)
            local b = Board:new()
            assert.is_true(b:rollDice())
            for _, d in ipairs(b.dice) do
                assert.is_true(d.face == Board.FACE_WORM or (d.face >= 1 and d.face <= 5))
            end
            assert.are.equal("deciding", b.turn_state)
        end)

        it("refuses to roll again before a keep decision", function()
            math.randomseed(42)
            local b = Board:new()
            b:rollDice()
            assert.is_false(b:rollDice())
        end)
    end)

    describe("keepValue", function()
        it("keeps every die showing the chosen face and accumulates pips", function()
            math.randomseed(42)
            local b = Board:new()
            b:rollDice()
            local face = b:availableKeepFaces()[1]
            local count = 0
            for _, d in ipairs(b.dice) do if d.face == face then count = count + 1 end end
            assert.is_true(b:keepValue(face))
            local expected_pips = (face == Board.FACE_WORM and 5 or face) * count
            assert.are.equal(expected_pips, b.turn_sum)
            assert.is_true(b.kept_values[face])
        end)

        it("refuses to keep a face that was already kept", function()
            math.randomseed(42)
            local b = Board:new()
            b:rollDice()
            local face = b:availableKeepFaces()[1]
            b:keepValue(face)
            b:rollDice()
            assert.is_false(b:keepValue(face))
        end)

        it("refuses outside the deciding state", function()
            local b = Board:new()
            assert.is_false(b:keepValue(1))
        end)
    end)

    describe("stopTurn", function()
        it("busts (no tile, next round) without a worm or under the tile minimum", function()
            local b = Board:new()
            b.turn_sum = 10
            b.has_worm = false
            assert.is_false(b:stopTurn())
            assert.are.same({}, b.player_tiles)
            assert.are.equal(2, b.round)
        end)

        it("takes the highest available tile at or below turn_sum when eligible", function()
            local b = Board:new()
            b.turn_sum = 25
            b.has_worm = true
            assert.is_true(b:stopTurn())
            assert.are.equal(25, b.player_tiles[1])
            assert.is_nil(b.available[25])
            assert.are.equal(2, b.score)  -- worms_for_tile(25) == 2
            assert.are.equal(2, b.round)
        end)
    end)

    describe("newGame", function()
        it("resets round, score and available tiles", function()
            local b = Board:new()
            b.turn_sum, b.has_worm = 25, true
            b:stopTurn()
            b:newGame()
            assert.are.equal(1, b.round)
            assert.are.equal(0, b.score)
            assert.are.same({}, b.player_tiles)
            assert.is_true(b.available[25])
        end)
    end)

    describe("serialize / load", function()
        it("round-trips round, score and dice state", function()
            math.randomseed(42)
            local b = Board:new()
            b:rollDice()
            local data = b:serialize()

            local b2 = Board:new()
            assert.is_true(b2:load(data))
            assert.are.equal(b.round, b2.round)
            assert.are.equal(b.turn_state, b2.turn_state)
            assert.are.equal(#b.dice, #b2.dice)
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
