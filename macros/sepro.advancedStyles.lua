script_name = "Advanced Styles"
script_description = "Alows saving and applying of advanced styles"
script_version = "1.1.2"
script_author = "sepro"
script_namespace = "sepro.advancedStyles"

local DependencyControl = require("l0.DependencyControl")

local depCtrl = DependencyControl {
    feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json",
    {"aegisub.util"}
}
local util = depCtrl:requireModules()

local advancedStyles = depCtrl:getConfigHandler({}, "advancedStyles")

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
    if text:match("\\pos%([^%)]+%)") or text:match("\\move%([^%)]+%)") then
        return text
    end
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

-- TODO: Change timing to be frame based instead of ms?
function save_advanced_style(subs, sel)
    -- Check if selection as same style
    local style = subs[sel[1]].style
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line.style ~= style then
            showError("Lines don't have the same style")
            return
        end
    end

    -- Check if selection has same baseText
    local baseText = subs[sel[1]].text:gsub("^{[^}]*}", "")
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line.text:gsub("^{[^}]*}", "") ~= baseText then
            showError("Lines text doesn't match")
            return
        end
    end

    -- Get start and end time to calculate offset of lines
    local baseStart = subs[sel[1]].start_time
    local baseEnd = subs[sel[1]].end_time

    -- setPos (set \pos on all lines)
    for _, i in ipairs(sel) do
        local line = subs[i]
        line.text = setPos(subs, line.text, line)
    end

    -- Extract tagData
    local firstTag = subs[sel[1]].text:match("^{([^}]*)}")
    local firstX, firstY = firstTag:match("\\pos%(([%d%.%-]*),([%d%.%-]*)%)")
    if firstX == nil or firstY == nil then
        firstX, firstY = firstTag:match("\\move%(([%d%.%-]*),([%d%.%-]*),[^%)]+%)")
        if firstX == nil or firstY == nil then
            showError("Could not extract position from tag")
            return
        end
    end
    local dataList = {}
    for _, i in ipairs(sel) do
        local line = subs[i]

        local tag = line.text:match("^{([^}]*)}")
        if tag:match("\\org%([^%)]+%)") then
            -- Rewrite \pos to be relative to first line
            local x, y = tag:match("\\org%(([%d%.%-]*),([%d%.%-]*)%)")
            if x == firstX then
                x = "$x"
            else
                x = "!$x+" .. tostring(tonumber(x) - tonumber(firstX)) .. "!"
            end
            if y == firstY then
                y = "$y"
            else
                y = "!$y+" .. tostring(tonumber(y) - tonumber(firstY)) .. "!"
            end
            tag = tag:gsub("\\org%([%d%.%-]*,[%d%.%-]*%)", "\\org%(" .. x .. "," .. y .. "%)")
        end

        if tag:match("\\pos%([^%)]+%)") then
            -- Rewrite \pos to be relative to first line
            local x, y = tag:match("\\pos%(([%d%.%-]*),([%d%.%-]*)%)")
            if x == firstX then
                x = "$x"
            else
                x = "!$x+" .. tostring(tonumber(x) - tonumber(firstX)) .. "!"
            end
            if y == firstY then
                y = "$y"
            else
                y = "!$y+" .. tostring(tonumber(y) - tonumber(firstY)) .. "!"
            end
            tag = tag:gsub("\\pos%([%d%.%-]*,[%d%.%-]*%)", "\\pos%(" .. x .. "," .. y .. "%)")
        elseif tag:match("\\move%([^%)]+%)") then
            -- Rewrite \move to be relative to first line
            local x1, y1, x2, y2, t1, t2 = tag:match(
                "\\move%(([%d%.%-]*),([%d%.%-]*),([%d%.%-]*),([%d%.%-]*),([%d]*),([%d]*)%)")
            if x1 == firstX then
                x1 = "$x"
            else
                x1 = "!$x+" .. tostring(tonumber(x1) - tonumber(firstX)) .. "!"
            end
            if x2 == firstX then
                x2 = "$x"
            else
                x2 = "!$x+" .. tostring(tonumber(x2) - tonumber(firstX)) .. "!"
            end
            if y1 == firstY then
                y1 = "$y"
            else
                y1 = "!$y+" .. tostring(tonumber(y1) - tonumber(firstY)) .. "!"
            end
            if y2 == firstY then
                y2 = "$y"
            else
                y2 = "!$y+" .. tostring(tonumber(y2) - tonumber(firstY)) .. "!"
            end
            tag = tag:gsub("\\move%([%d%.%-]*,[%d%.%-]*,[%d%.%-]*,[%d%.%-]*,[%d]*,[%d]*%)",
                "\\move%(" .. x1 .. "," .. y1 .. "," .. x2 .. "," .. y2 .. "," .. t1 .. "," .. t2 .. "%)")
        end

        local dataObj = {}
        dataObj["tag"] = tag
        dataObj["layer"] = line.layer
        dataObj["start_offset"] = line.start_time - baseStart
        dataObj["end_offset"] = line.end_time - baseEnd
        table.insert(dataList, dataObj)
    end

    -- Save data
    advancedStyles.config[style] = dataList

    advancedStyles:write()

end

function apply_advanced_style(subs, sel)
    local curIt = 1
    for _, i in ipairs(sel) do
        local line = subs[i]
        if not advancedStyles.config[line.style] then
            showError("No advanced style saved for " .. line.style)
            return
        end
        if line.text:match("\\move%([^%)]+%)") then
            showError("Cannot apply advanced style to line with move tag")
            return
        end
        line.text = setPos(subs, line.text, line)
        local firstX, firstY = line.text:match("\\pos%(([%d%.%-]*),([%d%.%-]*)%)")
        if firstX == nil or firstY == nil then
            showError("Could not extract position from tag")
            return
        end
        line.text = line.text:gsub("\\pos%([^%)]+%)", ""):gsub("{}", "")
        -- Read data
        local dataList = advancedStyles.config[line.style]
        local linesAdded = 0
        for _, dataObj in ipairs(dataList) do
            local tag = dataObj["tag"]
            -- Step 1 replae varaibles
            tag = tag:gsub("$x", firstX)
            tag = tag:gsub("$y", firstY)
            -- Step 2 calculate equations
            local count = 0
            while tag:match("!([^!]+)!") do
                local equation = tag:match("!([^!]+)!")
                local solution = loadstring('return ' .. equation)()
                local escapedEquation = equation:gsub("%]", "%%]"):gsub("%[", "%%["):gsub("%.", "%%."):gsub("%!", "%%!")
                    :gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%*", "%%*"):gsub("%+", "%%+"):gsub("%-", "%%-")
                tag = tag:gsub("%!" .. escapedEquation .. "%!", solution)
                count = count + 1
                if count > 1000 then
                    showError("Equation loop detected. Aborting.")
                    return
                end
            end
            -- Step 3 create lines with tag
            local newLine = util.deep_copy(line)
            newLine.layer = dataObj["layer"]
            newLine.start_time = newLine.start_time + dataObj["start_offset"]
            newLine.end_time = newLine.end_time + dataObj["end_offset"]
            newLine.text = ("{" .. tag .. "}" .. newLine.text):gsub("}{", "")
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
    return {sel[1]}
end

depCtrl:registerMacros({{"Save Style", "Saves an advanced style", save_advanced_style},
                        {"Apply Style", "Applies any advanced styles", apply_advanced_style}})
