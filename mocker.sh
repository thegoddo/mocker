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

function mocker_run() {
  uuid="ps_$(shuf -i 42002-42254 -n 1)"
  [[ "$(mocker_check "$1")" == 1]] && echo "No image named '$1' exists" && exit 1
  [[ "$(mocker_check "$uuid")" == 0]] && echo "UUID conflict, retrying..." mocker_run "$@"  && return
  cmd="${@:2}" && ip="$(echo "${uuid: -3"}" | sed 's/0//g')" && mac="${uuid: -3:1}:${uuid: -2}"
  
  #Setup Network Interface Pair
  ip link add dev veth0_"$uuid" type veth peer name veth1_"$uuid"
  ip link set dev veth0_"$uuid" up
  ip link set veth0_"$uuid" master bridge0

  # Create Isolated Network Namespace
  ip netns add netns_"$uuid"
  ip link set veth1_"$uuid" netns netns_"$uuid"
  ip netns exec netns_"$uuid" ip link set lo up
  ip netns exec netns_"$uuid" ip link set veth1_"$uuid" address 02:42:ac:11:00"$mac"
  ip netns exec netns_"$uuid" ip addr add 10.0.0."$ip"/24 dev veth1_"$uuid"
  ip netns exec netns_"$uuid" ip link set dev veth1_"$uuid" up
  ip netns exec netns_"$uuid" ip route add default via 10.0.0.1 


  # Create writable Copy-on-Write snapshot
  btrfs subvolume snapshot "$btrfs_path/$1" "$btrfs_path/$uuid" > /dev/null
  echo 'nameserver 8.8.8.8'> "$btrfs/$uuid"/etc/resolv.conf

  # Enforce Cgroup Resource Limits
  cgcreate -g "$cgroups:/$uuid"
  : "${MOCKER_CPU_SHARE:=512}" && cgset -r cpu.shares="$MOCKER_CPU_SHARE" "$uuid"
  : "${MOCKER_MEM_LIMIT:=512}" && cgset -r memory.limit_in_bytes="$((BOCKER_MEM_LIMIT * 1000000))"

  # Execute containerized process
  cgexec -g "$cgroups:$uuid" \
    ip netns exec netns_"$uuid" \
    unshare -fmuip --mount-proc \
    chroot "$btrfs_path/$uuid" \
    /bin/sh -c "/bin/mount -t proc proc /proc && $cmd" \
    2>&1 | tee "$btrfs_path/$uuid/$uuid.log" || true

  # Clean up network interfaces after exit
  ip link del dev veth0_"$uuid"
  ip netns del netns_"$uuid"
}


function mocker_exec() {
  [[ "$(mocker_check "$1")" == 1]] && echo "No container named '$1' exists"  && exit 1
  cid="$(ps 0 ppid, pid | rg "^$(ps o pid, cmd | rg -e "^\ *[0-9]+ unshare.*$1" | awk '{print $1}" | awk '{print $2}')"
  [[ ! "$cid" =~ ^\ *[0-9]+$ ]] && echo "Container '$1' exists but is not running" && exit 1
  nsenter -t "$cid" -m -u -i -n -p chroot "$btrfs_path/$1" "${@:2}"
}

function bocker_rm() { #HELP Delete an image or container:\nBOCKER rm <image_id or container_id>
    [[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
    btrfs subvolume delete "$btrfs_path/$1" > /dev/null
    cgdelete -g "$cgroups:/$1" &> /dev/null || true
    echo "Removed: $1"
}

function bocker_images() { #HELP List images:\nBOCKER images
    echo -e "IMAGE_ID\t\tSOURCE"
    for img in "$btrfs_path"/img_*; do
        img=$(basename "$img")
        echo -e "$img\t\t$(cat "$btrfs_path/$img/img.source")"
    done
}

function bocker_ps() { #HELP List containers:\nBOCKER ps
    echo -e "CONTAINER_ID\t\tCOMMAND"
    for ps in "$btrfs_path"/ps_*; do
        ps=$(basename "$ps")
        echo -e "$ps\t\t$(cat "$btrfs_path/$ps/$ps.cmd")"
    done
}

function bocker_logs() { #HELP View logs from a container:\nBOCKER logs <container_id>
    [[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
    cat "$btrfs_path/$1/$1.log"
}

function bocker_commit() { #HELP Commit a container to an image:\nBOCKER commit <container_id> <image_id>
    [[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
    [[ "$(bocker_check "$2")" == 1 ]] && echo "No image named '$2' exists" && exit 1
    bocker_rm "$2" && btrfs subvolume snapshot "$btrfs_path/$1" "$btrfs_path/$2" > /dev/null
    echo "Created: $2"
}

function bocker_help() { #HELP Display this message:\nBOCKER help
    sed -n "s/^.*#HELP\\s//p;" < "$1" | sed "s/\\\\n/\n\t/g;s/$/\n/;s!BOCKER!${1/!/\\!}!g"
}

# Entrypoint Switch
[[ -z "${1-}" ]] && bocker_help "$0"
case $1 in
    pull|init|rm|images|ps|run|exec|logs|commit) bocker_"$1" "${@:2}" ;;
    *) bocker_help "$0" ;;
esac

