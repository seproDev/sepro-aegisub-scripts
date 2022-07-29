script_name = "Variety Effects"
script_description = "Various macros useful when subbing variety shows"
script_version = '1.0.1'
script_author = "serpo"

has_subinspector, SubInspector = pcall(require, "SubInspector.Inspector")
require("karaskel")

function fade_in(subs, sel)
    currentFrame = aegisub.project_properties().video_position
    currentTimestamp = math.floor((aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    for _, i in ipairs(sel) do
        local line = subs[i]
        -- Add fad tags if not already present
        if not line.text:match("\\fad%(") then
            line.text = "{\\fad(0,0)}" .. line.text
            line.text = line.text:gsub("{\\fad%(0,0%)}{\\", "{\\fad(0,0)\\")
        end
        -- Overwrite fade in tim 
        fadeInTime = currentTimestamp - line.start_time
        line.text = line.text:gsub("\\fad%(%d+,(%d+)%)", "\\fad(" .. fadeInTime .. ",%1)")
        subs[i] = line
    end
    aegisub.set_undo_point(script_name)
    return sel
end

function fade_out(subs, sel)
    currentFrame = aegisub.project_properties().video_position
    currentTimestamp = math.floor((aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    for _, i in ipairs(sel) do
        local line = subs[i]
        -- Add fad tags if not already present
        if not line.text:match("\\fad%(") then
            line.text = "{\\fad(0,0)}" .. line.text
            line.text = line.text:gsub("{\\fad%(0,0%)}{\\", "{\\fad(0,0)\\")
        end
        -- Overwrite fade in tim 
        fadeOutTime = line.end_time - currentTimestamp
        line.text = line.text:gsub("\\fad%((%d+),%d+%)", "\\fad(%1," .. fadeOutTime .. ")")
        subs[i] = line
    end
    aegisub.set_undo_point(script_name)
    return sel
end

-- from unanimated. Should probably be rewritten
local function setPos(subs, text, line)
    st = nil
    defst = nil
    for g = 1, #subs do
        if subs[g].class == "info" then
            local k = subs[g].key
            local v = subs[g].value
            if k == "PlayResX" then
                resx = v
            end
            if k == "PlayResY" then
                resy = v
            end
        end
        if resx == nil then
            resx = 0
        end
        if resy == nil then
            resy = 0
        end
        if subs[g].class == "style" then
            local s = subs[g]
            if s.name == line.style then
                st = s
                break
            end
            if s.name == "Default" then
                defst = s
            end
        end
        if subs[g].class == "dialogue" then
            if defst then
                st = defst
            else
                t_error("Style '" .. line.style .. "' not found.\nStyle 'Default' not found. ", 1)
            end
            break
        end
    end
    if st then
        acleft = st.margin_l
        if line.margin_l > 0 then
            acleft = line.margin_l
        end
        acright = st.margin_r
        if line.margin_r > 0 then
            acright = line.margin_r
        end
        acvert = st.margin_t
        if line.margin_t > 0 then
            acvert = line.margin_t
        end
        acalign = st.align
        if text:match("\\an%d") then
            acalign = text:match("\\an(%d)")
        end
        aligntop = "789"
        alignbot = "123"
        aligncent = "456"
        alignleft = "147"
        alignright = "369"
        alignmid = "258"
        if alignleft:match(acalign) then
            horz = acleft
        elseif alignright:match(acalign) then
            horz = resx - acright
        elseif alignmid:match(acalign) then
            horz = resx / 2
        end
        if aligntop:match(acalign) then
            vert = acvert
        elseif alignbot:match(acalign) then
            vert = resy - acvert
        elseif aligncent:match(acalign) then
            vert = resy / 2
        end
    end
    if horz > 0 and vert > 0 then
        if not text:match("^{\\") then
            text = "{\\rel}" .. text
        end
        text = text:gsub("^({\\[^}]-)}", "%1\\pos(" .. horz .. "," .. vert .. ")}"):gsub("\\rel", "")
    end
    return text
end

function apply_gradient(subs, sel)
    local currentFrame = aegisub.project_properties().video_position
    local currentTimestamp = math.floor((aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    local meta, styles = karaskel.collect_head(subs, false)
    local lineHeight = 2

    local i = sel[1]
    local line = subs[i]
    -- Get c1 and c2
    line.text = line.text:gsub("\\1c", "\\c")
    c1 = line.text:match("\\c(&[^\\}]-)[\\}]") or styles[line.style].color1
    c2 = line.text:match("\\2c(&[^\\}]-)[\\}]") or styles[line.style].color2
    -- Get clip as bounding box or use SubInspector
    local left, top, right, bottom = line.text:match("\\clip%(([%d%.%-]*),([%d%.%-]*),([%d%.%-]*),([%d%.%-]*)%)")
    if left then
        bounds = {tonumber(left), tonumber(top), tonumber(right), tonumber(bottom)}
    elseif has_subinspector then
        assi, msg = SubInspector(subs)
        boundings, times = assi:getBounds({line})
        bounds = {boundings[1].x, boundings[1].y, boundings[1].x + boundings[1].w, boundings[1].y + boundings[1].h}
    else
        error("No clip given and SubInspector not installed")
        return
    end
    if bounds[1] > bounds[3] then
        tmp = bounds[1]
        bounds[1] = bounds[3]
        bounds[3] = tmp
    end

    if bounds[2] > bounds[4] then
        tmp = bounds[2]
        bounds[2] = bounds[4]
        bounds[4] = tmp
    end

    -- get line text without c1, c2 and clip
    local baseLine = line.text:gsub("\\c&[^\\}]+", ""):gsub("\\2c&[^\\}]+", ""):gsub("\\clip%([^%)]+%)", ""):gsub("{}", "")
    baseLine = setPos(subs, baseLine, line)

    for y = bounds[2], bounds[4], lineHeight do
        local progress = (y - bounds[2]) / (bounds[4] - bounds[2])
        local currentColor = util.interpolate_color(progress, c1, c2)
        local coloredLine = "{\\c" .. currentColor .. "}" .. baseLine
        local clippedLine = "{\\clip(" .. tostring(bounds[1]) .. "," .. tostring(y) .. "," .. tostring(bounds[3]) .. "," .. tostring(y + lineHeight) .. ")}" .. coloredLine
        local finalLine = clippedLine:gsub("}{", "")
        newLine = util.deep_copy(line)
        newLine.text = finalLine
        subs.insert(i + 1, newLine)
    end
    subs.delete(i)

    aegisub.set_undo_point(script_name)
    return sel
end

aegisub.register_macro(script_name .. "/Fade in", "Fade in to current frame", fade_in)
aegisub.register_macro(script_name .. "/Fade out", "Fade out of current frame", fade_out)
aegisub.register_macro(script_name .. "/Apply Gradient", "Applies vertical gradient based on c1 and c2", apply_gradient)
