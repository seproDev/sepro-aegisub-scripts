script_name = "QuickFade"
script_description = "Functions for fading in and out of the current frame"
script_version = '1.0.0'
script_author = "sepro"
script_namespace = "sepro.fade"

local haveDepCtrl, DependencyControl, depCtrl = pcall(require, "l0.DependencyControl")
if haveDepCtrl then
    depCtrl = DependencyControl {
        feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json"
    }
end

function fade_in(subs, sel)
    local currentFrame = aegisub.project_properties().video_position
    local currentTimestamp = math.floor(
        (aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    for _, i in ipairs(sel) do
        local line = subs[i]
        -- Add fad tags if not already present
        if not line.text:match("\\fad%(") then
            line.text = "{\\fad(0,0)}" .. line.text
            line.text = line.text:gsub("{\\fad%(0,0%)}{\\", "{\\fad(0,0)\\")
        end
        -- Overwrite fade in time
        local fadeInTime = currentTimestamp - line.start_time
        fadeInTime = math.max(0, fadeInTime)
        line.text = line.text:gsub("\\fad%(%d+,(%d+)%)", "\\fad(" .. fadeInTime .. ",%1)")
        subs[i] = line
    end
    aegisub.set_undo_point(script_name)
    return sel
end

function fade_out(subs, sel)
    local currentFrame = aegisub.project_properties().video_position
    local currentTimestamp = math.floor(
        (aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    for _, i in ipairs(sel) do
        local line = subs[i]
        -- Add fad tags if not already present
        if not line.text:match("\\fad%(") then
            line.text = "{\\fad(0,0)}" .. line.text
            line.text = line.text:gsub("{\\fad%(0,0%)}{\\", "{\\fad(0,0)\\")
        end
        -- Overwrite fade out time
        local fadeOutTime = line.end_time - currentTimestamp
        fadeOutTime = math.max(0, fadeOutTime)
        line.text = line.text:gsub("\\fad%((%d+),%d+%)", "\\fad(%1," .. fadeOutTime .. ")")
        subs[i] = line
    end
    aegisub.set_undo_point(script_name)
    return sel
end

if haveDepCtrl then
    depCtrl:registerMacros({{"Fade in", "Fade in to current frame", fade_in},
                            {"Fade out", "Fade out of current frame", fade_out}})
else
    aegisub.register_macro(script_name .. "/Fade in", "Fade in to current frame", fade_in)
    aegisub.register_macro(script_name .. "/Fade out", "Fade out of current frame", fade_out)
end
