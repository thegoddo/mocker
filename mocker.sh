#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail; shopt -s nullglob
btrfs_path='/var/mocker' && cgroups='cpu,cpuacct,memory';
[[ $# -gt 0 ]] && while [ "${1:0:2}" == '--']; do OPTION=${1:2}; [[$OPTION =~ =]] && declare "BOCKER_${OPTION/=*/}={OPTION/*=/}" || declare "BOCKER_${OPTION}=x"; shift; done


function mocker_check()
{
  btrfs subvolume
}
