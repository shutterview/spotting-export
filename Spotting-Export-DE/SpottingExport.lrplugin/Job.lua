local LrApplication   = import 'LrApplication'
local LrFileUtils     = import 'LrFileUtils'
local LrPathUtils     = import 'LrPathUtils'
local LrExportSession = import 'LrExportSession'
local LrDialogs       = import 'LrDialogs'
local LrTasks         = import 'LrTasks'

local M = {}
local appDir = LrPathUtils.child(LrPathUtils.getStandardFilePath('home'),
                                 'Library/Application Support/SpottingExport')
M.jobPath  = LrPathUtils.child(appDir, 'lr_job.txt')
M.donePath = LrPathUtils.child(appDir, 'lr_done.txt')
M.alivePath = LrPathUtils.child(appDir, 'lr_alive.txt')
M.logPath = LrPathUtils.child(appDir, 'lightroom.log')

local LrLogger = import 'LrLogger'
local logger = LrLogger('SpottingExport')
logger:enable('logfile')               -- zusätzlich: ~/Documents/LrClassicLogs/SpottingExport.log

function M.log(msg)
    pcall(function() logger:info(msg) end)
    pcall(function()
        local f = io.open(M.logPath, 'a')
        if f then f:write(os.date('%Y-%m-%d %H:%M:%S ') .. tostring(msg) .. '\n') f:close() end
    end)
end

-- Sichtbare Kurzmeldung in Lightroom (funktioniert auch ohne Dateizugriff)
function M.bezel(msg)
    pcall(function() LrDialogs.showBezel(msg, 3) end)
end
M.name = 'Spotting Export'

function M.heartbeat()
    pcall(function()
        local f = io.open(M.alivePath, 'w')
        if f then f:write(tostring(os.time())) f:close() end
    end)
end

function M.writeDone(text)
    local ok, err = pcall(function()
        local f = assert(io.open(M.donePath, 'w'))
        f:write(text)
        f:close()
    end)
    if not ok then M.log('Konnte Rückmeldung nicht schreiben: ' .. tostring(err)) end
end

local function readJob()
    local txt = LrFileUtils.readFile(M.jobPath)
    if not txt then return nil end
    local job = {}
    for line in txt:gmatch('[^\r\n]+') do
        local k, v = line:match('^([%w_]+)=(.*)$')
        if k then job[k] = v end
    end
    return job
end

-- Findet zum Photoshop-Bearbeitungsfile (z.B. IMG_1234-Bearbeitet.tif) das Original (IMG_1234.CR3)
local function findOriginal(catalog, editedPath)
    local stem = LrPathUtils.removeExtension(LrPathUtils.leafName(editedPath))
    local base = stem:gsub('%-Bearbeitet.*$', ''):gsub('%-Edit.*$', '')
    -- Hat Lightroom die Rohdatei direkt an Photoshop übergeben (z.B. _Y9A6479.CR3), ist sie selbst das Original
    if base == stem then
        local p = catalog:findPhotoByPath(editedPath)
        if p then return p end
    end
    local folder = catalog:getFolderByPath(LrPathUtils.parent(editedPath))
    if not folder then return nil end
    for _, p in ipairs(folder:getPhotos(false)) do
        local path = p:getRawMetadata('path')
        if path ~= editedPath and not p:getRawMetadata('isVirtualCopy')
           and LrPathUtils.removeExtension(LrPathUtils.leafName(path)) == base then
            return p
        end
    end
    return nil
end

-- Liest eine Lightroom-Exportvorgabe (.lrtemplate) und gibt deren Einstellungen zurück
local function loadPreset(path)
    local txt = LrFileUtils.readFile(path)
    if not txt then error('Exportvorgabe nicht lesbar: ' .. tostring(path)) end
    local chunk, err = loadstring(txt)
    if not chunk then error('Exportvorgabe fehlerhaft: ' .. tostring(err)) end
    local env = {}
    setfenv(chunk, env)
    chunk()
    local s = env.s
    if type(s) ~= 'table' or type(s.value) ~= 'table' then
        error('Unerwartetes Format der Exportvorgabe: ' .. tostring(path))
    end
    local copy = {}
    for k, v in pairs(s.value) do copy[k] = v end
    return copy
end

-- Seitenverhältnis des Lightroom-Zuschnitts als Namensendung, z.B. 16x9, 3x2, 4x5, 16x5
local RATIOS = { {1,1}, {5,4}, {4,3}, {3,2}, {16,10}, {16,9}, {2,1}, {12,5}, {3,1}, {16,5}, {20,5} }

local function ratioLabel(photo)
    local d = photo:getRawMetadata('croppedDimensions')
    if not d or not d.width or not d.height or d.height == 0 or d.width == 0 then return '' end
    local w, h = d.width, d.height
    local portrait = h > w
    local r = portrait and (h / w) or (w / h)
    local best, bestErr
    for _, q in ipairs(RATIOS) do
        local err = math.abs(q[1] / q[2] - r) / r
        if not bestErr or err < bestErr then best, bestErr = q, err end
    end
    if bestErr > 0.02 then                     -- freier Zuschnitt: z.B. 1.85x1
        return string.format('%.2fx1', r)
    end
    if portrait then return best[2] .. 'x' .. best[1] end
    return best[1] .. 'x' .. best[2]
end

-- Findet die Fassung, die an Photoshop übergeben wurde (TIFF-Kopie oder virtuelle Kopie)
local function sameId(a, b) return a and b and a.localIdentifier == b.localIdentifier end

