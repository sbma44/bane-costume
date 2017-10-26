OFFSETS = { 1, 85, 151, 216, 300 }
DIVIDER = 3
HIGH_POWER = 80
LOW_POWER = 10
LAST_POSITION = 0
LED_MODE = 0
INC_POOL = 0
FAUCET = 200
QUAD_COUNT = 0
GREEN = {0, 61, 127, 193, 255, 255, 255, 255, 255, 255, 255, 255, 255, 193, 127, 61, 0, 0, 0, 0, 0, 0, 0, 0, 0}
RED   = {255, 255, 255, 255, 255, 183, 127, 61, 0, 0, 0, 0, 0, 0, 0, 0, 0, 61, 127, 193, 255, 255, 255, 255, 255}
BLUE  = {0, 0, 0, 0, 0, 0, 0, 0, 0, 61, 127, 193, 255, 255, 255, 255, 255, 255, 255, 255, 255, 193, 127, 61, 0}

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
	-- only fire every 4th event
	QUAD_COUNT = (QUAD_COUNT + 1) % 4
	if QUAD_COUNT ~= 0 then
	    return
	end

	local pos = rotary.getpos(0)

	if LED_MODE == 2 then
	    color_count = tablelength(RED)
	    if (pos - LAST_POSITION) > 0 then
		INC_POOL = INC_POOL + 1
	    else
		INC_POOL = INC_POOL - 1
	    end
	    INC_POOL = INC_POOL % color_count
	    if INC_POOL < 0 then
		INC_POOL = INC_POOL + color_count
	    end
	    buf:fill(GREEN[INC_POOL + 1] / DIVIDER, RED[INC_POOL + 1] / DIVIDER, BLUE[INC_POOL + 1] / DIVIDER)
	    ws2812.write(buf)
	else
	    if (pos - LAST_POSITION) > 0 then
		FAUCET = FAUCET + 20
	    else
		FAUCET = math.max(0, FAUCET - 20)
	    end
	end
	LAST_POSITION = pos
    end

    if type == 16 then
        LED_MODE = (LED_MODE + 1) % 3
	if LED_MODE == 0 then
	    FAUCET = 200
	elseif LED_MODE == 1 then
	    FAUCET = 500
	elseif LED_MODE == 2 then
	    INC_POOL = 0
	end
	print("MODE CHANGE " .. LED_MODE)
    end
end

function rotary_setup()
    rotary.setup(0, 1, 2, 7)
    rotary.on(0, rotary.ALL, rotary_status)
    print("# rotary setup complete")
end

function buffer_setup()

    buf:fill(0, 0, 0)

    buf_venom_fwd:fill(0, 0, 0)
    buf_venom_rev:fill(0, 0, 0)

    buf_rainbow_fwd:fill(0, 0, 0)
    buf_rainbow_rev:fill(0, 0, 0)

    local ts = tablelength(RED)

    for i=1,300 do
        local power = LOW_POWER
        if (i % 4) == 0 then
            power = HIGH_POWER
        end
        buf_venom_fwd:set(i, power, 0, 0)
        buf_venom_rev:set(301 - i, power, 0, 0)

        local rainbow_i = (i % ts) + 1
        buf_rainbow_fwd:set(i, GREEN[rainbow_i] / DIVIDER, RED[rainbow_i] / DIVIDER, BLUE[rainbow_i] / DIVIDER)
        buf_rainbow_rev:set(301 - i, GREEN[rainbow_i] / DIVIDER, RED[rainbow_i] / DIVIDER, BLUE[rainbow_i] / DIVIDER)
    end
end

function frame_tic()
    if LED_MODE == 2 then
	fps = tmr.create():alarm(250, tmr.ALARM_SINGLE, frame_tic)
	return
    end

    INC_POOL = INC_POOL + FAUCET

    if INC_POOL > 0 then
	local shift_amt = math.floor(INC_POOL / 1000)
	if shift_amt > 0 then
	    if LED_MODE == 0 then
		buf_venom_fwd:shift(-1 * shift_amt, ws2812.SHIFT_CIRCULAR)
		buf_venom_rev:shift(shift_amt, ws2812.SHIFT_CIRCULAR)
	    else
		buf_rainbow_fwd:shift(-1 * shift_amt, ws2812.SHIFT_CIRCULAR)
		buf_rainbow_rev:shift(shift_amt, ws2812.SHIFT_CIRCULAR)
	    end
	    INC_POOL = INC_POOL - (1000 * shift_amt)
	end
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
        elseif LED_MODE == 1 then
	    target_buf = buf_rainbow_fwd
            if (i % 2) == 0 then
                target_buf = buf_rainbow_rev
            end
        end

        local excerpt = target_buf:sub(v, OFFSETS[i+1])
        buf:replace(excerpt, v)
    end

    ws2812.write(buf)

    fps = tmr.create():alarm(25, tmr.ALARM_SINGLE, frame_tic)
end

rotary_setup()
buffer_setup()
frame_tic()
