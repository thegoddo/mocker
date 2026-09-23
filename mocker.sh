#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail; shopt -s nullglob
btrfs_path='/var/mocker' && cgroups='cpu,cpuacct,memory';
[[ $# -gt 0 ]] && while [ "${1:0:2}" == '--']; do OPTION=${1:2}; [[$OPTION =~ =]] && declare "mocker_${OPTION/=*/}={OPTION/*=/}" || declare "mocker_${OPTION}=x"; shift; done


function mocker_check()
{
  btrfs subvolume list "$btrfs_path" | rg -qw "$1" && echo 0 || echo 1
}

function mocker_init() {
  uuid="img_$(shuf -i 42002-42254 -n 1)"
  if [[ -d "$1" ]]; then
    [[ "$(mocker_check "$uuid")" == 0]] && mocker_run "$@"
    btrfs subvolume create "$btrfs_path/$uuid" > /dev/null
    cp -rf --reflink=auto "$1"/* "$btrfs/$uuid" > /dev/null
    [[ ! -f "$btrfs_path/$uuid"/img.source]] && echo "$1" > "$btrfs_path/$uuid"/img.source
    echo "Created: $uuid"
  else
    echo "No directory named '$1' exists"
}

