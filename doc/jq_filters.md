# jq_filters.sh Documentation

## Overview
`jq_filters.sh` is a Bash script designed to provide a set of `jq` filters for processing JSON logs, particularly for handling timestamp conversions and period checks. The script is intended to be sourced (not executed directly) to make its functions available for use in other scripts or shell sessions. It supports converting various timestamp formats to epoch seconds, converting timestamps to ISO 8601 format in local time, and checking if a timestamp falls within a specified period.

## Usage
1. **Source the Script**:
   ```bash
   source ~/bin/jq_filters.sh
   ```
2. **Use Filters in `jq` Commands**:
   Pipe JSON log data through `jq` using the provided filter functions, combined as needed:
   ```bash
   cat some.log | jq "$(jq_toTimestamp) | $(jq_fromTimestamp)"
   ```

## Prerequisites
- **Bash**: The script requires a Bash shell environment.
- **jq**: Version 1.7 or later is recommended for correct timezone handling. If an earlier version is detected, a warning is displayed indicating potential issues with timezone offsets.
- **Environment**: The script uses the system's timezone (`date +%z`) by default unless overridden by setting the `TZ` variable.

## Configuration
The script includes a configuration section with the following settings:

- **`NON_ISO_TIMESTAMP`**:
  - Format: `%d/%m/%Y, %H:%M:%S` (e.g., `24/9/2025, 13:17:06`)
  - Defines the expected format for non-ISO 8601 timestamp inputs.
- **`TZ`**:
  - Default: System timezone (e.g., `+0200`).
  - Can be overridden by setting the `TZ` environment variable (e.g., `export TZ=+1000`).
- **`TZ_OFFSET`**:
  - Automatically calculated from `TZ` in seconds (e.g., `+0200` becomes `7200` seconds).
  - Used to adjust timestamps when no timezone is specified.

## Functions
The script defines the following `jq` filter functions within a `main` function, which is called upon sourcing and then unset to avoid polluting the environment.

### `jq_toTimestamp`
- **Purpose**: Converts an input timestamp (ISO 8601, non-ISO format, or epoch seconds/milliseconds) to epoch seconds.
- **Input**: A string or number representing a timestamp, such as:
  - ISO 8601: `"2025-09-24T13:17:06.438+0200"`, `"2025-09-24T13:17:06Z"`, `"2025-09-24T13:17:06"`
  - Custom format: `"24/9/2025, 0:00:12"` (matches `NON_ISO_TIMESTAMP`)
  - Epoch: `"1759762093142"` (milliseconds), `"1759762093"` (seconds), or unquoted equivalents
- **Output**: Epoch seconds (integer) or an error message (`"Unrecognized time format"`) if the input is invalid.
- **Logic**:
  - Parses ISO 8601 timestamps, extracting the raw time and timezone offset.
  - Calculates the offset in seconds (e.g., `+0200` → `7200` seconds) or uses `TZ_OFFSET` for non-specified timezones.
  - Converts the timestamp to epoch seconds using `jq`'s `fromdate`, adjusting for the offset.
  - Falls back to parsing non-ISO formats using `strptime` with `NON_ISO_TIMESTAMP`.
  - Handles epoch milliseconds (divides by 1000 if > `9999999999`) or seconds directly.
- **Example**:
  ```bash
  echo '"2025-09-24T13:17:06.438+0200"' | jq "$(jq_toTimestamp)"
  # Output: 1758796626
  ```

### `jq_fromTimestamp`
- **Purpose**: Converts an input timestamp to an ISO 8601 timestamp in the local timezone (defined by `TZ`).
- **Input**: Same as `jq_toTimestamp` (ISO 8601, non-ISO, or epoch).
- **Output**: ISO 8601 string with the local timezone (e.g., `"2025-09-24T13:17:06+0200"`).
- **Logic**:
  - Uses `jq_toTimestamp` to convert the input to epoch seconds.
  - Adds `TZ_OFFSET` to adjust to the local timezone.
  - Converts to ISO 8601 using `todateiso8601` and appends the `TZ` suffix (e.g., `+0200`).
- **Example**:
  ```bash
  echo '"2025-09-24T13:17:06Z"' | jq "$(jq_fromTimestamp)"
  # Output: "2025-09-24T15:17:06+0200" (assuming TZ=+0200)
  ```

