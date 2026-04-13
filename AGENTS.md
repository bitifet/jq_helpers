# AGENTS.md

## Testing
```bash
./test/filter_tests.sh
```

## Key conventions

- **Quote escaping in examples**: When documenting functions that output jq filters with embedded string arguments (e.g., `jq_period`), escape quotes in examples:
  ```bash
  # Correct (escaped for shell interpolation)
  jq "$(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\")"
  
  # Wrong (will fail at shell level)
  jq "$(jq_period "2025-09-24T00:00:00Z" "2025-10-07T23:59:59Z")"
  ```

- **Script must be sourced**: `jq_filters.sh` is not executed directly; source it:
  ```bash
  source ./src/jq_filters.sh
  ```

- **Use `$()` for interpolation**: Functions output jq filter strings to be interpolated:
  ```bash
  cat logs.json | jq "$(jq_toTimestamp)"
  ```
