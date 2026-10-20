return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.shutterview.spottingexport',
    LrPluginName = 'Spotting Export',
    LrInitPlugin = 'Init.lua',
    LrForceInitPlugin = true,      -- Wächter schon beim Lightroom-Start laden, nicht erst bei erster Benutzung
    LrShutdownPlugin = 'Shutdown.lua',
    LrExportMenuItems = {
        { title = 'Spotting Export jetzt ausführen', file = 'RunNow.lua' },
    },
    LrLibraryMenuItems = {
        { title = 'Spotting Export jetzt ausführen', file = 'RunNow.lua' },
    },
    VERSION = { major = 1, minor = 1, revision = 0 },
}
