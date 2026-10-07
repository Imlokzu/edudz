#!/bin/sh
# The isolated SDK avoids the installed Dart launcher's macOS startup hang.
set -eu
sdk=/Users/hhh/.cache/edudz-flutter
exec "$sdk/bin/flutter" "$@"
