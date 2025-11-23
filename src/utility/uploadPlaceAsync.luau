--!strict

local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")

local chalk = require("@pkg/chalk")
local spin = require("@pkg/spin")

export type UploadPlaceOptions = {
	universeId: number,
	placeId: number,
	apiKey: string,
	filePath: string,
}

export type UploadPlaceResult = {
	versionNumber: number,
}

local function uploadPlaceAsync(options: UploadPlaceOptions): UploadPlaceResult?
	local universeId = options.universeId
	local placeId = options.placeId
	local apiKey = options.apiKey
	local filePath = options.filePath

	local renderer = spin.render(spin.animations.arc, function(frame: string, text: string)
		return chalk.green(chalk.bold(frame .. " " .. text))
	end)
	local _setText, stop = spin.start(renderer, "Uploading place file...")

	local readSuccess, placeFile = pcall(fs.readFile, filePath)
	if not readSuccess then
		stop()
		print(chalk.red(chalk.bold("Failed to read place file")))
		return nil
	end

	local res = net.request({
		url = `https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions`,
		method = "POST",
		body = placeFile,
		query = {
			versionType = "Published",
		},
		headers = {
			["x-api-key"] = apiKey,
			["Content-Type"] = "application/octet-stream",
			["Accept"] = "application/json",
		},
	})

	stop()

	local decodedBody = serde.decode("json", res.body)
	if res.ok then
		print(chalk.green(chalk.bold(`Place uploaded successfully (version {decodedBody.versionNumber})`)))
		return {
			versionNumber = decodedBody.versionNumber,
		}
	else
		print(chalk.red(chalk.bold("Failed to upload place file")))
		print(decodedBody)
		return nil
	end
end

return uploadPlaceAsync