### `jq_period <start> <end>`
- **Purpose**: Checks if an input timestamp falls within a specified time period (inclusive).
- **Arguments**:
  - `start`: Start of the period (any format supported by `jq_toTimestamp`).
  - `end`: End of the period (any format supported by `jq_toTimestamp`).
- **Input**: A timestamp (same formats as `jq_toTimestamp`).
- **Output**: `true` if the timestamp is within `[start, end]`, `false` otherwise, or an error if the input is invalid.
- **Logic**:
  - Converts the input, `start`, and `end` to epoch seconds using `jq_toTimestamp`.
  - Checks if the input timestamp is `>= start` and `<= end`.
- **Example**:
  ```bash
  echo '"2025-09-24T13:17:06Z"' | jq "$(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\")"
  # Output: true
  ```

### `jq_invalidtimeformat`
- **Purpose**: Detects if a timestamp is not in ISO 8601 format (undocumented utility function).
- **Input**: A timestamp string.
- **Output**: `true` if the input is not ISO 8601, `false` otherwise.
- **Logic**:
  - Strips sub-second precision and attempts to parse with `fromdate`.
  - Returns `true` if parsing fails (indicating non-ISO format).
- **Note**: This function is intentionally undocumented and used internally for format detection.

## Error Handling
- **Invalid Timestamps**: All functions return an error (captured as `<ERROR>` in tests) for invalid inputs (e.g., `"175aa62093"`).
- **jq Version Check**: On sourcing, the script checks the `jq` version. If it’s earlier than 1.7, a warning is displayed about potential timezone handling issues, but execution continues.
- **Timezone Handling**: If no timezone is specified in the input, the script uses `TZ_OFFSET` (derived from `TZ` or system timezone).

## Testing
The script is accompanied by a comprehensive test suite (`test_library.sh`) that validates the behavior of `jq_toTimestamp`, `jq_fromTimestamp`, and `jq_period`. The tests cover:
- Various input formats (ISO 8601 with/without timezone, custom format, epoch seconds/milliseconds, quoted/unquoted).
- Edge cases (invalid timestamps, period boundaries).
- Expected outputs and errors.

To run the tests:
```bash
./test/test_library.sh
```

## Limitations
- **jq Version**: Requires `jq` 1.7+ for reliable timezone handling. Earlier versions may misinterpret offsets.
- **Timezone**: Assumes a consistent timezone (`TZ`) for non-ISO inputs. Dynamic timezone changes during execution may cause inconsistencies.
- **Sub-second Precision**: ISO 8601 inputs with sub-second precision are stripped before processing, as `jq` does not support sub-seconds in `fromdate`.
- **Non-ISO Format**: Limited to the `NON_ISO_TIMESTAMP` format (`%d/%m/%Y, %H:%M:%S`). Other formats require modification of the configuration.

## Example Commands
Below are examples demonstrating how to use the `jq_filters.sh` functions to process JSON logs, including basic and advanced use cases inspired by real-world log processing scenarios.

### Basic Examples
1. **Convert a Log Timestamp to Epoch Seconds**:
   Convert a timestamp field in a JSON log to epoch seconds.
   ```bash
   echo '{"time": "2025-09-24T13:17:06.438+0200"}' | jq ".time |= $(jq_toTimestamp)"
   # Output: {"time": 1758796626}
   ```

2. **Convert a Log Timestamp to Local ISO 8601**:
   Convert a timestamp field to ISO 8601 in the local timezone.
   ```bash
   echo '{"time": "2025-09-24T13:17:06Z"}' | jq ".time |= $(jq_fromTimestamp)"
   # Output: {"time": "2025-09-24T15:17:06+0200"} (assuming TZ=+0200)
   ```

3. **Filter Logs Within a Date Range**:
   Select logs where the `time` field falls within a specified period.
   ```bash
   echo '{"time": "2025-09-24T13:17:06Z"}' | jq "$(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\")"
   # Output: true
   ```

4. **Combine Filters**:
   Convert a timestamp to local ISO 8601 after ensuring it’s in a valid format.
   ```bash
   echo '{"time": "24/9/2025, 0:00:12"}' | jq ".time |= ($(jq_toTimestamp) | $(jq_fromTimestamp))"
   # Output: {"time": "2025-09-24T00:00:12+0200"} (assuming TZ=+0200)
   ```

### Advanced Examples
These examples demonstrate more complex log processing scenarios, such as filtering specific log entries, transforming timestamps, and extracting relevant fields from structured JSON logs.

