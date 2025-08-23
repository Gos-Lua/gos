local AIO_FOLDER = "L9Engine"
local BASE_URL = "https://raw.githubusercontent.com/Gos-Lua/gos/main/"
local LOCAL_PATH = COMMON_PATH .. AIO_FOLDER .. "/"
local CORE_FILE = LOCAL_PATH .. "Core.lua"

local CHAMPION_SCRIPTS = {
    "Sylas.lua",
    "Pyke.lua", 
    "Aurora.lua",
    "Draven.lua",
    "XinZhao.lua",
    "MasterYi.lua",
    "Thresh.lua",
    "Kayn.lua"
}

local needed = {
    [CORE_FILE] = "Core.lua"
}

for _, scriptName in ipairs(CHAMPION_SCRIPTS) do
    local scriptPath = LOCAL_PATH .. "Champions/" .. scriptName
    needed[scriptPath] = scriptName
end

local function FileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local pendingDownloads = 0
local function Download(url, path, cb)
    pendingDownloads = pendingDownloads + 1
    DownloadFileAsync(url, path, function()
        pendingDownloads = pendingDownloads - 1
        if cb then cb(path) end
    end)
end

local function EnsureDir()
    local championsPath = LOCAL_PATH .. "Champions/"
    if not FileExists(championsPath) then
        print("[L9Engine] Création du dossier Champions...")
    end
end

local function CheckAndDownload()
    EnsureDir()
    for fullPath, shortName in pairs(needed) do
        if not FileExists(fullPath) then
            print(string.format("[L9Engine] Téléchargement de %s depuis GitHub...", shortName))
            Download(BASE_URL .. shortName, fullPath, function()
                print(string.format("[L9Engine] %s prêt", shortName))
            end)
        end
    end
end

local function SafeDofile(path)
    local ok, err = pcall(dofile, path)
    if not ok then
        print("[L9Engine] Erreur lors du chargement de " .. path .. ": " .. tostring(err))
        return false
    end
    return true
end

local function TryLoadCore()
    if _G.L9EngineLoaded then
        Callback.Del("Tick", TryLoadCore)
        return
    end
    if pendingDownloads > 0 then return end
    if not FileExists(CORE_FILE) then return end
    if SafeDofile(CORE_FILE) then
        if _G.L9EngineLoaded then
            print("[L9Engine] Engine original chargé avec succès")
            print("[L9Engine] Champions supportés: Sylas, Pyke, Aurora, Draven, XinZhao, MasterYi, Thresh, Kayn")
        end
        Callback.Del("Tick", TryLoadCore)
    end
end

print("[L9Engine] Démarrage de l'engine original...")
print("[L9Engine] Téléchargement depuis: https://github.com/Gos-Lua/gos")
CheckAndDownload()

Callback.Add("Tick", TryLoadCore)

DelayAction(function()
    TryLoadCore()
    if pendingDownloads == 0 and not FileExists(CORE_FILE) then
        print("[L9Engine] Impossible d'obtenir Core.lua depuis GitHub")
    end
end, 3)
