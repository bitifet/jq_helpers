# jq_helpers

*jq_helpers* is a collection of tools to assist with processing JSON logs using
jq.

It simplifies complex jq queries by providing reusable bash functions that
produce advanced jq filters for processing JSON logs.

## Features

  * Generate jq filters for common log processing tasks
    - Generators can accept parameters.

  * Combine multiple filters for complex queries
    - Build your own scripts for custom reports.

  * Normalize timestamps to ISO 8601 in local timezone:
    - Preserves readability.
    - Ensures sortability.
    - Keep interoperability.

  * Filter logs by time range.

  * Easy to extend with custom filters.

  * Built-in help via `jq_help`.


## Overview

```
.
├── README.md            →  This file
├── src
│   └── jq_filters.sh    →  Advanced jq filters generators
├── doc
│   └── jq_filters.md    →  Usage documentation for jq_filters.sh
├── examples
│   └── reports.sh       →  Sample script to generate advanced reports
└── test
    └── filter_tests.sh  →  Unit tests for jq_filters.sh
```

## Requirements

  * bash
  * jq >= 1.7

## Usage

  1. Source the script to load all filter functions:
     ```bash
     source ./path/to/jq_filters.sh
     ```

  2. Explore available functions:
     ```bash
     jq_help
     ```

  3. Use the filter functions inside `jq` commands via `$()` interpolation:
     ```bash
     cat some.log | jq "$(jq_toTimestamp)"
     cat some.log | jq ".time |= $(jq_fromTimestamp)"
     cat some.log | jq "select(.time | $(jq_period "2025-09-24T00:00:00Z" "2025-10-07T23:59:59Z"))"
     ```

## Filter Functions

After sourcing `jq_filters.sh`, the following functions are available. Each
function **outputs a jq filter string** that is meant to be interpolated into a
`jq` expression using `$()`.

| Function | Description |
|---|---|
| `jq_toTimestamp` | Convert any timestamp to epoch seconds |
| `jq_fromTimestamp` | Convert any timestamp to ISO 8601 in local timezone |
| `jq_period <start> <end>` | Check if a timestamp falls within a time period |
| `jq_invalidtimeformat` | Detect timestamps not in ISO 8601 format |
| `jq_help [function]` | Show help, or detailed help for a specific function |

### `jq_help`

`jq_help` is a built-in help command available after sourcing the script.

```bash
# List all available filter functions:
jq_help

# Show detailed help and examples for a specific function:
jq_help jq_toTimestamp
jq_help jq_fromTimestamp
jq_help jq_period
jq_help jq_invalidtimeformat
```

### `jq_toTimestamp`

Converts any supported timestamp to **epoch seconds** (UTC).

Supported input formats:
- ISO 8601 with timezone offset: `"2025-09-24T13:17:06.438+0200"`
- ISO 8601 UTC: `"2025-09-24T13:17:06Z"`
- ISO 8601 without timezone: `"2025-09-24T13:17:06"` (assumes local TZ)
- Custom format: `"24/9/2025, 0:00:12"` (see `NON_ISO_TIMESTAMP` config)
- Epoch milliseconds (string or number): `"1759762093142"` / `1759762093142`
- Epoch seconds (string or number): `"1759762093"` / `1759762093`

```bash
# Convert a standalone timestamp string to epoch seconds:
echo '"2025-09-24T13:17:06.438+0200"' | jq "$(jq_toTimestamp)"
# Output: 1758796626

# Convert a timestamp field inside a JSON object to epoch seconds:
echo '{"time": "2025-09-24T13:17:06.438+0200"}' | jq ".time |= $(jq_toTimestamp)"
# Output: {"time": 1758796626}
```

### `jq_fromTimestamp`

Converts any supported timestamp to **ISO 8601 in the local timezone** (as set
by `TZ` or the system timezone).

```bash
# Normalize a standalone timestamp string to local ISO 8601:
echo '"2025-09-24T13:17:06Z"' | jq "$(jq_fromTimestamp)"
# Output: "2025-09-24T15:17:06+0200"  (assuming TZ=+0200)

# Normalize a timestamp field inside a JSON object:
echo '{"time": "2025-09-24T13:17:06Z"}' | jq ".time |= $(jq_fromTimestamp)"
# Output: {"time": "2025-09-24T15:17:06+0200"}

# Chain: convert epoch seconds back to local ISO 8601:
echo '1758796626' | jq "$(jq_fromTimestamp)"
# Output: "2025-09-24T13:17:06+0200"  (assuming TZ=+0200)
```

### `jq_period <start> <end>`

Returns `true` if the input timestamp falls within `[start, end]` (inclusive).
Both `start` and `end` accept any format supported by `jq_toTimestamp`.

```bash
# Check a standalone timestamp:
echo '"2025-09-24T13:17:06Z"' | jq "$(jq_period "2025-09-24T00:00:00Z" "2025-10-07T23:59:59Z")"
# Output: true

# Use as a select filter on a .time field in a log stream:
cat app.log | jq "select(.time | $(jq_period "2025-09-24T00:00:00Z" "2025-10-07T23:59:59Z"))"

# Combine with jq_fromTimestamp to filter and normalize in one pass:
cat app.log | jq "
  select(.time | $(jq_period "2025-09-24T00:00:00Z" "2025-10-07T23:59:59Z"))
  | .time |= $(jq_fromTimestamp)
"
```

### `jq_invalidtimeformat`

Returns `true` if the input is **not** a valid ISO 8601 timestamp. Useful for
flagging or skipping log entries with non-standard timestamps.

```bash
# Test a valid ISO 8601 timestamp:
echo '"2025-09-24T13:17:06Z"' | jq "$(jq_invalidtimeformat)"
# Output: false

# Test a custom-format timestamp:
echo '"24/9/2025, 0:00:12"' | jq "$(jq_invalidtimeformat)"
# Output: true

# Keep only entries whose .time field is already ISO 8601, then normalize:
cat app.log | jq "
  select(.time | $(jq_invalidtimeformat) | not)
  | .time |= $(jq_fromTimestamp)
"
```

## Documentation

  * [jq filter generators](doc/jq_filters.md) for detailed usage instructions and examples.

## Remote Sourcing

You can load `jq_filters.sh` directly from GitHub without keeping a local copy,
using process substitution:

```bash
source <(curl -fsSL https://raw.githubusercontent.com/bitifet/jq_helpers/main/src/jq_filters.sh)
```

> **Security recommendation:** Pin to a specific commit SHA instead of `main`
> to avoid unintentionally running updated (or compromised) code:
>
> ```bash
> # Replace <COMMIT_SHA> with a known-good commit hash, e.g. cc7d60e
> source <(curl -fsSL https://raw.githubusercontent.com/bitifet/jq_helpers/<COMMIT_SHA>/src/jq_filters.sh)
> ```
>
> Additional precautions:
> - **Inspect before sourcing**: download and review the script first.
>   ```bash
>   curl -fsSL https://raw.githubusercontent.com/bitifet/jq_helpers/main/src/jq_filters.sh | less
>   ```
> - **Use HTTPS** (the `curl` commands above already do this).
> - **Avoid in automated/production pipelines** unless you have verified and
>   pinned to a trusted commit.

## Testing

Run the test suite:

```bash
./test/filter_tests.sh
```
