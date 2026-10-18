-- Startet beim Lightroom-Start einen Hintergrund-Wächter, der auf Aufträge
-- des Python-Skripts wartet (lr_job.txt) und sie automatisch ausführt.
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'
local Job = require 'Job'

Job.gen = (Job.gen or 0) + 1
local myGen = Job.gen

LrTasks.startAsyncTask(function()
    Job.log('Plugin gestartet')
    LrTasks.sleep(4)
    Job.bezel('Spotting Export bereit')                 -- sichtbares Zeichen, dass der Wächter läuft
    local beat = 0
    while Job.gen == myGen do
        if LrFileUtils.exists(Job.jobPath) and not Job.busy then
            Job.bezel('Spotting Export: Export läuft …')
            local ok, err = LrTasks.pcall(Job.process)
            if ok then
                Job.bezel('Spotting Export: fertig')
            else
                Job.log('FEHLER: ' .. tostring(err))
                Job.writeDone('FEHLER: ' .. tostring(err))
                LrDialogs.message('Spotting Export – Fehler', tostring(err), 'critical')
            end
        end
        beat = beat + 1
        if beat >= 4 then Job.heartbeat(); beat = 0 end
        LrTasks.sleep(1.5)
    end
end, 'SpottingExport-Waechter')
