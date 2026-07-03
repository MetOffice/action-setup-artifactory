#!/usr/bin/env bash
set -euo pipefail

echo "##[group]Get condarc locations"
# Get condarc file sources, as reported by the tooling.
# We need to do this as:
#   1. Not all tools default to using ~/.condarc, e.g. the setup-micromamba action
#      uses a different location for its configuration file.
#   2. There may be several configuration files, e.g. a system-wide configuration file,
#      and a user configuration file.
# The best way to get the list of configuration files is to ask the tooling itself.
sources=""

# Check if conda is installed and get its config sources
if command -v conda >/dev/null 2>&1; then
    # The JSON output of Conda config includes some files that are not condarc files.
    # We filter these out:
    #  - `jq -r 'keys[]'` : gets the keys of the JSON object, which are the file paths
    #  - `grep -E '/\.?condarc$'` : filters to only include paths that end with .condarc or condarc
    sources="${sources} $(conda config --show-sources --json | jq -r 'keys[]' | grep -E '/\.?condarc$')"
    echo "Added Conda CONDARC: ${sources}"
fi

# Check if micromamba is installed and get its config sources
if [ -n "${MAMBA_EXE}" ]; then
    # Micromamba doesn't have a nice JSON output, so we just take the output of
    # the `config sources` command and skip the first line (which is a header):
    sources="${sources} $(${MAMBA_EXE} config sources | tail -n+2)"
fi

# Sanitize: replace `~` with `$HOME` and get rid of newlines:
#  - `sed "s|~|${HOME}|g"` : replaces ~ with the value of $HOME
#  - `tr '\n' ' '` : replaces newlines with spaces
#  - `sed "s| *$||g"` : removes trailing whitespace
sources=$(echo "${sources}" | sed "s|~|${HOME}|g" | tr '\n' ' ' | sed "s| *$||g")

# If no sources found, add a default source of ${HOME}/.condarc:
if [ -z "${sources}" ]; then
    echo "[INFO] Found no condarc source, adding default source of ${HOME}/.condarc"
    sources="${HOME}/.condarc"
    touch ${sources}
else
    # Otherwise, add user ${HOME}/.condarc if it exists and not already listed in sources:
    if (! echo "${sources}" | grep -q "${HOME}/.condarc") && (test -f ${HOME}/.condarc); then
    sources="${sources} ${HOME}/.condarc"
    echo "Added HOME/USER CONDARC: ${sources}"
    fi
fi

echo "The following condarc sources will be updated:"
echo "${sources}"
echo "##[endgroup]"


echo "##[group]Create netrc file"
# Create netrc file
echo "machine metoffice.jfrog.io" >> ~/.netrc
# If username is empty don't add login entry to .netrc (assumes Access Token):
if [[ -n "${USERNAME}" ]]; then
    echo "  login ${USERNAME}" >> ~/.netrc
fi
echo "  password ${API_KEY}" >> ~/.netrc
echo "##[endgroup]"

echo "##[group]Configure the condarc file"
# Configure the condarc file
# We do this by modifying the condarc files directly rather than using 
# `conda config` or `micromamba config` commands, as these commands don't always
# modify the correct condarc file when writing configuration files compared to 
# reading them. This is particularly true for the micromamba.
if ${SETUP_CONDA_FORGE}; then
    flags="--setup-conda-forge"
fi
for condarc_file in ${sources}; do
    echo "INFO: Updating ${condarc_file}"
    python3 "${ACTION_PATH}/update_condarc.py" "${condarc_file}" ${flags:-}
done
echo "##[endgroup]"

echo "##[group]Create pip configuration file"
# Create pip configuration file
mkdir -p ~/.config/pip
cat << EOF > ~/.config/pip/pip.conf
[global]
index-url = https://metoffice.jfrog.io/metoffice/api/pypi/pypi/simple
trusted-host = metoffice.jfrog.io
EOF
echo "##[endgroup]"

if [[ "${CHECK_CREDS}" = 'true' ]]; then
    echo "##[group]Check Artifactory authentication"
    # Check Artifactory authentication
    echo "Testing authentication to Artifactory"  

    url="https://metoffice.jfrog.io/metoffice/api/conda/conda-forge"
    # If connection and authentication work, then expect a successful response.
    if curl -n -I -sSf --silent --output /dev/null "${url}" ; then
        echo "Artifactory accessible, continuing"
    else
        # connection or authentication problems
        echo "Artifactory could not be accessed. Check authentication file, token expiry or user settings"
        exit 1
    fi
    echo "##[endgroup]"
fi