5. **Monitor Watchdog Logs**:
   Filter JSON logs from a `watchdog` module within a 2-hour time window, convert timestamps to local ISO 8601, and extract key fields (e.g., `time`, `message`, `alive`, `delta_time`). This is useful for monitoring system health checks.
   ```bash
   zcat myApp-watchdog__2025-09-24.log.gz | grep '^{' | jq "
     select(
       (.time | $(jq_period \"2025-09-24T13:17:06.438+0200\" \"2025-09-24T15:17:06.438+0200\"))
       and (.module == \"watchdog\")
     )
     | .time = (.time | $(jq_fromTimestamp))
     | {
         time,
         message,
         alive,
         delta_time
       }
   "
   ```
   **Example Input**:
   ```json
   {"time": "2025-09-24T13:30:00Z", "module": "watchdog", "message": "System check", "alive": true, "delta_time": 120}
   ```
   **Example Output**:
   ```json
   {
     "time": "2025-09-24T15:30:00+0200",
     "message": "System check",
     "alive": true,
     "delta_time": 120
   }
   ```

6. **Identify High-Latency HTTP Requests**:
   Filter JSON logs for HTTP server requests with latency exceeding 10 seconds within a 2-hour time window, convert timestamps to local ISO 8601, and extract relevant fields (e.g., `time`, `msg`, `method`, `status`, `elapsed`, `url`, `referer`). This is useful for performance analysis.
   ```bash
   zcat myApp-pro-error__2025-09-24.log.gz | grep '^{' | jq "
     select(
       (.time | $(jq_period \"2025-09-24T13:17:06.438+0200\" \"2025-09-24T15:17:06.438+0200\"))
       and (.connection.type == \"httpserver\")
       and (.elapsed > 10000)
     )
     | .time = (.time | $(jq_fromTimestamp))
     | {
         time,
         msg,
         method,
         status,
         elapsed,
         url,
         referer
       }
   "
   ```
   **Example Input**:
   ```json
   {"time": "2025-09-24T13:45:00Z", "connection": {"type": "httpserver"}, "elapsed": 12000, "msg": "Request completed", "method": "GET", "status": 200, "url": "/api/data", "referer": "https://example.com"}
   ```
   **Example Output**:
   ```json
   {
     "time": "2025-09-24T15:45:00+0200",
     "msg": "Request completed",
     "method": "GET",
     "status": 200,
     "elapsed": 12000,
     "url": "/api/data",
     "referer": "https://example.com"
   }
   ```

7. **Count Logs by Module in a Time Period**:
   Count the number of log entries per module within a specified time period, useful for summarizing log activity.
   ```bash
   zcat myApp__2025-09-24.log.gz | grep '^{' | jq "
     select(.time | $(jq_period \"2025-09-24T00:00:00Z\" \"2025-09-24T23:59:59Z\"))
     | .time = (.time | $(jq_fromTimestamp))
     | group_by(.module)
     | map({ module: .[0].module, count: length })
   "
   ```
   **Example Input**:
   ```json
   {"time": "2025-09-24T10:00:00Z", "module": "watchdog", "message": "Check"}
   {"time": "2025-09-24T11:00:00Z", "module": "httpserver", "message": "Request"}
   {"time": "2025-09-24T12:00:00Z", "module": "watchdog", "message": "Check"}
   ```
   **Example Output**:
   ```json
   [
     {"module": "httpserver", "count": 1},
     {"module": "watchdog", "count": 2}
   ]
   ```

8. **Filter and Clean Invalid Timestamps**:
   Filter logs with valid timestamps and convert them to local ISO 8601, excluding entries with non-ISO 8601 timestamps that cannot be parsed.
   ```bash
   zcat myApp__2025-09-24.log.gz | grep '^{' | jq "
     select(.time | $(jq_invalidtimeformat) | not)
     | .time = (.time | $(jq_fromTimestamp))
   "
   ```
   **Example Input**:
   ```json
   {"time": "2025-09-24T13:17:06Z", "message": "Valid"}
   {"time": "invalid", "message": "Invalid"}
   ```
   **Example Output**:
   ```json
   {"time": "2025-09-24T15:17:06+0200", "message": "Valid"}
   ```

## Notes
- The script is designed to be sourced, not executed directly, to avoid polluting the shell environment.
- Variables like `TZ`, `TZ_OFFSET`, and `JQ_VERSION` are set globally but cleaned up where possible (e.g., `main` function is unset after execution).
- The `jq_invalidtimeformat` function is an internal utility and not intended for direct use.
