# jq filters for JSON logs
#
# USAGE:
#   1. Import filters:
#      `source ~/bin/jq_filters.sh`
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

    # Text timestamps format (other than ISO 8661):
    NON_ISO_TIMESTAMP="%d/%m/%Y, %H:%M:%S"

    # Time zone for NON_ISO_TIMESTAMP:
    # (comment out to use different than current one).
    #TZ=+1000


    ### Default values:
    ### ---------------

    if [[ -z "$TZ" ]]; then
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
            ) catch ( # If catpured it should be "Z" or empty (no tz info)
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

}

main "$@"

unset -f main


