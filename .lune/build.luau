local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local TARGETS = {
	{ os = "macos", arch = "aarch64", ext = "" },
	{ os = "macos", arch = "x86_64", ext = "" },
	{ os = "linux", arch = "x86_64", ext = "" },
	{ os = "windows", arch = "x86_64", ext = ".exe" },
}

local function log(message: string)
	stdio.write(`[build] {message}\n`)
end

local function runCommand(command: string, args: { string }, description: string): boolean
	log(description)
	local result = process.exec(command, args)

	if not result.ok then
		stdio.ewrite(`Error: {description} failed\n`)
		if result.stderr and #result.stderr > 0 then
			stdio.ewrite(`{result.stderr}\n`)
		end
		return false
	end

	return true
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function main()
	log("Starting jest-rodeo binary build process...")

	ensureDir("build")

	-- Step 1: Bundle source with darklua
	log("Step 1/2: Bundling source with darklua")

	local bundleSuccess = runCommand("darklua", { "process", "src", "build/bundle", "--config", ".lune/bundle.darklua.json" }, "Running darklua bundler")

	if not bundleSuccess then
		process.exit(1)
	end

	-- Step 2: Build binaries for each platform
	log("Step 2/2: Building platform-specific binaries")

	ensureDir("build/releases")

	for _, target in TARGETS do
		local platformName = `{target.os}-{target.arch}`
		local outputPath = `build/releases/jest-rodeo_{platformName}{target.ext}`
		local targetArg = `{target.os}-{target.arch}`

		local buildSuccess = runCommand("lune", { "build", "build/bundle/init.luau", "-o", outputPath, "--target", targetArg }, `Building for {platformName}`)

		if not buildSuccess then
			stdio.ewrite(`Warning: Failed to build for {platformName}, continuing...\n`)
		else
			local fileSize = #fs.readFile(outputPath)
			log(`  Created {outputPath} ({fileSize} bytes)`)
		end
	end

	log("Build complete! Binaries are in build/releases/")
end

main()
