#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
shopt -s nullglob

btrfs_path='/var/mocker'
cgroups='cpu,cpuacct,memory'

# Parse command-line options.
while [[ $# -gt 0 && "${1:0:2}" == '--' ]]; do
    OPTION="${1:2}"

    if [[ "$OPTION" =~ ^([^=]+)=(.*)$ ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        declare "mocker_${name}=${value}"
    else
        declare "mocker_${OPTION}=x"
    fi

    shift
done


function mocker_check() {
    if btrfs subvolume list "$btrfs_path" | rg -qw -- "$1"; then
        echo 0
    else
        echo 1
    fi
}


function mocker_init() {
    local uuid
    uuid="img_$(shuf -i 42002-42254 -n 1)"

    if [[ -d "$1" ]]; then

        if [[ "$(mocker_check "$uuid")" == 0 ]]; then
            mocker_run "$@"
            return
        fi

        btrfs subvolume create "$btrfs_path/$uuid" > /dev/null

        cp -rf --reflink=auto "$1"/* "$btrfs_path/$uuid/" \
            > /dev/null

        if [[ ! -f "$btrfs_path/$uuid/img.source" ]]; then
            echo "$1" > "$btrfs_path/$uuid/img.source"
        fi

        echo "Created: $uuid"

    else
        echo "No directory named '$1' exists"
        return 1
    fi
}


function mocker_pull() {
    # HELP Pull an image from Docker Hub:
    # mocker pull <name> <tag>

    local token registry id ancestry tmp_uuid
    local -a layers

    token="$(
        curl -fsSL -o /dev/null -D- \
            -H 'X-Docker-Token: true' \
            "https://index.docker.io/v1/repositories/$1/images" |
        tr -d '\r' |
        awk -F ': *' '$1 == "X-Docker-Token" { print $2 }'
    )"

    registry='https://registry-1.docker.io/v1'

    id="$(
        curl -fsSL \
            -H "Authorization: Token $token" \
            "$registry/repositories/$1/tags/$2" |
        tr -d '"'
    )"

    if [[ "${#id}" -ne 64 ]]; then
        echo "No image named '$1:$2' exists" >&2
        return 1
    fi

    ancestry="$(
        curl -fsSL \
            -H "Authorization: Token $token" \
            "$registry/images/$id/ancestry"
    )"

    # Convert the ancestry JSON array into a Bash array.
    IFS=',' read -r -a layers <<< "$(
        printf '%s' "$ancestry" |
        tr -d '[] "' 
    )"

    tmp_uuid="$(uuidgen)"
    mkdir -p "/tmp/$tmp_uuid"

    for id in "${layers[@]}"; do
        curl -fSL \
            -H "Authorization: Token $token" \
            "$registry/images/$id/layer" \
            -o "/tmp/$tmp_uuid/layer.tar"

        tar xf "/tmp/$tmp_uuid/layer.tar" -C "/tmp/$tmp_uuid"
        rm -f "/tmp/$tmp_uuid/layer.tar"
    done

    echo "$1:$2" > "/tmp/$tmp_uuid/img.source"

    mocker_init "/tmp/$tmp_uuid"

    rm -rf "/tmp/$tmp_uuid"
}
