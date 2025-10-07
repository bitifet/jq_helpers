#!/bin/bash

BASE_PATH=$(dirname "$0")
source "$BASE_PATH/../src/jq_filters.sh"

# Test function
run_test() {
    local msg="$1" input="$2" expected="$3"
    result=$(jq -e "${testFilter}" <<< "$input" 2>/dev/null || echo "<ERROR>")
    status=$?
    [[ "$result" == "$expected" ]] && echo "  ✔️ PASS: $msg" || { echo "  ✖️ FAIL: $msg: expected '$expected', got '$result'"; exit 1; }
}

run_test_suite() {
    local heading=("$1")
    local testFilter="$2|tostring"
    local tests=("${@:3}")

    # Print heading
    echo ""
    echo "📌 ${heading}:"

    # Run all tests
    for test in "${tests[@]}"; do
        IFS=';' read -r msg input expected fail <<< $(echo "$test" | sed -E 's/(\s+(;)|^)\s+/\2/g')
        run_test "$msg" "$input" "$expected" "$fail"
    done
}


##################################################
heading="Running tests for jq_toTimestamp filter"
# ------------------------------------------------

testFilter="$(jq_toTimestamp) | todate"
                              ## Convert to timestamp and back to ISO 8601 string for easier human inspection

# Array of tests: (message, input, expected_output)
tests=(
    "ISO 8601 with timezone offset to UTC     ; \"2025-09-24T13:17:06.438+0200\"  ; \"2025-09-24T11:17:06Z\""
    "ISO 8601 with Z to UTC                   ; \"2025-09-24T13:17:06.438Z\"      ; \"2025-09-24T13:17:06Z\""
    "ISO 8601 without timezone to UTC         ; \"2025-09-24T13:17:06.438\"       ; \"2025-09-24T11:17:06Z\""
    "custom date format to UTC                ; \"24/9/2025, 0:00:12\"            ; \"2025-09-23T22:00:12Z\""
    "millisecond timestamp to UTC             ; \"1759762093142\"                 ; \"2025-10-06T14:48:13Z\""
    "second timestamp to UTC                  ; \"1759762093\"                    ; \"2025-10-06T14:48:13Z\""
    "millisecond timestamp (no quotes) to UTC ; 1759762093142                     ; \"2025-10-06T14:48:13Z\""
    "second timestamp (no quotes) to UTC      ; 1759762093                        ; \"2025-10-06T14:48:13Z\""
    "timestamp with decimals to UTC           ; 1759762093.123                    ; \"2025-10-06T14:48:13Z\""
    "invalid timestamp                        ; \"175aa62093\"                    ; <ERROR>"
)

run_test_suite "$heading" "$testFilter" "${tests[@]}"


##################################################
heading="Running tests for jq_fromTimestamp filter"
# ------------------------------------------------

testFilter="$(jq_fromTimestamp)"
                              ## Convert to timestamp and back to ISO 8601 string for easier human inspection

# Array of tests: (message, input, expected_output)
tests=(
    "ISO 8601 with timezone offset to local ISO     ; \"2025-09-24T13:17:06.438+0200\"  ; \"2025-09-24T13:17:06+0200\""
    "ISO 8601 with Z to local ISO                   ; \"2025-09-24T13:17:06.438Z\"      ; \"2025-09-24T15:17:06+0200\""
    "ISO 8601 without timezone to local ISO         ; \"2025-09-24T13:17:06.438\"       ; \"2025-09-24T13:17:06+0200\""
    "custom date format to local ISO                ; \"24/9/2025, 0:00:12\"            ; \"2025-09-24T00:00:12+0200\""
    "millisecond timestamp to local ISO             ; \"1759762093142\"                 ; \"2025-10-06T16:48:13+0200\""
    "second timestamp to local ISO                  ; \"1759762093\"                    ; \"2025-10-06T16:48:13+0200\""
    "millisecond timestamp (no quotes) to local ISO ; 1759762093142                     ; \"2025-10-06T16:48:13+0200\""
    "second timestamp (no quotes) to local ISO      ; 1759762093                        ; \"2025-10-06T16:48:13+0200\""
    "timestamp with decimals to local ISO           ; 1759762093.123                    ; \"2025-10-06T16:48:13+0200\""
    "invalid timestamp                              ; \"175aa62093\"                    ; <ERROR>"
)

run_test_suite "$heading" "$testFilter" "${tests[@]}"



##################################################
heading="Running tests for jq_period filter"
# ------------------------------------------------

testFilter="$(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\")"

# Array of tests: (message, input, expected_output)
tests=(
    "within period (ISO 8601 with Z)             ; \"2025-09-24T13:17:06Z\"      ; \"true\""
    "within period (ISO 8601 with offset)        ; \"2025-09-24T15:17:06+0200\"  ; \"true\""
    "within period (custom format)               ; \"24/9/2025, 13:17:06\"       ; \"true\""
    "within period (timestamp)                   ; \"1758796266000\"             ; \"true\""
    "before period (ISO 8601)                    ; \"2025-09-23T23:59:59Z\"      ; \"false\""
    "after period (ISO 8601)                     ; \"2025-10-08T00:00:00Z\"      ; \"false\""
    "at period start (ISO 8601)                  ; \"2025-09-24T00:00:00Z\"      ; \"true\""
    "at period end (ISO 8601)                    ; \"2025-10-07T23:59:59Z\"      ; \"true\""
    "invalid timestamp                           ; \"175aa62093\"                ; \"false\"" # No or bad timestamp => not in period.
)

run_test_suite "$heading" "$testFilter" "${tests[@]}"



##################################################
echo ""
echo "✅ All tests passed!"