local function findPsPhoto(catalog, job, original, targets)
    local stem = LrPathUtils.removeExtension(LrPathUtils.leafName(job.edited_path))
    local base = stem:gsub('%-Bearbeitet.*$', ''):gsub('%-Edit.*$', '')
    if base ~= stem then
        return catalog:findPhotoByPath(job.edited_path)          -- Bearbeitungskopie (TIF/PSD)
    end
    -- 1. was beim Start in Lightroom ausgewählt war (die Fassung mit "Bearbeiten in")
    for _, p in ipairs(targets or {}) do
        local ok, master = pcall(function() return p:getRawMetadata('masterPhoto') end)
        if not sameId(p, original) and ok and sameId(master, original) then return p end
    end
    -- 2. virtuelle Kopie des Originals mit dem Panorama-Format
    local ok, copies = pcall(function() return original:getRawMetadata('virtualCopies') end)
    if ok and copies then
        for _, c in ipairs(copies) do
            if ratioLabel(c) == job.v_format then return c end
        end
    end
    return nil
end

local function processInner()
    local job = readJob()
    if not job then return end
    LrFileUtils.delete(M.jobPath)   -- sofort entfernen, damit nichts doppelt läuft

    M.log('Auftrag gelesen: ' .. tostring(job.edited_path))
    local catalog = LrApplication.activeCatalog()
    local targets = catalog:getTargetPhotos()     -- Auswahl merken, bevor sie geändert wird
    local photo = findOriginal(catalog, job.edited_path)
    if not photo then
        error('Original zu ' .. tostring(job.edited_path) .. ' nicht im Katalog gefunden', 0)
    end

    -- Original auswählen und (optional) als "Ausgewählt" markieren
    catalog:setSelectedPhotos(photo, { photo })
    local psPhoto = findPsPhoto(catalog, job, photo, targets)
    if job.pick == '1' then
        local ok, err = LrTasks.pcall(function()
            catalog:withWriteAccessDo('Spotting Export markieren', function()
                photo:setRawMetadata('pickStatus', 1)
                if psPhoto and not sameId(psPhoto, photo) then psPhoto:setRawMetadata('pickStatus', 1) end
            end, { timeout = 30 })
        end)
        if not ok then M.log('Markieren übersprungen: ' .. tostring(err)) end
    end

    -- Endung (Seitenverhältnis) bestimmen
    local suffix = job.suffix or ''
    if suffix:lower() == 'auto' then suffix = ratioLabel(photo) end

    -- Text für das Freitext-Feld ("Benutzerdefinierter Text") aus dem Muster bauen
    local vals = {
        kennzeichen = job.v_kennzeichen, airline = job.v_airline, flughafen = job.v_flughafen,
        runway = job.v_runway, familie = job.v_familie, freitext = job.v_freitext, format = suffix,
    }
    local custom = (job.custom_pattern or '{kennzeichen}-{format}'):gsub('{(%w+)}', function(k)
        return vals[k] or ''
    end)
    custom = custom:gsub('%-%-+', '-'):gsub('__+', '_'):gsub('^[-_]+', ''):gsub('[-_]+$', '')

    local settings
    if job.preset_path and job.preset_path ~= '' then
        -- Deine Lightroom-Exportvorgabe: alles bleibt wie eingestellt, inkl. fester Namensteile.
        -- Geändert werden nur Zielordner und das Freitext-Feld.
        settings = loadPreset(job.preset_path)
        if not tostring(settings.LR_tokens or ''):find('custom_token', 1, true) then
            error('Die Exportvorgabe enthält kein Freitext-Feld (Benutzerdefinierter Text) im Dateinamen.')
        end
        settings.LR_tokenCustomString = custom
    else
        settings = {
            LR_format                   = 'JPEG',
            LR_jpeg_quality             = (tonumber(job.quality) or 100) / 100,
            LR_export_colorSpace        = 'sRGB',
            LR_size_doConstrain         = false,   -- Originalgröße
            LR_outputSharpeningOn       = false,
            LR_renamingTokensOn         = true,
            LR_tokens                   = '{{custom_token}}',
            LR_tokenCustomString        = (job.name_prefix or '') .. '_' .. custom,
            LR_collisionHandling        = 'rename',
            LR_minimizeEmbeddedMetadata = false,
            LR_reimportExportedPhoto    = false,
        }
    end
    settings.LR_collisionHandling            = 'rename'   -- nie mit einer Rückfrage hängen bleiben
    settings.LR_export_destinationType       = 'specificFolder'
    settings.LR_export_destinationPathPrefix = job.target_folder
    settings.LR_export_useSubfolder          = false

    M.log('Original: ' .. tostring(photo:getRawMetadata('path')) .. ' -> ' .. tostring(job.target_folder))
    local session = LrExportSession { photosToExport = { photo }, exportSettings = settings }
    local outPath
    for _, rendition in session:renditions() do
        local ok, pathOrMsg = rendition:waitForRender()
        if not ok then error(pathOrMsg) end
        outPath = pathOrMsg
    end
    M.log('Export fertig: ' .. tostring(outPath))
    M.writeDone('OK ' .. tostring(outPath))
    pcall(function() LrDialogs.showBezel('Spotting Export fertig') end)
end

function M.process()
    if M.busy then return end
    M.busy = true
    local ok, err = LrTasks.pcall(processInner)
    M.busy = false
    if not ok then error(err, 0) end
end

return M
