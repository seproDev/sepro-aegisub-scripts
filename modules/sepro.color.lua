local haveDepCtrl, DependencyControl, depCtrl = pcall(require, "l0.DependencyControl")
local colorModule = {}
if haveDepCtrl then
    depCtrl = DependencyControl({
        name = "libColor",
        version = "1.0.0",
        description = "Bunch of color related functions",
        author = "Sepro",
        url = "https://github.com/seproDev/sepros-aegisub-scripts",
        feed = "https://raw.githubusercontent.com/seproDev/sepros-aegisub-scripts/main/DependencyControl.json",
        moduleName = "sepro.color"
    })
end

-- Code ported from http://www.easyrgb.com/en/math.php

local function XYZ_to_RGB(X, Y, Z)
    local var_X = X / 100
    local var_Y = Y / 100
    local var_Z = Z / 100

    var_R = var_X * 3.2406 + var_Y * -1.5372 + var_Z * -0.4986
    var_G = var_X * -0.9689 + var_Y * 1.8758 + var_Z * 0.0415
    var_B = var_X * 0.0557 + var_Y * -0.2040 + var_Z * 1.0570

    if (var_R > 0.0031308) then
        var_R = 1.055 * (var_R ^ (1 / 2.4)) - 0.055
    else
        var_R = 12.92 * var_R
    end
    if (var_G > 0.0031308) then
        var_G = 1.055 * (var_G ^ (1 / 2.4)) - 0.055
    else
        var_G = 12.92 * var_G
    end
    if (var_B > 0.0031308) then
        var_B = 1.055 * (var_B ^ (1 / 2.4)) - 0.055
    else
        var_B = 12.92 * var_B
    end

    local R = var_R * 255
    local G = var_G * 255
    local B = var_B * 255

    return R, G, B
end

local function RGB_to_XYZ(R, G, B)
    local var_R = (R / 255)
    local var_G = (G / 255)
    local var_B = (B / 255)

    if (var_R > 0.04045) then
        var_R = ((var_R + 0.055) / 1.055) ^ 2.4
    else
        var_R = var_R / 12.92
    end

    if (var_G > 0.04045) then
        var_G = ((var_G + 0.055) / 1.055) ^ 2.4
    else
        var_G = var_G / 12.92
    end

    if (var_B > 0.04045) then
        var_B = ((var_B + 0.055) / 1.055) ^ 2.4
    else
        var_B = var_B / 12.92
    end

    var_R = var_R * 100
    var_G = var_G * 100
    var_B = var_B * 100

    local X = var_R * 0.4124 + var_G * 0.3576 + var_B * 0.1805
    local Y = var_R * 0.2126 + var_G * 0.7152 + var_B * 0.0722
    local Z = var_R * 0.0193 + var_G * 0.1192 + var_B * 0.9505

    return X, Y, Z
end

local function XYZ_to_CIELab(X, Y, Z)
    -- D65
    local var_X = X / 95.047
    local var_Y = Y / 100.0
    local var_Z = Z / 108.883

    if (var_X > 0.008856) then
        var_X = var_X ^ (1 / 3)
    else
        var_X = (7.787 * var_X) + (16 / 116)
    end
    if (var_Y > 0.008856) then
        var_Y = var_Y ^ (1 / 3)
    else
        var_Y = (7.787 * var_Y) + (16 / 116)
    end
    if (var_Z > 0.008856) then
        var_Z = var_Z ^ (1 / 3)
    else
        var_Z = (7.787 * var_Z) + (16 / 116)
    end

    local L = (116 * var_Y) - 16
    local a = 500 * (var_X - var_Y)
    local b = 200 * (var_Y - var_Z)

    return L, a, b
end

local function CIELab_to_XYZ(L, a, b)

    local var_Y = (L + 16) / 116
    local var_X = a / 500 + var_Y
    local var_Z = var_Y - b / 200

    if (var_Y ^ 3 > 0.008856) then
        var_Y = var_Y ^ 3
    else
        var_Y = (var_Y - 16 / 116) / 7.787
    end
    if (var_X ^ 3 > 0.008856) then
        var_X = var_X ^ 3
    else
        var_X = (var_X - 16 / 116) / 7.787
    end
    if (var_Z ^ 3 > 0.008856) then
        var_Z = var_Z ^ 3
    else
        var_Z = (var_Z - 16 / 116) / 7.787
    end

    -- D65
    local X = var_X * 95.047
    local Y = var_Y * 100.0
    local Z = var_Z * 108.883

    return X, Y, Z
end

