#!/usr/bin/env bash
#
# collect-macpro61-baseline.sh - read-only MacPro6,1 state collector
#
# This harness establishes a reproducible description of the host before a
# kernel or system configuration change.  It is STATE ONLY, NOT A
# PERFORMANCE RESULT: it does not run workload benchmarks, install packages,
# change sysctls, change module parameters, alter networking, start/stop
# services, drop caches, or create files outside the selected output directory.
#
# Usage:
#   ./collect-macpro61-baseline.sh [OUTPUT-DIRECTORY]
#
# With no argument, results are written below this script's benchmarks/results
# directory.  An argument may be an existing directory or a new directory.
# All command output, including failures and unavailable optional commands, is
# kept in that directory.  The collector intentionally skips glxinfo,
# vulkaninfo, sysbench, and ethtool even when they are installed.

set -u

usage() {
    printf 'Usage: %s [OUTPUT-DIRECTORY]\n' "${0##*/}"
}

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 2
fi

if [[ $# -eq 1 && ( "$1" == '-h' || "$1" == '--help' ) ]]; then
    usage
    exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P) || {
    printf 'Unable to determine the script directory.\n' >&2
    exit 1
}

if [[ $# -eq 1 ]]; then
    OUTPUT_DIR=$1
else
    timestamp=$(date '+%Y%m%d-%H%M%S') || {
        printf 'Unable to create a timestamp for the default output directory.\n' >&2
        exit 1
    }
    OUTPUT_DIR="$SCRIPT_DIR/results/macpro61-state-$timestamp"
fi

if ! mkdir -p -- "$OUTPUT_DIR"; then
    printf 'Unable to create output directory: %s\n' "$OUTPUT_DIR" >&2
    exit 1
fi
OUTPUT_DIR=$(CDPATH= cd -- "$OUTPUT_DIR" 2>/dev/null && pwd -P) || {
    printf 'Unable to resolve output directory: %s\n' "$OUTPUT_DIR" >&2
    exit 1
}

# Every writer below is given an output filename.  Keeping the write helpers
# here makes it difficult to accidentally turn a diagnostic command into a
# write elsewhere on the host.
start_file() {
    local file=$1 title=$2
    {
        printf '%s\n' '============================================================'
        printf '%s\n' "$title"
        printf '%s\n' '============================================================'
    } > "$OUTPUT_DIR/$file"
}

append_command() {
    local file=$1 label=$2
    shift 2
    local rc
    {
        printf '\n--- %s ---\n' "$label"
        printf 'Command:'
        printf ' %q' "$@"
        printf '\n'
        if "$@"; then
            rc=0
        else
            rc=$?
        fi
        printf '\n[exit status: %s]\n' "$rc"
    } >> "$OUTPUT_DIR/$file" 2>&1
}

append_file() {
    local file=$1 label=$2 source=$3
    {
        printf '\n--- %s (%s) ---\n' "$label" "$source"
        if [[ -r "$source" ]]; then
            cat -- "$source"
        else
            printf '[unavailable: not readable]\n'
        fi
    } >> "$OUTPUT_DIR/$file" 2>&1
}

write_unavailable() {
    local file=$1 label=$2 reason=$3
    {
        printf '%s\n' '============================================================'
        printf '%s\n' "$label"
        printf '%s\n' '============================================================'
        printf '\n[unavailable: %s]\n' "$reason"
    } > "$OUTPUT_DIR/$file"
}

# A command can be installed but deliberately not invoked.  This gives the
# reader both the availability result and an unambiguous skip record.
skip_optional() {
    local command_name=$1 file=$2
    local resolved='not found'
    resolved=$(command -v "$command_name" 2>/dev/null) || resolved='not found'
    {
        printf '%s\n' '============================================================'
        printf 'Optional command: %s\n' "$command_name"
        printf '%s\n' '============================================================'
        printf 'Availability: %s\n' "$resolved"
        printf 'Status: SKIPPED by design. This harness collects state only; it does not invoke this optional command.\n'
    } > "$OUTPUT_DIR/$file"
}

generated_at=$(date --iso-8601=seconds 2>/dev/null || date)

cat > "$OUTPUT_DIR/README.txt" <<EOF
MacPro6,1 baseline state collection
===================================

IMPORTANT: This directory establishes host state only. It is NOT a
performance result and must not be interpreted as a benchmark.

Collected at: $generated_at
Output directory: $OUTPUT_DIR
Collector: ${BASH_SOURCE[0]}

The harness is read-only with respect to host runtime configuration. It does
not install packages, run workload benchmarks, change sysctls or module
parameters, modify network state, manage services, drop caches, or write
outside this directory. Some command output may be unavailable without
appropriate permissions; that is recorded rather than treated as a change.

Files are grouped by subject. command-availability.txt records commands used
or considered. glxinfo, vulkaninfo, sysbench, and ethtool are always reported
there and in optional-*.txt as SKIPPED, whether or not they are installed.
EOF

start_file command-availability.txt 'Command availability (no package installation)'
{
    printf '\nGenerated: %s\n' "$generated_at"
    printf 'Format: STATUS<TAB>COMMAND<TAB>RESOLUTION\n\n'
} >> "$OUTPUT_DIR/command-availability.txt"

commands=(
    bash cat date df findmnt free hostname hostnamectl ip lsblk lsmod lscpu
    lspci mkdir modinfo pgrep ps readlink sensors swapon sysctl systemctl
    systemd-analyze tc uname vmstat zramctl
    glxinfo vulkaninfo sysbench ethtool
)
for command_name in "${commands[@]}"; do
    if resolved=$(command -v "$command_name" 2>/dev/null); then
        printf 'AVAILABLE\t%s\t%s\n' "$command_name" "$resolved" >> "$OUTPUT_DIR/command-availability.txt"
    else
        printf 'MISSING\t%s\t-\n' "$command_name" >> "$OUTPUT_DIR/command-availability.txt"
    fi
done

start_file host-identity.txt 'Host and kernel identity'
append_command host-identity.txt 'uname -a' uname -a
append_command host-identity.txt 'uname -mrs' uname -mrs
append_command host-identity.txt 'hostname' hostname
append_command host-identity.txt 'hostnamectl (if available)' hostnamectl
append_file host-identity.txt '/etc/os-release' /etc/os-release
append_file host-identity.txt '/etc/hostname' /etc/hostname
append_file host-identity.txt '/etc/machine-id' /etc/machine-id
append_file host-identity.txt '/proc/version' /proc/version
append_file host-identity.txt '/proc/sys/kernel/osrelease' /proc/sys/kernel/osrelease
append_file host-identity.txt '/proc/sys/kernel/hostname' /proc/sys/kernel/hostname

start_file cpu-memory.txt 'CPU and RAM state'
append_command cpu-memory.txt 'lscpu' lscpu
append_command cpu-memory.txt 'free -h' free -h
append_file cpu-memory.txt '/proc/meminfo' /proc/meminfo
append_file cpu-memory.txt '/proc/loadavg' /proc/loadavg

start_file storage-mounts.txt 'Storage, filesystems, and mounts'
append_command storage-mounts.txt 'lsblk -e 7 -o NAME,PATH,MODEL,SERIAL,SIZE,RO,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS' \
    lsblk -e 7 -o NAME,PATH,MODEL,SERIAL,SIZE,RO,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS
append_command storage-mounts.txt 'findmnt -A' findmnt -A
append_command storage-mounts.txt 'df -hT' df -hT
append_file storage-mounts.txt '/proc/mounts' /proc/mounts
append_file storage-mounts.txt '/proc/filesystems' /proc/filesystems

start_file kernel-cmdline.txt 'Kernel command line and boot parameters'
append_file kernel-cmdline.txt '/proc/cmdline' /proc/cmdline
append_file kernel-cmdline.txt '/proc/bootconfig' /proc/bootconfig
append_file kernel-cmdline.txt '/sys/kernel/security/lsm' /sys/kernel/security/lsm

start_file sysctls.txt 'Selected sysctls and congestion-control availability (read-only)'
{
    printf '\nThese are reads only. The first group mirrors every value proposed by the MacPro6,1 sysctl profile; dirty bytes and ratios are both recorded.\n'
} >> "$OUTPUT_DIR/sysctls.txt"

sysctl_keys=(
    vm.swappiness
    vm.vfs_cache_pressure
    vm.dirty_ratio
    vm.dirty_background_ratio
    vm.dirty_bytes
    vm.dirty_background_bytes
    net.core.rmem_max
    net.core.wmem_max
    net.ipv4.tcp_fastopen
    net.core.netdev_max_backlog
    net.ipv4.tcp_congestion_control
    kernel.printk
    kvm.ignore_msrs
    net.core.default_qdisc
    net.ipv4.tcp_available_congestion_control
    net.ipv4.tcp_allowed_congestion_control
)
for key in "${sysctl_keys[@]}"; do
    if value=$(sysctl -n "$key" 2>&1); then
        printf '%s = %s\n' "$key" "$value" >> "$OUTPUT_DIR/sysctls.txt"
    else
        printf '%s = [unavailable]\n%s\n' "$key" "$value" >> "$OUTPUT_DIR/sysctls.txt"
    fi
done

{
    printf '\n--- kvm module parameter (the profile proposes kvm.ignore_msrs = 1) ---\n'
    if [[ -r /sys/module/kvm/parameters/ignore_msrs ]]; then
        printf 'kvm.ignore_msrs = '
        cat /sys/module/kvm/parameters/ignore_msrs
    else
        printf 'kvm.ignore_msrs = [unavailable: /sys/module/kvm/parameters/ignore_msrs]\n'
    fi
    printf '\n--- tcp_bbr module presence and parameters ---\n'
    if [[ -d /sys/module/tcp_bbr ]]; then
        printf 'tcp_bbr module: present\n'
        for parameter in /sys/module/tcp_bbr/parameters/*; do
            [[ -e "$parameter" ]] || continue
            printf '%s = ' "${parameter##*/}"
            cat -- "$parameter"
        done
    else
        printf 'tcp_bbr module: not present\n'
    fi
} >> "$OUTPUT_DIR/sysctls.txt" 2>&1
if command -v modinfo >/dev/null 2>&1; then
    append_command sysctls.txt 'modinfo tcp_bbr (read-only)' modinfo tcp_bbr
else
    printf '\n--- modinfo tcp_bbr ---\n[skipped: modinfo is unavailable]\n' >> "$OUTPUT_DIR/sysctls.txt"
fi

start_file zram-swap.txt 'zram and swap state'
append_command zram-swap.txt 'swapon --show --bytes' swapon --show --bytes
append_file zram-swap.txt '/proc/swaps' /proc/swaps
if command -v zramctl >/dev/null 2>&1; then
    append_command zram-swap.txt 'zramctl --output all' zramctl --output all
else
    printf '\n--- zramctl ---\n[skipped: zramctl is unavailable]\n' >> "$OUTPUT_DIR/zram-swap.txt"
fi
{
    printf '\n--- zram sysfs attributes ---\n'
    found_zram=0
    for zram in /sys/block/zram*; do
        [[ -d "$zram" ]] || continue
        found_zram=1
        printf '\n[%s]\n' "${zram##*/}"
        for attribute in disksize mem_limit orig_data_size compr_data_size mem_used_total \
                         num_reads num_writes zero_pages mm_stat backing_dev; do
            if [[ -r "$zram/$attribute" ]]; then
                printf '%s = ' "$attribute"
                cat -- "$zram/$attribute"
            fi
        done
    done
    [[ $found_zram -eq 1 ]] || printf '[no zram devices found]\n'
} >> "$OUTPUT_DIR/zram-swap.txt" 2>&1

start_file psi.txt 'Memory and I/O pressure stall information'
append_file psi.txt '/proc/pressure/memory' /proc/pressure/memory
append_file psi.txt '/proc/pressure/io' /proc/pressure/io
append_file psi.txt '/proc/pressure/cpu (additional context)' /proc/pressure/cpu

start_file vmstat.txt 'Virtual-memory and VM statistics (read-only snapshots)'
append_command vmstat.txt 'vmstat -s' vmstat -s
append_command vmstat.txt 'vmstat -d' vmstat -d
append_file vmstat.txt '/proc/vmstat' /proc/vmstat

start_file boot-timing.txt 'Boot timing and uptime'
append_file boot-timing.txt '/proc/uptime' /proc/uptime
append_file boot-timing.txt '/proc/stat (btime)' /proc/stat
if command -v systemd-analyze >/dev/null 2>&1; then
    append_command boot-timing.txt 'systemd-analyze time' systemd-analyze time
    append_command boot-timing.txt 'systemd-analyze blame --no-pager' systemd-analyze blame --no-pager
    append_command boot-timing.txt 'systemd-analyze critical-chain --no-pager' systemd-analyze critical-chain --no-pager
else
    printf '\n[systemd-analyze unavailable: boot unit timing skipped]\n' >> "$OUTPUT_DIR/boot-timing.txt"
fi

start_file modules.txt 'Loaded kernel modules'
append_command modules.txt 'lsmod' lsmod
append_file modules.txt '/proc/modules' /proc/modules

start_file gpu-drivers.txt 'GPU inventory and kernel drivers'
append_command gpu-drivers.txt 'lspci -nnk (GPU and driver information is included)' lspci -nnk
{
    printf '\n--- DRM devices and driver symlinks ---\n'
    found_drm=0
    for card in /sys/class/drm/card[0-9]*; do
        [[ -e "$card" ]] || continue
        found_drm=1
        printf '\n[%s]\n' "${card##*/}"
        if command -v readlink >/dev/null 2>&1; then
            printf 'device = '
            readlink -f "$card/device" 2>/dev/null || true
            printf 'driver = '
            readlink -f "$card/device/driver" 2>/dev/null || true
        fi
        for attribute in vendor device subsystem_vendor subsystem_device; do
            if [[ -r "$card/device/$attribute" ]]; then
                printf '%s = ' "$attribute"
                cat -- "$card/device/$attribute"
            fi
        done
    done
    [[ $found_drm -eq 1 ]] || printf '[no DRM card devices found]\n'
} >> "$OUTPUT_DIR/gpu-drivers.txt" 2>&1
skip_optional glxinfo optional-glxinfo.txt
skip_optional vulkaninfo optional-vulkaninfo.txt

start_file network.txt 'Network interfaces, link state, routes, and qdiscs'
append_command network.txt 'ip -details link show' ip -details link show
append_command network.txt 'ip -details address show' ip -details address show
append_command network.txt 'ip route show table all' ip route show table all
if command -v tc >/dev/null 2>&1; then
    append_command network.txt 'tc -s qdisc show' tc -s qdisc show
else
    printf '\n[tc unavailable: qdisc enumeration skipped]\n' >> "$OUTPUT_DIR/network.txt"
fi
{
    printf '\n--- per-interface sysfs link state ---\n'
    found_interface=0
    for interface in /sys/class/net/*; do
        [[ -e "$interface" ]] || continue
        found_interface=1
        name=${interface##*/}
        printf '\n[%s]\n' "$name"
        for attribute in address operstate carrier speed mtu tx_queue_len; do
            if [[ -r "$interface/$attribute" ]]; then
                printf '%s = ' "$attribute"
                cat -- "$interface/$attribute"
            fi
        done
    done
    [[ $found_interface -eq 1 ]] || printf '[no interfaces found]\n'
} >> "$OUTPUT_DIR/network.txt" 2>&1
skip_optional ethtool optional-ethtool.txt

if command -v sensors >/dev/null 2>&1; then
    start_file sensors.txt 'Hardware sensors (if exposed by the host)'
    append_command sensors.txt 'sensors' sensors
else
    write_unavailable sensors.txt 'Hardware sensors (if exposed by the host)' 'sensors command is unavailable'
fi

start_file macfanctld.txt 'macfanctld service status (read-only)'
if command -v systemctl >/dev/null 2>&1; then
    append_command macfanctld.txt 'systemctl status macfanctld --no-pager --full' systemctl status macfanctld --no-pager --full
    append_command macfanctld.txt 'systemctl is-enabled macfanctld' systemctl is-enabled macfanctld
    append_command macfanctld.txt 'systemctl is-active macfanctld' systemctl is-active macfanctld
else
    printf '\n[systemctl unavailable: service manager status skipped]\n' >> "$OUTPUT_DIR/macfanctld.txt"
fi
if command -v pgrep >/dev/null 2>&1; then
    append_command macfanctld.txt 'pgrep -a macfanctld' pgrep -a macfanctld
else
    printf '\n[pgrep unavailable: process check skipped]\n' >> "$OUTPUT_DIR/macfanctld.txt"
fi

skip_optional sysbench optional-sysbench.txt

printf 'MacPro6,1 state collection complete. Output: %s\n' "$OUTPUT_DIR"
