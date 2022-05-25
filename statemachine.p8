pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

game_state_stack = {}
player_state_stack = {}
message_state_stack = {}

move_draw_queue = {}

level = 0

player = {
    x = 64,
    y = 64,
    sprite = 1,
}

function _init()
    game_state_stack = state_stack()
    player_state_stack = state_stack()
    message_state_stack = state_stack()

    game_state_stack:push(game_planning_state())
end

function _update60()
    game_state_stack:update()
end

function _draw()
    cls()
    game_state_stack:draw() 
end


--STATE STACK

function state_stack()
    return {
        entered = false,
        stack = {},
        obj_ref = nil,

        has_states = function(self)
            return count(self.stack) > 0
        end,

        push = function(self, new_state)
            if self.entered then
                self.entered = false
                self.stack[1]:exit(self.obj_ref)
            end
            add(self.stack, new_state, 1) 
        end,

        push_back = function(self, new_state)
            add(self.stack, new_state)
        end,

        pop = function(self)
            local popped = self.stack[1]
            del(self.stack, self.stack[1])
            if self.entered then
                self.entered = false
                popped:exit(self.obj_ref)
            end
        end,

        swap = function(self, new_state)
            self:pop()
            self:push(new_state)
        end,

        clear = function(self)
            if self.entered then
                self.entered = false
                self.stack[1]:exit(self.obj_ref)
            end
            self.stack = { }
        end,

        fresh = function(self, new_state)
            self:clear()
            self:push(new_state)
        end,

        update = function(self, obj)
            if count(self.stack) == 0 then 
                return
            end
            while not self.entered do
                self.entered = true 
                self.obj_ref = obj
                self.stack[1]:enter(self.obj_ref)
            end
            self.stack[1]:update(obj)
        end,

        draw = function(self)
            if count(self.stack) == 0 then
                return
            end
            self.stack[1]:draw(self.obj_ref)
        end
    }
end


--GAME STATES

function game_planning_state()
    local add_move = function(p_spr, q_spr, x_dir, y_dir)
        add(move_draw_queue, q_spr)
        player_state_stack:push_back(move_dir_state(p_spr, x_dir, y_dir))
    end
    return {
        enter = function(obj) end,
        update = function(obj)
            if count(move_draw_queue) < 4 then
                if (btnp(2)) add_move(1, 17, 0, -1)
                if (btnp(3)) add_move(2, 18, 0, 1)
                if (btnp(0)) add_move(3, 19, -1, 0)
                if (btnp(1)) add_move(4, 20, 1, 0)
            end
            if (btnp(4)) then
                move_queue = {}
                player_state_stack:clear()
            end
            if btnp(5) and player_state_stack:has_states() then
                game_state_stack:push(game_moving_state())
            end
        end,
        draw = function(obj)
            draw_level()
            draw_player()
            draw_move_queue()
        end,
        exit = function(obj) end
    }
end

function game_showing_messages_state()
    return {
        enter = function() end,
        update = function()
            message_state_stack:update()
            if not message_state_stack:has_states() then
                game_state_stack:pop()
            end
        end,
        draw = function()
            draw_level()
            draw_player()
            draw_move_queue()
            message_state_stack:draw()
        end,
        exit = function() end
    }
end

function game_moving_state()
    return {
        enter = function(obj) end,
        update = function(obj)
            if player_state_stack:has_states() then
                player_state_stack:update(player)
            else    
                game_state_stack:pop()
            end
        end,
        draw = function(obj)
            draw_level()
            draw_player()
            draw_move_queue()
        end,
        exit = function(obj) end
    }
end

function game_loading_state()
    local t = 0
    return {
        enter = function(obj) end,
        update = function(obj)
            t += 1
            if t == 60 then
                game_state_stack:fresh(game_planning_state())
            end
        end,
        draw = function(obj)
            print('loading', 48, 48)
        end,
        exit = function(obj)
            level += 1
            move_queue = {}
            player_state_stack:clear()
            message_state_stack:clear()
            player.x = 64
            player.y = 64
        end
    }
end


--MESSAGE STATES

function message_burst_state(messages)
    local msgs = {}
    return {
        enter = function(obj)
            message_state_stack:pop()
            for i = 1, count(messages) do
                add(msgs, messages[i])
                message_state_stack:push(message_state(copy(msgs)))
            end
        end,
        update = function(obj) end,
        draw = function(obj) end,
        exit = function(obj) end
    }