local function CIELab_to_Hue(var_a, var_b)

    local var_bias = 0
    if (var_a >= 0 and var_b == 0) then
        return 0
    end
    if (var_a < 0 and var_b == 0) then
        return 180
    end
    if (var_a == 0 and var_b > 0) then
        return 90
    end
    if (var_a == 0 and var_b < 0) then
        return 270
    end
    if (var_a > 0 and var_b > 0) then
        var_bias = 0
    end
    if (var_a < 0) then
        var_bias = 180
    end
    if (var_a > 0 and var_b < 0) then
        var_bias = 360
    end
    return (math.deg(math.atan(var_b / var_a)) + var_bias)
end

local function deltaE_2000(L1, a1, b1, L2, a2, b2)
    -- Wheight factors
    local WHT_L = 1
    local WHT_C = 1
    local WHT_H = 1

    local xC1 = math.sqrt(a1 * a1 + b1 * b1)
    local xC2 = math.sqrt(a2 * a2 + b2 * b2)
    local xCX = (xC1 + xC2) / 2
    local xGX = 0.5 * (1 - math.sqrt((xCX ^ 7) / ((xCX ^ 7) + (25 ^ 7))))
    local xNN = (1 + xGX) * a1
    xC1 = math.sqrt(xNN * xNN + b1 * b1)
    local xH1 = CIELab_to_Hue(xNN, b1)
    xNN = (1 + xGX) * a2
    xC2 = math.sqrt(xNN * xNN + b2 * b2)
    local xH2 = CIELab_to_Hue(xNN, b2)
    local xDL = L2 - L1
    local xDC = xC2 - xC1
    local xDH
    if ((xC1 * xC2) == 0) then
        xDH = 0
    else
        xNN = xH2 - xH1
        if (math.abs(xNN) <= 180) then
            xDH = xH2 - xH1
        else
            if (xNN > 180) then
                xDH = xH2 - xH1 - 360
            else
                xDH = xH2 - xH1 + 360
            end
        end
    end

    xDH = 2 * math.sqrt(xC1 * xC2) * math.sin(math.rad(xDH / 2))
    local xLX = (L1 + L2) / 2
    local xCY = (xC1 + xC2) / 2
    local xHX
    if ((xC1 * xC2) == 0) then
        xHX = xH1 + xH2
    else
        xNN = math.abs(xH1 - xH2)
        if (xNN > 180) then
            if ((xH2 + xH1) < 360) then
                xHX = xH1 + xH2 + 360
            else
                xHX = xH1 + xH2 - 360
            end
        else
            xHX = xH1 + xH2
        end
        xHX = xHX / 2
    end
    local xTX = 1 - 0.17 * math.cos(math.rad(xHX - 30)) + 0.24 * math.cos(math.rad(2 * xHX)) + 0.32 * math.cos(math.rad(3 * xHX + 6)) - 0.20 * math.cos(math.rad(4 * xHX - 63))
    local xPH = 30 * math.exp(-((xHX - 275) / 25) * ((xHX - 275) / 25))
    local xRC = 2 * math.sqrt((xCY ^ 7) / ((xCY ^ 7) + (25 ^ 7)))
    local xSL = 1 + ((0.015 * ((xLX - 50) * (xLX - 50))) / math.sqrt(20 + ((xLX - 50) * (xLX - 50))))

    local xSC = 1 + 0.045 * xCY
    local xSH = 1 + 0.015 * xCY * xTX
    local xRT = -math.sin(math.rad(2 * xPH)) * xRC
    xDL = xDL / (WHT_L * xSL)
    xDC = xDC / (WHT_C * xSC)
    xDH = xDH / (WHT_H * xSH)

    return math.sqrt(xDL ^ 2 + xDC ^ 2 + xDH ^ 2 + xRT * xDC * xDH)
end

local function RGB_deltaE_2000(R1, G1, B1, R2, G2, B2)
    local X1, Y1, Z1 = RGB_to_XYZ(R1, G1, B1)
    local X2, Y2, Z2 = RGB_to_XYZ(R2, G2, B2)
    local L1, a1, b1 = XYZ_to_CIELab(X1, Y1, Z1)
    local L2, a2, b2 = XYZ_to_CIELab(X2, Y2, Z2)
    return deltaE_2000(L1, a1, b1, L2, a2, b2)
end

colorModule = {
    XYZ_to_RGB = XYZ_to_RGB,
    RGB_to_XYZ = RGB_to_XYZ,
    XYZ_to_CIELab = XYZ_to_CIELab,
    CIELab_to_XYZ = CIELab_to_XYZ,
    CIELab_to_Hue = CIELab_to_Hue,
    deltaE_2000 = deltaE_2000,
    RGB_deltaE_2000 = RGB_deltaE_2000
}

if haveDepCtrl then
    colorModule.version = depCtrl
    return depCtrl:register(colorModule)
else
    return colorModule
end
