#!/bin/sh
# Bounded, read-only self-diagnostic for mcp-shell. No caller-controlled arguments.
# Relies on mcp-shell's inherited MCP_SHELL_SEC_CONFIG_FILE, not an assumed path.
set -u
if [ "$#" -ne 0 ]; then
    printf '%s\n' 'diagnostic arguments are not accepted'
    exit 2
fi
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LC_ALL=C
export PATH LC_ALL

config=${MCP_SHELL_SEC_CONFIG_FILE-}

printf '%s\n' '=== MCP security configuration self-check ==='
case "$config" in
    /*)
        if [ -f "$config" ] && [ ! -L "$config" ] && [ -r "$config" ]; then
            printf '%s\n' 'inherited config path points to readable regular file: PASS'
            if [ -w "$config" ]; then
                printf '%s\n' 'config not writable by MCP process: FAIL'
            else
                printf '%s\n' 'config not writable by MCP process: PASS'
            fi
            # Inspect only known script names in the kit's example indentation.
            # This does NOT prove that mcp-shell parsed or loaded this file.
            declared=$(awk '
                /^security:[[:space:]]*$/ { security=1; next }
                security && /^[^[:space:]#]/ { security=0; scripts=0 }
                security && /^  scripts:[[:space:]]*$/ { scripts=1; next }
                scripts && /^  [^[:space:]#]/ { scripts=0 }
                scripts && /^    linux_posture:[[:space:]]*\[/ { found=1 }
                END { print found ? "YES" : "NO" }
            ' "$config" 2>/dev/null) || declared=UNVERIFIED
            case "$declared" in
                YES|NO) printf 'linux_posture declared in inherited config: %s\n' "$declared" ;;
                *) printf '%s\n' 'linux_posture declared in inherited config: UNVERIFIED' ;;
            esac
        else
            printf '%s\n' 'inherited config path points to readable regular file: FAIL'
            printf '%s\n' 'config not writable by MCP process: UNVERIFIED'
            printf '%s\n' 'linux_posture declared in inherited config: UNVERIFIED'
        fi
        ;;
    *)
        printf '%s\n' 'inherited config path points to readable regular file: UNVERIFIED'
        printf '%s\n' 'config not writable by MCP process: UNVERIFIED'
        printf '%s\n' 'linux_posture declared in inherited config: UNVERIFIED'
        ;;
esac
printf '%s\n' 'Effective loaded config, live tool registry, actual script executable and Tunnel profile: UNVERIFIED'
printf '%s\n' 'Confirm live registration with run_script(name=linux_posture) and inspect host-side deployment independently.'
