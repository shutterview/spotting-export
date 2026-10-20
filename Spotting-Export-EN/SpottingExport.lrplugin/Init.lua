-- Starts a background watcher on Lightroom launch that waits for jobs
-- from the Python script (lr_job.txt) and runs them automatically.
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'
local Job = require 'Job'

Job.gen = (Job.gen or 0) + 1
local myGen = Job.gen

LrTasks.startAsyncTask(function()
    Job.log('Plugin started')
    LrTasks.sleep(4)
    Job.bezel('Spotting Export ready')                 -- visible sign that the watcher is running
    local beat = 0
    while Job.gen == myGen do
        if LrFileUtils.exists(Job.jobPath) and not Job.busy then
            Job.bezel('Spotting Export: exporting …')
            local ok, err = LrTasks.pcall(Job.process)
            if ok then
                Job.bezel('Spotting Export: done')
            else
                Job.log('ERROR: ' .. tostring(err))
                Job.writeDone('ERROR: ' .. tostring(err))
                LrDialogs.message('Spotting Export – error', tostring(err), 'critical')
            end
        end
        beat = beat + 1
        if beat >= 4 then Job.heartbeat(); beat = 0 end
        LrTasks.sleep(1.5)
    end
end, 'SpottingExport-Watcher')
