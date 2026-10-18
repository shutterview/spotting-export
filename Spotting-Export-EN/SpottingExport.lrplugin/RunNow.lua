local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local Job = require 'Job'

LrTasks.startAsyncTask(function()
    if not LrFileUtils.exists(Job.jobPath) then
        LrDialogs.message('Spotting Export', 'No pending job.')
        return
    end
    if Job.busy then
        LrDialogs.message('Spotting Export', 'The export is already running.')
        return
    end
    local ok, err = LrTasks.pcall(Job.process)
    if ok then
        Job.bezel('Spotting Export: done')
    else
        Job.log('ERROR: ' .. tostring(err))
        Job.writeDone('ERROR: ' .. tostring(err))
        LrDialogs.message('Spotting Export – error', tostring(err), 'critical')
    end
end)
