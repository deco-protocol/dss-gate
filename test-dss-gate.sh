#!/usr/bin/env bash
set -e

for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)

    case "$KEY" in
            match)      MATCH="$VALUE" ;;
            *)
    esac
done

if [[ -z "$1" ]]; then
  dapp --use solc:0.8.11 test -v
else
  dapp --use solc:0.8.11 test --match "$MATCH" -vv
fi
