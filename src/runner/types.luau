--!strict

export type RunTarget = "cloud" | "once" | "serve"

export type CloudConfig = {
	module: string,
	setup: string?,
	target: "cloud",
	universeId: string,
	placeId: string,
	placeVersion: string?,
	apiKey: string,
	upload: boolean?,
	placePath: string?,
}

export type OnceConfig = {
	module: string,
	setup: string?,
	target: "once",
	placePath: string,
	noError: boolean?,
	noWarn: boolean?,
}

export type ServeConfig = {
	module: string,
	setup: string?,
	target: "serve",
	noError: boolean?,
	noWarn: boolean?,
}

export type RunTargetConfig = CloudConfig | OnceConfig | ServeConfig

return nil
