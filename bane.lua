OFFSETS = { 1, 85, 151, 216, 300 }
DELAY = 200
HIGH_POWER = 80
LOW_POWER = 10
LAST_POSITION = 0
LED_MODE = 0
INC_POOL = 0

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

ws2812.init()

buf = ws2812.newBuffer(300, 3)
buf_venom_fwd = ws2812.newBuffer(300, 3)
buf_venom_rev = ws2812.newBuffer(300, 3)
buf_rainbow_fwd = ws2812.newBuffer(300, 3)
buf_rainbow_rev = ws2812.newBuffer(300, 3)

function rotary_status(type, pos, when)
    --print("0 / Position=" .. pos .. " event type=" .. type .. " time=" .. when)
    if type == 8 then
	local pos = rotary.getpos(0)
	if (pos - LAST_POSITION) > 0 then
	    DELAY = DELAY + 2
	else
	    DELAY = math.max(1, DELAY - 2)
	end
	LAST_POSITION = pos
    end
    if type == 16 then
        LED_MODE = (LED_MODE + 1) % 2
	if LED_MODE == 0 then
	    DELAY = 200
	else
	    DELAY = 50
	end
	print("MODE CHANGE " .. LED_MODE)
    end
end

function rotary_setup()
    rotary.setup(0, 1, 2, 7)
    rotary.on(0, rotary.ALL, rotary_status)

    rotary.setup(1, 5, 6, 3)
    rotary.on(1, rotary.ALL, rotary_status)
    print("# rotary setup complete")
end

function buffer_setup()
    local green = {0, 61, 127, 193, 255, 255, 255, 255, 255, 255, 255, 255, 255, 193, 127, 61, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    local red   = {255, 255, 255, 255, 255, 183, 127, 61, 0, 0, 0, 0, 0, 0, 0, 0, 0, 61, 127, 193, 255, 255, 255, 255, 255}
    local blue  = {0, 0, 0, 0, 0, 0, 0, 0, 0, 61, 127, 193, 255, 255, 255, 255, 255, 255, 255, 255, 255, 193, 127, 61, 0}

    buf:fill(0, 0, 0)

    buf_venom_fwd:fill(0, 0, 0)
    buf_venom_rev:fill(0, 0, 0)

    buf_rainbow_fwd:fill(0, 0, 0)
    buf_rainbow_rev:fill(0, 0, 0)

    local ts = tablelength(red)

    for i=1,300 do
        local power = LOW_POWER
        if (i % 4) == 0 then
            power = HIGH_POWER
        end
        buf_venom_fwd:set(i, power, 0, 0)
        buf_venom_rev:set(301 - i, power, 0, 0)

        local rainbow_i = (i % ts) + 1
	local divider = 3
        buf_rainbow_fwd:set(i, green[rainbow_i] / divider, red[rainbow_i] / divider, blue[rainbow_i] / divider)
        buf_rainbow_rev:set(301 - i, green[rainbow_i] / divider, red[rainbow_i] / divider, blue[rainbow_i] / divider)
    end
end

function frame_tic()
    if INC_POOL ~= 0 then
	if LED_MODE == 0 then
	    buf_venom_fwd:shift(-1 * INC_POOL, ws2812.SHIFT_CIRCULAR)
	    buf_venom_rev:shift(INC_POOL, ws2812.SHIFT_CIRCULAR)
	else
	    buf_rainbow_fwd:shift(-1 * INC_POOL, ws2812.SHIFT_CIRCULAR)
	    buf_rainbow_rev:shift(INC_POOL, ws2812.SHIFT_CIRCULAR)
	end
	INC_POOL = 0
    end

    for i, v in ipairs(OFFSETS) do
        if i > 4 then
            break
        end
        local target_buf = nil
        if LED_MODE == 0 then
            target_buf = buf_venom_fwd
            if (i % 2) == 0 then
                target_buf = buf_venom_rev
            end
        else
            target_buf = buf_rainbow_fwd
            if (i % 2) == 0 then
                target_buf = buf_rainbow_rev
            end
        end

        local excerpt = target_buf:sub(v, OFFSETS[i+1])
        buf:replace(excerpt, v)
    end

    ws2812.write(buf)

    fps = tmr.create():alarm(50, tmr.ALARM_SINGLE, frame_tic)
end

function shift()
    INC_POOL = INC_POOL + 1
    tmr.create():alarm(DELAY, tmr.ALARM_SINGLE, shift)
end

rotary_setup()
buffer_setup()
frame_tic()
tmr.create():alarm(DELAY, tmr.ALARM_SINGLE, shift)
