script_name = "QuickGradient"
script_description = "Applies vertical gradient based on 1c and 2c"
script_version = '1.0.0'
script_author = "sepro"
script_namespace = "sepro.gradient"

local haveDepCtrl, DependencyControl, depCtrl = pcall(require, "l0.DependencyControl")
local SubInspector, haveSubInsp, advancedStyles, color
if haveDepCtrl then
    depCtrl = DependencyControl {
        feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json",
        {{
            "SubInspector.Inspector",
            version = "0.7.2",
            url = "https://github.com/TypesettingTools/SubInspector",
            feed = "https://raw.githubusercontent.com/TypesettingTools/SubInspector/master/DependencyControl.json"
        }, {
            "sepro.color",
            version = "1.0.0",
            url = "https://github.com/seproDev/sepros-aegisub-scripts",
            feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json"
        }, "karaskel"}
    }
    SubInspector, color = depCtrl:requireModules()
    haveSubInsp = true
    advancedStyles = depCtrl:getConfigHandler({}, "advancedStyles")
else
    haveSubInsp, SubInspector = pcall(require, "SubInspector.Inspector")
    color = require("sepro.color")
    require("karaskel")
end

local function showError(msg)
    aegisub.dialog.display({{
        class = "label",
        label = "Error: " .. msg,
        x = 0,
        y = 0,
        width = 1,
        height = 1
    }}, {"Okay"})

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
                showError("Style '" .. line.style .. "' not found.\nStyle 'Default' not found. ")
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
    local currentTimestamp = math.floor(
        (aegisub.ms_from_frame(currentFrame + 1) + aegisub.ms_from_frame(currentFrame)) / 2)
    local meta, styles = karaskel.collect_head(subs, false)

    local curIt = 1
    for _, i in ipairs(sel) do
        local line = subs[i]

        -- Get c1 and c2
        line.text = line.text:gsub("\\1c", "\\c")
        local c1 = line.text:match("\\c(&[^\\}]-)[\\}]") or styles[line.style].color1
        local c2 = line.text:match("\\2c(&[^\\}]-)[\\}]") or styles[line.style].color2

        -- Calculate deltaE
        local r1, g1, b1, a1 = util.extract_color(c1)
        local r2, g2, b2, a2 = util.extract_color(c2)
        local deltaE = color.RGB_deltaE_2000(r1, g1, b1, r2, g2, b2)

        -- Get clip as bounding box or use SubInspector
        local left, top, right, bottom = line.text:match("\\clip%(([%d%.%-]*),([%d%.%-]*),([%d%.%-]*),([%d%.%-]*)%)")
        local bounds
        if left then
            bounds = {tonumber(left), tonumber(top), tonumber(right), tonumber(bottom)}
        elseif haveSubInsp then
            local assi, msg = SubInspector(subs)
            local boundings, times = assi:getBounds({line})
            bounds = {boundings[1].x, boundings[1].y, boundings[1].x + boundings[1].w, boundings[1].y + boundings[1].h}
        else
            showError("No clip given and SubInspector not installed")
            return
        end
        if bounds[1] > bounds[3] then
            local tmp = bounds[1]
            bounds[1] = bounds[3]
            bounds[3] = tmp
        end

        if bounds[2] > bounds[4] then
            local tmp = bounds[2]
            bounds[2] = bounds[4]
            bounds[4] = tmp
        end

        -- expand horizontal bounds
        bounds[1] = math.max(0, bounds[1] - 3)
        bounds[3] = bounds[3] + 3

        -- Calculate lineHeight based on detlaE and y height
        local yHeight = bounds[4] - bounds[2]
        local lineHeight = math.min(math.max(math.floor(yHeight / deltaE), 2), 15)

        -- get line text without c1, c2 and clip
        local baseLine = line.text:gsub("\\c&[^\\}]+", ""):gsub("\\2c&[^\\}]+", ""):gsub("\\clip%([^%)]+%)", ""):gsub(
            "{}", "")
        baseLine = setPos(subs, baseLine, line)

        local linesAdded = 0
        for y = bounds[2], bounds[4], lineHeight do
            local progress = (y - bounds[2]) / (bounds[4] - bounds[2])
            local currentColor = util.interpolate_color(progress, c1, c2)
            local coloredLine = "{\\c" .. currentColor .. "}" .. baseLine
            local clippedLine = "{\\clip(" .. tostring(bounds[1]) .. "," .. tostring(y) .. "," .. tostring(bounds[3]) ..
                                    "," .. tostring(y + lineHeight) .. ")}" .. coloredLine
            local finalLine = clippedLine:gsub("}{", "")
            local newLine = util.deep_copy(line)
            newLine.text = finalLine
            subs.insert(i + 1, newLine)
            linesAdded = linesAdded + 1
        end
        subs.delete(i)
        if curIt < #sel then
            for s = curIt + 1, #sel do
                sel[s] = sel[s] + linesAdded - 1
            end
        end
        curIt = curIt + 1
    end
    aegisub.set_undo_point(script_name)
    return {sel[1]}
end

if haveDepCtrl then
    depCtrl:registerMacro(apply_gradient)
else
    aegisub.register_macro(script_name, "Applies vertical gradient based on 1c and 2c", apply_gradient)
end
