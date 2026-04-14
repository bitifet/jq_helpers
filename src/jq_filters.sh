# jq filters for JSON logs
#
# USAGE:
#   1. Import filters:
#      `source ./path/to/jq_filters.sh`
#   2. Use filters:
#      `cat some.log | jq "$(f1 args..) | $(f2 args...)"
#


# This script is not meant to be executed directly.
# It contains jq filters for JSON logs processing.
# Please source it in your shell or another script.
function main() {

    ### ############## ###
    ### Config Section ###
    ### ############## ###

    # Text timestamps format (other than ISO 8601):
    NON_ISO_TIMESTAMP="%d/%m/%Y, %H:%M:%S"

    # Time zone for NON_ISO_TIMESTAMP:
    # (comment out to use different than current one).
    #TZ=+1000


    ### Default values:
    ### ---------------

    if [[ -z "${TZ:-}" ]]; then
        TZ=$(date +%z)
    fi

    #TZ_OFFSET="..."{{{
    _() {
      local hours=$(echo "${TZ}" | cut -c1,2-3)
      local minutes=$(echo "${TZ}" | cut -c1,4-5)
      local offset_seconds=$(( ($hours * 3600 + $minutes * 60) ))
      echo "$offset_seconds"
    }
    TZ_OFFSET=$(_)
    unset -f _
    # }}}


    ### ##################### ###
    ### Verifications section ###
    ### ##################### ###

    # Minimal jq version{{{
    JQ_VERSION=$(jq --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    TARGET_VERSION="1.7"

    if [[ 
        ${JQ_VERSION} != "${TARGET_VERSION}"
        && $(echo -e "$JQ_VERSION\n$TARGET_VERSION" | sort -V -r | head -n1) == "$TARGET_VERSION"
    ]]; then

        echo "================================================="
        echo " ⚠️ jq version ($JQ_VERSION) is earlier than $TARGET_VERSION"
        echo " -----------------------------------------------"
        echo " Timezone offset will not be handled correctly."
        echo " Please update jq to version $TARGET_VERSION or later."
        echo "================================================="
        echo ""
    fi
    # }}}

    ### ####### ###
    ### Filters ###
    ### ####### ###

    # jq_toTimestamp() <ISO or NON-ISO timestamp string to epoch seconds>{{{
    jq_toTimestamp() {
      echo ". |(
        # ISO 8601:
        try (
          # Get raw time and offset parts.
          # and strip seconds (not supported in jq):
          capture(
              \"(?<rawtime>.*?)(\\\\.[0-9]+)?(?<tzSpec>(?<oSign>[+-])(?<oHours>[0-9]{1,2})(?<oMins>[0-9]{2})|Z?)\$\"
          ) as \$parts

          # Calculate offset in seconds:
          | (
            try (
              ((\$parts.oSign + \$parts.oHours) | tonumber | . * 3600) # offsetHours
              + ((\$parts.oSign + \$parts.oMins) | tonumber | . * 60) # offsetMins
            ) catch ( # If captured it should be "Z" or empty (no tz info)
              if \$parts.tzSpec == \"Z\" then 0   ## UTC
              else ${TZ_OFFSET}                   ## Local time zone offset
              end
            )
          ) as \$offsetSecs


          | \$parts.rawtime + \"Z\"
          | fromdate
          | . - \$offsetSecs

        )
        // try (strptime(\"$NON_ISO_TIMESTAMP\") | todate | fromdate - ${TZ_OFFSET} )
        // (
            (try tonumber)
            | if (. > 9999999999) then . / 1000 else . end ## Epoch milliseconds to seconds
        )
        // (\"Unrecognized time format\")
     )"
    }
    # }}}

    # jq_fromTimestamp() <everything to ISO 8601 timestamp in local time>{{{
    jq_fromTimestamp() {
        echo "( .
            | $(jq_toTimestamp)
            | . + (${TZ_OFFSET})
            | todateiso8601
            | sub(\"Z\$\"; \"${TZ}\")
        )"
    }
    # }}}

    # jq_invalidtimeformat() <detect non ISO 8601 timestamp>{{{
    jq_invalidtimeformat() {
      # Intentionally undocumented
      # Just to detect non ISO timestamps, no matter if jq_toTimestamp would parse it or not.
      echo "(sub(\"\\\\.[0-9]+\"; \"\") | try fromdate // null | . == null)"
    }
    # }}}

    # jq_period() <check if current time is within start and end time>{{{
    jq_period() {
      local start="$1"
      local end="$2"
      echo ". |
          (. | $(jq_toTimestamp)) as \$current
          | (${start} | $(jq_toTimestamp)) as \$start
          | (${end} | $(jq_toTimestamp)) as \$end
          | (\$current >= \$start and \$current <= \$end)
      "
    }
    # }}}

    # jq_help() <show help for jq filter functions>{{{
    jq_help() {
        local func="${1:-}"
        case "$func" in
            "")
                cat << 'EOF'
Available jq filter functions (source jq_filters.sh to use them):

  jq_toTimestamp            Convert any timestamp to epoch seconds
  jq_fromTimestamp          Convert any timestamp to ISO 8601 in local timezone
  jq_period <start> <end>   Check if a timestamp falls within a time period
  jq_invalidtimeformat      Detect timestamps not in ISO 8601 format

