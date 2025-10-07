#!/usr/bin/env bash

HELP=false
if [ "$1" = "--help" ]; then
    HELP=true
    shift;
fi

REPORT="$1";

showHelp() {
    cat << EOF
${REPORT_DESC}

Usage: ${SYNTAX}
EOF
exit 0;
}


source "$(dirname "$0")/../src/jq_filters.sh"


case "$REPORT" in
    watchdog)
        REPORT_DESC="Watchdog alive reports"
        SYNTAX="$0 watchdog"
        SRC="
              select(
                  (.time | $(jq_period  \"2025-09-24T13:17:06.438+0200\" \"2025-09-24T15:17:06.438+0200\"))
                  and (.module == \"watchdog\")
              )
              | .time = (.time | $(jq_fromTimestamp))
              # | del (.node_report)
              | {
                  time,
                  message,
                  alive,
                  delta_time,
              }
        ";
        ;;

    longLatency)
        REPORT_DESC="Long latency HTTP requests (>10s)"
        SYNTAX="$0 longLatency [threshold_ms=10000]"
        SRC="
              select(
                  (.time | $(jq_period  \"2025-09-24T13:17:06.438+0200\" \"2025-09-24T15:17:06.438+0200\"))
                  and (.connection.type = \"httpserver\")
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
                  referer,
              }
        ";
        ;;

    "")

        ;;
    *)
        echo "Unknown report: $REPORT"
        echo "Use --help to see usage."
        exit 1
        ;;
esac

if $HELP; then showHelp; fi


echo $SRC;