end

function message_state(msgs)
    return {
        enter = function(obj) end,
        update = function(obj)
            if btnp(4) or btnp(5) then
                message_state_stack:pop()
            end
        end,
        draw = function(obj)
            draw_messages(msgs)
        end,
        exit = function(obj) end
    }
end


--MOVEMENT STATES

function move_dir_state(player_sprite, x_dir, y_dir)
    return {
        enter = function(self, obj)
            obj.sprite = player_sprite
        end,
        update = function(self, obj)
            if wall_collision(obj.x, obj.y, x_dir, y_dir) then
                player_state_stack:pop()
            else
                obj.x += x_dir
                obj.y += y_dir
            end
            if win_collision(obj.x, obj.y) then
                game_state_stack:fresh(game_loading_state())
            elseif msg_collision(obj.x, obj.y) then 
                mset(obj.x\8 + level * 16, obj.y\8, 0)
                game_state_stack:push(game_showing_messages_state())
                message_state_stack:push(message_burst_state({
                    'message 1',
                    'message 2',
                    'message 3'
                }))
            end
        end,
        exit = function(self, obj)
            del(move_draw_queue, move_draw_queue[1])
        end
    }
end


--COLLISIONS

function win_collision(x, y)
    local level_off = level * 16
    return x % 8 == 0 and y % 8 == 0 and mget(x/8 + level_off, y/8) == 6
end

function msg_collision(x, y)
    local level_off = level * 16
    return x % 8 == 0 and y % 8 == 0 and mget(x/8 + level_off, y/8) == 21
end

function wall_collision(x, y, x_dir, y_dir)
    local level_off = level * 16
    local coll_off_x = x_dir == 0 and 0 or x_dir > 0 and 8 or -1
    local coll_off_y = y_dir == 0 and 0 or y_dir > 0 and 8 or -1
    return mget((x + coll_off_x)\8 + level_off, (y + coll_off_y)\8) == 5
end


--DRAWING

function draw_level()
    map(0 + level * 16,0,0,0,16,16)
end

function draw_player()
    spr(player.sprite, player.x, player.y)
end

function draw_move_queue()
    print('queue', 104, 4)
    line(104, 12, 122, 12, 7)
    rect(101, 1, 125, 55, 7)
    for i = 0, count(move_draw_queue) - 1 do
        local y = 15 + i * 10
        spr(move_draw_queue[i + 1], 109, y)
    end
end

function draw_messages(msgs)
    local x1 = 11 
    local y1 = 20
    local w = 50
    local h = 20
    for i = 0, count(msgs) - 1 do
        local off = i * 8 
        rectfill(x1 + off, y1 + off, x1 + off + w, y1 + off + h, 13)
        rect(x1 + off, y1 + off, x1 + off + w, y1 + off + h, 5)
        print(msgs[i + 1], x1 + off + 4, y1 + off + 4, 7)
    end
end


--UTIL

function copy(tbl)
    local cpy = {}
    for k, v in pairs(tbl) do
        cpy[k] = v
    end
    return cpy
end

__gfx__
00000000000880000008800000080000000080009999999400063000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008888000008800000880000000088009ffffff400063300000000000000000000000000000000000000000000000000000000000000000000000000
00700700088888800008800008880000000088809ffffff400063330000000000000000000000000000000000000000000000000000000000000000000000000
00077000888888880008800088888888888888889ffffff400063300000000000000000000000000000000000000000000000000000000000000000000000000
00077000000880008888888888888888888888889ffffff400063000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000880000888888008880000000088809ffffff400060000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000880000088880000880000000088009ffffff400060000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000880000008800000080000000080009444444400060000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000007700000070000000070000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007777000007700000770000000077000677876000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077777700007700007770000000077706777877600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777770007700077777777777777776777877600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770007777777777777777777777776777777600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000777777007770000000077700667876000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000077770000770000000077000006660000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000770000007700000070000000070000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0505050505050505050505000000000005050505050505050505050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000050005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000005000000000005000000000005000000000000000500050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000005000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000150000000005000000000005000000050000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000500000005000005000000000005000000000000050000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500060000050000000005000000000005000000000000050000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000500000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500050000000000000005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000500000005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000600150000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000005000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000000000005000000000005000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050505050505000000000005050505050505050505050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
