return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.shutterview.spottingexport',
    LrPluginName = 'Spotting Export',
    LrPluginInfoUrl = 'https://www.instagram.com/shutterview.aviation/',
    LrInitPlugin = 'Init.lua',
    LrForceInitPlugin = true,      -- load the watcher on Lightroom start, not on first use
    LrShutdownPlugin = 'Shutdown.lua',
    LrExportMenuItems = {
        { title = 'Spotting Export – run now', file = 'RunNow.lua' },
    },
    LrLibraryMenuItems = {
        { title = 'Spotting Export – run now', file = 'RunNow.lua' },
    },
    VERSION = { major = 1, minor = 1, revision = 0 },
}
