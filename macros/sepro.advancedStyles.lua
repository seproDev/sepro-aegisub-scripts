script_name = "Advanced Styles"
script_description = "Alows saving and applying of advanced styles"
script_version = '1.0.0'
script_author = "sepro"
script_namespace = "sepro.advancedStyles"

local DependencyControl = require("l0.DependencyControl")

local depCtrl = DependencyControl {
    feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json"
}

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

-- TODO: relative timing of lines
-- TODO: Move, org support
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

    -- Check if selection has same start_time and end_time
    local baseStart = subs[sel[1]].start_time
    local baseEnd = subs[sel[1]].end_time
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line.start_time ~= baseStart or line.end_time ~= baseEnd then
            showError("Lines with different start/end time are not yet supported")
            return
        end
    end

    -- setPos (set \pos on all lines)
    for _, i in ipairs(sel) do
        local line = subs[i]
        line.text = setPos(subs, line.text, line)
    end

    -- Extract tagData
    local firstTag = subs[sel[1]].text:match("^{([^}]*)}")
    local firstX, firstY = firstTag:match("\\pos%(([%d%.%-]*),([%d%.%-]*)%)")
    local dataList = {}
    for _, i in ipairs(sel) do
        local line = subs[i]
        -- Rewrite \pos to be relative to first line
        local tag = line.text:match("^{([^}]*)}")
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

        local dataObj = {}
        dataObj["tag"] = tag
        dataObj["layer"] = line.layer
        table.insert(dataList, dataObj)
    end

    -- Save data
    advancedStyles.config[style] = dataList

    advancedStyles:write()

end

function apply_advanced_style(subs, sel)
    if not haveDepCtrl then
        showError("DependencyControl required for this function")
        return
    end
    local curIt = 1
    for _, i in ipairs(sel) do
        local line = subs[i]
        if not advancedStyles.config[line.style] then
            showError("No advanced style saved for " .. line.style)
            return
        end

        line.text = setPos(subs, line.text, line)
        local firstX, firstY = line.text:match("\\pos%(([%d%.%-]*),([%d%.%-]*)%)")
        line.text = line.text:gsub("\\pos&[^\\}]+", ""):gsub("{}", "")
        -- Read data
        local dataList = advancedStyles.config[line.style]
        local linesAdded = 0
        for _, dataObj in ipairs(dataList) do
            local tag = dataObj["tag"]
            local x, y = tag:match("\\pos%(([%d%.%-!$x+]*),([%d%.%-!$y+]*)%)")
            x = x:gsub("$x", firstX)
            y = y:gsub("$y", firstY)
            if x:match("!([^!]+)!") then
                x = loadstring('return ' .. x:match("!([^!]+)!"))()
            end
            if y:match("!([^!]+)!") then
                y = loadstring('return ' .. y:match("!([^!]+)!"))()
            end

            tag = tag:gsub("\\pos%([%d%.%-!$x+]*,[%d%.%-!$y+]*%)", "\\pos%(" .. x .. "," .. y .. "%)")

            local newLine = util.deep_copy(line)
            newLine.layer = dataObj["layer"]
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
