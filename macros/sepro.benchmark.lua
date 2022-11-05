script_name = "Benchmark"
script_description = "Banchmark subtitle performance"
script_version = '0.0.1'
script_author = "sepro"
script_namespace = "sepro.benchmark"

local haveDepCtrl, DependencyControl, depCtrl = pcall(require, "l0.DependencyControl")
if haveDepCtrl then
    depCtrl = DependencyControl {
        feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json"
    }
end

local function showMsg(msg)
    aegisub.dialog.display({{
        class = "label",
        label = msg,
        x = 0,
        y = 0,
        width = 1,
        height = 1
    }}, {"Okay"})
end

local function showError(msg)
    showMsg("Error: " .. msg)
end

function benchmark(subs, sel)
    -- Check if get_frame is available
    if not aegisub.get_frame then
        showError("get_frame is not available. Please update Aegisub to a newer version.")
        return sel
    end
    -- Check if video is available
    if not aegisub.video_size() then
        showError("Video is not available. Please open a video file.")
        return sel
    end

    -- Find start and end time of selected lines
    local t1, t2 = math.huge, 0
    for _, i in ipairs(sel) do
        t1 = math.min(t1, subs[i].start_time)
        t2 = math.max(t2, subs[i].end_time)
    end
    local start_frame = aegisub.frame_from_ms(t1)
    local end_frame = aegisub.frame_from_ms(t2) - 1

    frame_times = {}
    local precision = 10
    -- go through frames
    for frame_number = start_frame, end_frame, 1 do
        -- fetch frame beforehand to cache
        local frame = aegisub.get_frame(frame_number, false)
        -- actually time subtitle drawing
        local x = os.clock()
        for run = 1, precision,1 do
            frame = aegisub.get_frame(frame_number, true)
        end
        local y = os.clock()
        -- Keep memory consumption under control
        frame = nil
        collectgarbage()
        -- save time
        local frame_time = (y - x) * 1000 / precision
        frame_times[frame_number - start_frame + 1] = frame_time
    end
    worst_frame_time = math.max(unpack(frame_times))

    average_frame_time = 0
    for _, frame_time in ipairs(frame_times) do
        average_frame_time = average_frame_time + frame_time
    end
    average_frame_time = average_frame_time / #frame_times

    table.sort(frame_times)
    median_frame_time = frame_times[math.floor(#frame_times / 2)]

    local msg = "Worst frame time: " .. string.format("%.2f", worst_frame_time) .. " ms\n"
    msg = msg .. "Average frame time: " .. string.format("%.2f", average_frame_time) .. " ms\n"
    msg = msg .. "Median frame time: " .. string.format("%.2f", median_frame_time) .. " ms\n"

    showMsg(msg)
    return sel
end


if haveDepCtrl then
    depCtrl:registerMacros({{"Benchmark", "Run performance benchmark", benchmark}})
else
    aegisub.register_macro("Benchmark", "Run performance benchmark", benchmark)
end
