--!strict

local argparse = require("@pkg/argparse")
local configModule = require("@self/config")
local convertFilePathToRobloxPath = require("@self/sourcemap/convertFilePathToRobloxPath")
local generateTestScript = require("@self/generateTestScript")
local process = require("@lune/process")
local runTestsCloud = require("@self/runner/runTestsCloud")
local runTestsOnce = require("@self/runner/runTestsOnce")
local runTestsServe = require("@self/runner/runTestsServe")
local types = require("@self/runner/types")

type RunTarget = types.RunTarget
type RunTargetConfig = types.RunTargetConfig

local function loadEnvFile(): { [string]: string }
	local fs = require("@lune/fs")
	local envPath = ".env"

	if not fs.isFile(envPath) then
		error("No .env file found")
	end

	local content = fs.readFile(envPath)
	local env = {}

	for line in content:gmatch("[^\r\n]+") do
		local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
		if key and value then
			-- Remove quotes if present
			value = value:match('^"(.+)"$') or value:match("^'(.+)'$") or value
			env[key] = value
		end
	end

	return env
end

local function getApiKey(): string
	local keyInEnv = process.env.JEST_RODEO_API_KEY
	if keyInEnv then
		return keyInEnv
	end

	local success, envFile = pcall(loadEnvFile)
	if not success then
		error("No environment variable set for JEST_RODEO_API_KEY. Please set it in the environment or in the .env file.")
	end

	return envFile.JEST_RODEO_API_KEY
end

local function parseArgs()
	local parser: any = argparse():name("test"):description("Run tests")

	parser:flag("--verbose", "Enable verbose output")
	parser:flag("--ci", "Run in CI mode")
	parser:flag("--no-error", "Suppress error and info output from rodeo")
	parser:flag("--no-warn", "Suppress warning output from rodeo")
	parser:option("--target", "Execution target: once, serve, or cloud (default: serve)")
	parser:option("--project", "Project name from jest-rodeo.toml to run tests for")
	parser:option("--test-name-pattern", "Pattern to match test names (regex)")
	parser:option("--test-path-pattern", "Pattern to match test file paths (regex)")
	parser:option("--universe-id", "Universe ID for cloud execution")
	parser:option("--place-id", "Place ID for cloud execution")
	parser:option("--place-version", "Place version for cloud execution (optional, uses latest if not specified)")
	parser:option("--api-key", "Roblox Open Cloud API key")
	parser:flag("--upload", "Upload the place file before running tests (cloud only)")
	parser:option("--place", "Path to place file (for once target and cloud with --upload)")
	parser:option("--sourcemap", "Path to sourcemap.json")

	return parser:parse(process.args)
end

local function determineProjects(args, jestRodeoConfig): ({ string }?, string?, string?)
	local projects: { string }? = nil
	local testPathPattern: string? = args.test_path_pattern
	local testNamePattern: string? = args.test_name_pattern

	if args.project then
		if not jestRodeoConfig then
			error("jest-rodeo.toml not found. Cannot use --project flag without config file.")
		end

		local projectPath = configModule.getProjectPath(jestRodeoConfig, args.project, convertFilePathToRobloxPath)
		if not projectPath then
			error(`Project "{args.project}" not found in jest-rodeo.toml`)
		end

		projects = { projectPath }
	else
		if jestRodeoConfig then
			projects = configModule.getAllProjectPaths(jestRodeoConfig, convertFilePathToRobloxPath)
		end
	end

	return projects, testPathPattern, testNamePattern
end

local function buildConfig(target: RunTarget, args, jestRodeoConfig: any): RunTargetConfig
	if target == "cloud" then
		local apiKey: string = if typeof(args.api_key) == "string" then args.api_key else getApiKey()

		local universeId: string? = args.universe_id
		if not universeId and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.universe_id) == "string" then
			universeId = jestRodeoConfig.cloud.universe_id
		elseif not universeId and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.universe_id) == "number" then
			universeId = tostring(jestRodeoConfig.cloud.universe_id)
		end
		if not universeId then
			error("Universe ID required for --target cloud. Provide via --universe-id flag or jest-rodeo.toml [cloud] section")
		end

		local placeId: string? = args.place_id
		if not placeId and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.place_id) == "string" then
			placeId = jestRodeoConfig.cloud.place_id
		elseif not placeId and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.place_id) == "number" then
			placeId = tostring(jestRodeoConfig.cloud.place_id)
		end
		if not placeId then
			error("Place ID required for --target cloud. Provide via --place-id flag or jest-rodeo.toml [cloud] section")
		end

		local placeVersion: string? = args.place_version
		if not placeVersion and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.place_version) == "string" then
			placeVersion = jestRodeoConfig.cloud.place_version
		elseif not placeVersion and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.place_version) == "number" then
			placeVersion = tostring(jestRodeoConfig.cloud.place_version)
		end

		local upload: boolean? = args.upload
		if upload == nil and jestRodeoConfig and typeof(jestRodeoConfig.cloud) == "table" and typeof(jestRodeoConfig.cloud.upload) == "boolean" then
			upload = jestRodeoConfig.cloud.upload
		end

		local placePath: string? = nil
		if typeof(args.place) == "string" then
			placePath = args.place
		elseif jestRodeoConfig and typeof(jestRodeoConfig.once) == "table" and typeof(jestRodeoConfig.once.place_file) == "string" then
			placePath = jestRodeoConfig.once.place_file
		end

		return {
			target = "cloud" :: "cloud",
			universeId = universeId,
			placeId = placeId,
			placeVersion = placeVersion,
			apiKey = apiKey,
			upload = upload,
			placePath = placePath,
		}
	elseif target == "once" then
		local placePath: string
		if typeof(args.place) == "string" then
			placePath = args.place
		elseif jestRodeoConfig and typeof(jestRodeoConfig.once) == "table" and typeof(jestRodeoConfig.once.place_file) == "string" then
			placePath = jestRodeoConfig.once.place_file
		else
			error("Place file path required for --target once. Provide via --place flag or jest-rodeo.toml [once] section")
		end

		local sourcemapPath: string? = if typeof(args.sourcemap) == "string" then args.sourcemap else "sourcemap.json"

		return {
			target = "once",
			placePath = placePath,
			sourcemapPath = sourcemapPath,
			noError = args.no_error,
			noWarn = args.no_warn,
		}
	else
		local sourcemapPath: string? = if typeof(args.sourcemap) == "string" then args.sourcemap else "sourcemap.json"

		return {
			target = "serve",
			sourcemapPath = sourcemapPath,
			noError = args.no_error,
			noWarn = args.no_warn,
		}
	end
end

local function main(): number
	local args = parseArgs()

	local target: RunTarget = args.target or "serve"
	if target ~= "once" and target ~= "serve" and target ~= "cloud" then
		error(`Invalid target "{target}". Must be one of: once, serve, cloud`)
	end

	local jestRodeoConfig = configModule.loadConfig()
	local projects, testPathPattern, testNamePattern = determineProjects(args, jestRodeoConfig)
	local config = buildConfig(target, args, jestRodeoConfig)
	local scriptContent = generateTestScript({
		verbose = args.verbose or false,
		ci = args.ci or false,
		projects = projects,
		testNamePattern = testNamePattern,
		testPathPattern = testPathPattern,
	})

	local exitCode: number
	if config.target == "cloud" then
		exitCode = runTestsCloud(scriptContent, config)
	elseif config.target == "once" then
		exitCode = runTestsOnce(scriptContent, config)
	else
		exitCode = runTestsServe(scriptContent, config)
	end

	return exitCode
end

process.exit(main())
