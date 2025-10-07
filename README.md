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
    - Make them sortable. 
    - Keep interoperability.

  * Filter logs by time range.

  * Easy to extend with custom filters.


## Overview

```
.
├── README.md            →  This file
├── src
│   └── jq_filters.sh    →  Advanced jq filters generators
├── doc
│   └── jq_filters.md    →  Usage documentation for jq_filters.sh
├── examples
│   └── reports.sh       →  Sample script to generate advanced reports
└── test
    └── filter_tests.sh  →  Unit tests for jq_filters.sh
```

## Requirements

  * bash
  * jq >= 1.7

## Usage

  1. Import filters:
     `source ./path/to/jq_filters.sh`

  2. Use filters:
     `cat some.log | jq "$(f1 args..) | $(f2 args...)"`


## Documentation

    * [jq filter generators](doc/jq_filters.md) for detailed usage instructions and examples.

## Testing

Run all scripts in the `tests` directory:

```bash
./tests/*
```