Run 'jq_help <function>' for detailed help and usage examples.
EOF
                ;;
            jq_toTimestamp)
                cat << 'EOF'
jq_toTimestamp — Convert any timestamp to epoch seconds

SYNOPSIS
  echo '"<timestamp>"' | jq "$(jq_toTimestamp)"

DESCRIPTION
  Converts a timestamp in any supported format to epoch seconds (UTC).

SUPPORTED FORMATS
  • ISO 8601 with offset:  "2025-09-24T13:17:06.438+0200"
  • ISO 8601 UTC (Z):      "2025-09-24T13:17:06.438Z"
  • ISO 8601 no timezone:  "2025-09-24T13:17:06.438"  (assumes local TZ)
  • Custom format:         "24/9/2025, 0:00:12"  (see NON_ISO_TIMESTAMP)
  • Epoch milliseconds:    "1759762093142" or 1759762093142
  • Epoch seconds:         "1759762093" or 1759762093

EXAMPLES
  echo '"2025-09-24T13:17:06.438+0200"' | jq "$(jq_toTimestamp)"
  # Output: 1758796626

  echo '{"time": "2025-09-24T13:17:06Z"}' | jq ".time |= $(jq_toTimestamp)"
  # Output: {"time": 1758796626}
EOF
                ;;
            jq_fromTimestamp)
                cat << 'EOF'
jq_fromTimestamp — Convert any timestamp to ISO 8601 in local timezone

SYNOPSIS
  echo '"<timestamp>"' | jq "$(jq_fromTimestamp)"

DESCRIPTION
  Converts any supported timestamp to an ISO 8601 string in the local
  timezone (as set by the TZ variable or the system timezone).

INPUT
  Any format supported by jq_toTimestamp.

OUTPUT
  ISO 8601 string with local timezone offset (e.g. "2025-09-24T13:17:06+0200").

EXAMPLES
  echo '"2025-09-24T13:17:06Z"' | jq "$(jq_fromTimestamp)"
  # Output: "2025-09-24T15:17:06+0200"  (assuming TZ=+0200)

  echo '{"time": "2025-09-24T13:17:06Z"}' | jq ".time |= $(jq_fromTimestamp)"
  # Output: {"time": "2025-09-24T15:17:06+0200"}

  echo '1758796626' | jq "$(jq_fromTimestamp)"
  # Output: "2025-09-24T13:17:06+0200"  (epoch seconds → local ISO 8601)

  cat app.log | jq ".time |= $(jq_fromTimestamp)"
  # Normalize every .time field in a log stream to local ISO 8601
EOF
                ;;
            jq_period)
                cat << 'EOF'
jq_period <start> <end> — Check if a timestamp falls within a period

SYNOPSIS
  echo '"<timestamp>"' | jq "$(jq_period \"<start>\" \"<end>\")"

DESCRIPTION
  Returns true if the input timestamp is within [start, end] (inclusive).
  All timestamp arguments accept any format supported by jq_toTimestamp.

ARGUMENTS
  start   Start of the period
  end     End of the period

OUTPUT
  true or false

EXAMPLES
  echo '"2025-09-24T13:17:06Z"' | \
      jq "$(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\")"
  # Output: true

  cat app.log | jq "
    select(.time | $(jq_period \"2025-09-24T00:00:00Z\" \"2025-10-07T23:59:59Z\"))
    | .time |= $(jq_fromTimestamp)
  "
EOF
                ;;
            jq_invalidtimeformat)
                cat << 'EOF'
jq_invalidtimeformat — Detect non-ISO 8601 timestamps

SYNOPSIS
  echo '"<timestamp>"' | jq "$(jq_invalidtimeformat)"

DESCRIPTION
  Returns true if the input string is NOT a valid ISO 8601 timestamp.
  Useful to filter or flag log entries with non-standard timestamp formats.

OUTPUT
  true  — timestamp is NOT in ISO 8601 format
  false — timestamp IS in ISO 8601 format

EXAMPLES
  echo '"2025-09-24T13:17:06Z"' | jq "$(jq_invalidtimeformat)"
  # Output: false  (valid ISO 8601)

  echo '"24/9/2025, 0:00:12"' | jq "$(jq_invalidtimeformat)"
  # Output: true   (custom format, not ISO 8601)

  cat app.log | jq "select(.time | $(jq_invalidtimeformat) | not) | .time |= $(jq_fromTimestamp)"
  # Converts only entries with ISO 8601 timestamps
EOF
                ;;
            jq_help)
                cat << 'EOF'
jq_help [function] — Show help for jq filter functions

SYNOPSIS
  jq_help               List all available filter functions
  jq_help <function>    Detailed help for a specific function

AVAILABLE FUNCTIONS
  jq_toTimestamp, jq_fromTimestamp, jq_period, jq_invalidtimeformat, jq_help
EOF
                ;;
            *)
                echo "jq_help: unknown function '${func}'." >&2
                echo "Run 'jq_help' with no arguments to list available functions." >&2
                return 1
                ;;
        esac
    }
    # }}}

    # Print a hint when sourced into an interactive shell
    if [[ $- == *i* ]]; then
        echo "ℹ️  jq_filters.sh loaded. Run 'jq_help' to see available filter functions."
    fi

}

main "$@"

unset -f main


