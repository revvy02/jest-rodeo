# jest-rodeo

CLI companion for [jest-luau](https://github.com/jsdotlua/jest-lua). Run your tests in your current Studio session, via Roblox Cloud execution, or by opening a new place file - all routes results back to the CLI.

Requires [rodeo](https://github.com/revvy02/rodeo) for `--target once` and `--target serve`.

## Installation

### via pesde

```bash
pesde add rvy/jest-rodeo
```

### via mise

```bash
mise use ubi:rvy/jest-rodeo
```

### via rokit

```bash
rokit add revvy02/jest-rodeo
```

## Features

- Run tests in Roblox Studio via `rodeo once` (one-time execution, like run-in-roblox)
- Run tests in Roblox Studio via `rodeo serve/exec` (executes in your current Studio session)
- Run tests in Roblox Cloud via Open Cloud API
- Filter tests by name or path patterns
- Support for multiple project configurations
- Configuration via `jest-rodeo.toml` and environment variables
- Output control with `--no-error` and `--no-warn` flags

## Usage

Run `jest-rodeo` to execute tests in your current Studio session (serve mode). Use the `--target` flag to specify a different execution method.

### Targets

#### `--target once`
Runs tests via `rodeo once` - similar to run-in-roblox. Clones the place file to `.jest-rodeo/` temp directory and always opens a fresh Studio instance for testing. **Requires rodeo to be installed.**

**Note:** You must build/maintain the place file yourself - jest-rodeo does not build it.

```bash
# Run all tests via rodeo once
jest-rodeo --target once

# Run with test filtering
jest-rodeo --target once --test-name-pattern "async" --project shared

# Specify custom place file
jest-rodeo --target once --place my-test.rbxl
```

#### `--target serve`
Executes tests in your current Studio session via `rodeo exec`. Assumes `rodeo serve` is already running and connected to Studio. Does not build or clone place files. **Requires rodeo to be installed and running.**

```bash
# Run all tests via rodeo exec
jest-rodeo --target serve

# Run specific tests
jest-rodeo --target serve --test-path-pattern "use_async"
```

#### `--target cloud`
Runs tests in Roblox Cloud using the Open Cloud Luau Execution API. Requires universe ID, place ID, place version, and API key.

```bash
# Run tests in cloud (using jest-rodeo.toml config)
jest-rodeo --target cloud

# Upload place file and run tests in cloud (uses returned version)
jest-rodeo --target cloud --upload

# Override config with CLI flags
jest-rodeo --target cloud --universe-id <id> --place-id <id> --place-version <version> --api-key <key>

# Run specific project in cloud
jest-rodeo --target cloud --project shared
```

**Cloud Configuration:**
- API key: `--api-key` flag, `jest-rodeo_API_KEY` environment variable, or `.env` file
- Universe ID: `--universe-id` flag or `jest-rodeo.toml` `[cloud]` section
- Place ID: `--place-id` flag or `jest-rodeo.toml` `[cloud]` section
- Place Version: `--place-version` flag or `jest-rodeo.toml` `[cloud]` section (optional if `--upload` is used)
- Upload: `--upload` flag or `jest-rodeo.toml` `[cloud]` section (uploads place file and uses returned version)
- Place File: `--place` flag or `jest-rodeo.toml` `[once.place_file]` section (required when using `--upload`)

### Filtering Tests

```bash
# Filter by test name (matches test descriptions)
jest-rodeo --target once --test-name-pattern "should handle errors"

# Filter by test file path
jest-rodeo --target serve --test-path-pattern "use_async"

# Combine filters
jest-rodeo --target once --test-name-pattern "user" --test-path-pattern "auth"
```

### Output Control

jest-rodeo provides flags to control rodeo output verbosity for `once` and `serve` targets:

```bash
# Suppress error and info output from rodeo
jest-rodeo --target serve --no-error

# Suppress warning output from rodeo
jest-rodeo --target once --no-warn

# Combine flags for minimal output
jest-rodeo --target serve --no-error --no-warn
```

**Output Flags:**
- `--no-error`: Suppresses error and info messages from rodeo
- `--no-warn`: Suppresses warning messages from rodeo
- These flags only affect rodeo's internal output, test results are still shown

### Project Configuration

Create a `jest-rodeo.toml` file in your project root:

```toml
[once]
place_file = "test.rbxl"  # Also used by --target cloud when --upload is enabled

[cloud]
place_id = 72824109308551
universe_id = 8612861022
place_version = 51  # Optional if upload is true
upload = false

[projects]
shared = "src/shared"
client = "src/client"
server = "src/server"
hooks = "src/client/app/hooks"
```

**Configuration Details:**
- `[once].place_file`: Path to your built place file for `--target once` and `--target cloud --upload`
- `[cloud].place_id`: Roblox place ID for cloud execution
- `[cloud].universe_id`: Roblox universe ID for cloud execution
- `[cloud].place_version`: Specific place version to run tests against (optional if upload is true)
- `[cloud].upload`: Upload the place file before running tests (default: false)
- `[projects]`: Named project paths that can be referenced with `--project` flag

**Environment Variables:**
- `jest-rodeo_API_KEY`: Roblox Open Cloud API key (alternative to `--api-key` flag)

You can also create a `.env` file in your project root:

```env
jest-rodeo_API_KEY=your-api-key-here
```

Then use project names to run specific projects:

```bash
jest-rodeo --target once --project shared
```

### Examples

```bash
# Run tests in serve mode (default - connects to current Studio session)
jest-rodeo

# Run specific project in serve mode
jest-rodeo --project shared

# Filter tests in serve mode
jest-rodeo --test-path-pattern "use_async"

# Run all tests via rodeo once (opens new Studio instance)
jest-rodeo --target once

# Run tests in cloud (using jest-rodeo.toml)
jest-rodeo --target cloud

# Upload place file and run tests in cloud
jest-rodeo --target cloud --upload

# Filter by test name
jest-rodeo --target once --test-name-pattern "async"

# Suppress rodeo errors and warnings
jest-rodeo --no-error --no-warn

# Verbose output
jest-rodeo --verbose

# CI mode
jest-rodeo --target cloud --ci

# Combined: upload, filter, and suppress output
jest-rodeo --target cloud --upload --project shared --no-error
```

