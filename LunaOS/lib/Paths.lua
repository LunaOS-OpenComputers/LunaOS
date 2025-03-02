
local paths = {system = {}, user = {}}

--------------------------------------------------------------------------------

paths.system.libraries = "/LunaOS/lib/"
paths.system.applications = "/Program Files/"
paths.system.icons = "/LunaOS/media/ico/"
paths.system.sys32 = "/LunaOS/system32/"
paths.system.media = "/LunaOS/media/"
paths.system.localizations = "/LunaOS/lang/"
paths.system.extensions = "/LunaOS/ext/"
paths.system.mounts = "/Drives/"
paths.system.temporary = "/Temp/"
paths.system.wallpapers = "/ProgramData/LunaOS/Wallpapers/"
paths.system.users = "/Users/"
paths.system.versions = "/Versions.cfg"

paths.system.applicationSample = paths.system.sys32 .. "Sample.app/"
paths.system.applicationAppMarket = paths.system.sys32 .. "App Store.app/Main.lua"
paths.system.applicationMineCodeIDE = paths.system.sys32 .. "MineCode IDE.app/Main.lua"
paths.system.applicationFinder = paths.system.sys32 .. "Explorer.app/Main.lua"
paths.system.applicationPictureEdit = paths.system.sys32 .. "Paint.app/Main.lua"
paths.system.applicationSettings = paths.system.sys32 .. "Settings.app/Main.lua"
paths.system.applicationPrint3D = paths.system.sys32 .. "Print3D.app/Main.lua"
paths.system.applicationConsole = paths.system.sys32 .. "Command Prompt.app/Main.lua"
paths.system.applicationPictureView = paths.system.sys32 .. "Photos.app/Main.lua"

--------------------------------------------------------------------------------

function paths.create(what)
	for _, path in pairs(what) do
		if path:sub(-1, -1) == "/" then
			require("Filesystem").makeDirectory(path)
		end
	end
end

function paths.getUser(name)
	local user = {}

	user.home = paths.system.users .. name .. "/"
	user.applicationData = user.home .. "AppData/Roaming/"
	user.desktop = user.home .. "Desktop/"
	user.documents = user.home .. "Documents/"
	user.scripts = user.home .. "Scripts/"
	user.libraries = user.home .. "AppData/Local/Libraries/"
	user.applications = user.home .. "AppData/Local/Programs/"
	user.wallpapers = user.home .. "AppData/LocalLow/LunaOS/Wallpapers/"
	user.trash = user.home .. "AppData/Roaming/LunaOS/Recycle Bin/"
	user.settings = user.home .. "AppData/Roaming/LunaOS/Settings.cfg"
	user.versions = user.home .. "AppData/Roaming/LunaOS/Versions.cfg"

	return user
end

function paths.updateUser(...)
	paths.user = paths.getUser(...)
end

--------------------------------------------------------------------------------

return paths
