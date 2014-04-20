--[[
Copyright 2014 Seth VanHeulen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- addon information

_addon.name = 'digger'
_addon.version = '1.3.3'
_addon.command = 'digger'
_addon.author = 'Seth VanHeulen'

-- modules

config = require('config')
require('pack')

-- default settings

defaults = {}
defaults.delay = {}
defaults.delay.area = 60
defaults.delay.lag = 3
defaults.delay.dig = 15
defaults.fatigue = {}
defaults.fatigue.date = os.date('!%Y-%m-%d', os.time() + 32400)
defaults.fatigue.remaining = 100
defaults.accuracy = {}
defaults.accuracy.successful = 0
defaults.accuracy.total = 0

settings = config.load(defaults)

-- global constants

fail_message = {
    [7208]=true, [7250]=true, [7227]=true, [7536]=true, [7194]=true,
    [7682]=true, [7198]=true, [7256]=true, [7216]=true, [7035]=true
}
success_message = {
    [6379]=true, [6393]=true, [6406]=true, [6552]=true, [7377]=true,
    [7692]=true, [7717]=true
}
ease_message = {
    [7283]=true, [7325]=true, [7302]=true, [7611]=true, [7269]=true,
    [7757]=true, [7273]=true, [7331]=true, [7291]=true, [7110]=true
}
chocobo_zone = {
    [2]=true,   [4]=true,   [51]=true,  [52]=true,  [100]=true,
    [101]=true, [102]=true, [103]=true, [104]=true, [105]=true,
    [106]=true, [107]=true, [108]=true, [109]=true, [110]=true,
    [114]=true, [115]=true, [116]=true, [117]=true, [118]=true,
    [119]=true, [120]=true, [121]=true, [123]=true, [124]=true,
    [125]=true
}

-- buff helper function

function get_chocobo_buff()
    for _,buff_id in pairs(windower.ffxi.get_player().buffs) do
        if buff_id == 252 then
            return true
        end
    end
    return false
end

-- inventory helper function

function get_gysahl_count()
    local count = 0
    for _,item in pairs(windower.ffxi.get_items().inventory) do
        if item.id == 4545 and item.status == 0 then
            count = count + item.count
        end
    end
    return count
end

-- stats helper functions

function update_stats(count)
    local today = os.date('!%Y-%m-%d', os.time() + 32400)
    if settings.fatigue.date ~= today then
        settings.fatigue.date = today
        settings.fatigue.remaining = 100
    end
    if count < 1 then
        settings.accuracy.total = settings.accuracy.total + 1
    end
    if count < 0 then
        settings.accuracy.successful = settings.accuracy.successful + 1
    end
    settings.fatigue.remaining = settings.fatigue.remaining + count
    settings:save('all')
end

function display_stats()
    local accuracy = (settings.accuracy.successful / settings.accuracy.total) * 100
    windower.add_to_chat(207, 'dig accuracy: %d%% (%d/%d), items until fatigued: %d, gysahl greens remaining: %d':format(accuracy, settings.accuracy.successful, settings.accuracy.total, settings.fatigue.remaining, get_gysahl_count()))
end

-- event callback functions

function check_zone_change(new_zone_id, old_zone_id)
    if chocobo_zone[new_zone_id] then
        windower.send_command('timers c "Chocobo Area Delay" %d down':format(settings.delay.area + settings.delay.lag))
    else
        windower.send_command('timers d "Chocobo Area Delay"')
    end
    windower.send_command('timers d "Chocobo Dig Delay"')
end

function check_incoming_chunk(id, original, modified, injected, blocked)
    if id == 0x2A and windower.ffxi.get_player().id == original:unpack('I', 5) then
        local message_id = original:unpack('H', 27) % 0x8000
        if success_message[message_id] and get_chocobo_buff() then
            update_stats(-1)
            display_stats()
        elseif ease_message[message_id] then
            update_stats(1)
        end
    elseif id == 0x2F and settings.delay.dig > 0 and windower.ffxi.get_player().id == original:unpack('I', 5) then
        windower.send_command('timers c "Chocobo Dig Delay" %d down':format(settings.delay.dig))
    elseif id == 0x36 and windower.ffxi.get_player().id == original:unpack('I', 5) then
        local message_id = original:unpack('H', 11) % 0x8000
        if fail_message[message_id] then
            update_stats(0)
            display_stats()
        end
    end
end

function digger_command(...)
    if #arg == 1 and arg[1]:lower() == 'reset' then
        windower.add_to_chat(200, 'resetting dig accuracy statistics')
        settings.accuracy.successful = 0
        settings.accuracy.total = 0
        settings:save('all')
    elseif #arg == 2 and arg[1]:lower() == 'rank' then
        local rank = arg[2]:lower()
        if rank == 'amateur' then
            settings.delay.area = 60
            settings.delay.dig = 15
        elseif rank == 'recruit' then
            settings.delay.area = 55
            settings.delay.dig = 10
        elseif rank == 'initiate' then
            settings.delay.area = 50
            settings.delay.dig = 5
        elseif rank == 'novice' then
            settings.delay.area = 45
            settings.delay.dig = 0
        elseif rank == 'apprentice' then
            settings.delay.area = 40
            settings.delay.dig = 0
        elseif rank == 'journeyman' then
            settings.delay.area = 35
            settings.delay.dig = 0
        elseif rank == 'craftsman' then
            settings.delay.area = 30
            settings.delay.dig = 0
        elseif rank == 'artisan' then
            settings.delay.area = 25
            settings.delay.dig = 0
        elseif rank == 'adept' then
            settings.delay.area = 20
            settings.delay.dig = 0
        elseif rank == 'veteran' then
            settings.delay.area = 15
            settings.delay.dig = 0
        elseif rank == 'expert' then
            settings.delay.area = 10
            settings.delay.dig = 0
        else
            windower.add_to_chat(167, 'invalid digging rank: %s':format(rank))
            return
        end
        windower.add_to_chat(200, 'setting digging rank to %s: area delay = %d seconds, dig delay = %d seconds':format(rank, settings.delay.area, settings.delay.dig))
        settings:save('all')
    else
        windower.add_to_chat(167, 'usage: digger rank <crafting rank>')
        windower.add_to_chat(167, '        digger reset')
    end
end

-- register event callbacks

windower.register_event('zone change', check_zone_change)
windower.register_event('incoming chunk', check_incoming_chunk)
windower.register_event('addon command', digger_command)
