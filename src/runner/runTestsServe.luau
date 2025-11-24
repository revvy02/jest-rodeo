--!strict

local process = require("@lune/process")
local types = require("./types")

type ServeConfig = types.ServeConfig

local function runTestsServe(scriptContent: string, config: ServeConfig): number
	local args = { "exec", "-s", scriptContent }

	if config.noError then
		table.insert(args, "--no-error")
		table.insert(args, "--no-info")
	end

	if config.noWarn then
		table.insert(args, "--no-warn")
	end

	local result = process.exec("rodeo", args, {
		stdio = "forward",
	})

	return result.code
end

return runTestsServe
