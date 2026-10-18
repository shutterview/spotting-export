local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local Job = require 'Job'

LrTasks.startAsyncTask(function()
    if not LrFileUtils.exists(Job.jobPath) then
        LrDialogs.message('Spotting Export', 'Kein offener Auftrag vorhanden.')
        return
    end
    if Job.busy then
        LrDialogs.message('Spotting Export', 'Der Export läuft bereits.')
        return
    end
    local ok, err = LrTasks.pcall(Job.process)
    if ok then
        Job.bezel('Spotting Export: fertig')
    else
        Job.log('FEHLER: ' .. tostring(err))
        Job.writeDone('FEHLER: ' .. tostring(err))
        LrDialogs.message('Spotting Export – Fehler', tostring(err), 'critical')
    end
end)
