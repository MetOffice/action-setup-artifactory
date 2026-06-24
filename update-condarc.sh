#!/usr/bin/env bash

# Some notes on the version of `yq` installed on the GH Runner. The following
# commands/flag are not available in this build:
#  - `--arg`: used to pass in variables; inject environment variables directly into command string instead.
#  - `.index()` and `.any()`: used to check for existence of a value in an array; use `select()` instead.

set -euo pipefail
yq --version

for CONDARC_FILE in ${CONDARC_SOURCES}; do

    echo "[INFO] Processing file: ${CONDARC_FILE}"

    if [ ! -f "${CONDARC_FILE}" ]; then
        echo "INFO: ${CONDARC_FILE} does not exist, skipping..."
    	continue
    fi

    # Add the conda-forge channel:
    if yq eval -e '.channels[] | select(. == "conda-forge")' "${CONDARC_FILE}" >/dev/null 2>&1; then
        echo "INFO: conda-forge channel already present in ${CONDARC_FILE}"
    else
        echo "INFO: Adding conda-forge channel to ${CONDARC_FILE}"
        yq -i '.channels = ["conda-forge"] + .channels' "${CONDARC_FILE}"
    fi

    # remove any of the defaults channels from the config file:
    for DEFAULT in ${DEFAULT_CHANNELS}; do
        if yq eval -e '.channels[] | select(. == "'"${DEFAULT}"'")' "${CONDARC_FILE}" >/dev/null 2>&1; then
            echo "INFO: Removing default channel ${DEFAULT} from ${CONDARC_FILE}"
            yq -i ".channels |= map(select(. != \"$DEFAULT\"))" "${CONDARC_FILE}"
        fi
    done

    echo "===== UPDATED CONDARC ======"
    cat ${CONDARC_FILE}
    echo "============================"
    echo ""
done
