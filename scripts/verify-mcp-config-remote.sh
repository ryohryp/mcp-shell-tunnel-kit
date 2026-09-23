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

# Report only fixed reason codes. Never echo paths, YAML, credentials or environment values.
# An absent environment variable cannot prove which configuration the live process loaded.
report_unverified() {
    printf '%s\n' 'inherited config path points to readable regular file: UNVERIFIED'
    printf '%s\n' 'config not writable by MCP process: UNVERIFIED'
    printf '%s\n' 'linux_posture declared in inherited config: UNVERIFIED'
}
printf '%s\n' '=== MCP security configuration self-check ==='
if [ "${MCP_SHELL_SEC_CONFIG_FILE+x}" != x ]; then
    printf '%s\n' 'config inspection reason: CONFIG_ENV_UNSET'
    report_unverified
else
    config=$MCP_SHELL_SEC_CONFIG_FILE
    case "$config" in
        '') reason=CONFIG_ENV_EMPTY ;;
        /*)
            if [ -L "$config" ]; then
                reason=CONFIG_FILE_SYMLINK
            elif [ ! -e "$config" ]; then
                reason=CONFIG_FILE_MISSING
            elif [ ! -f "$config" ]; then
                reason=CONFIG_NOT_REGULAR
            elif [ ! -r "$config" ]; then
                reason=CONFIG_NOT_READABLE
            else
                reason=
            fi
            ;;
        *) reason=CONFIG_PATH_NOT_ABSOLUTE ;;
    esac
    if [ -n "$reason" ]; then
        printf 'config inspection reason: %s\n' "$reason"
        # An observed bad path or object is not the same as missing evidence
        # about the process environment. Keep the original three verdicts.
        case "$reason" in
            CONFIG_FILE_SYMLINK|CONFIG_FILE_MISSING|CONFIG_NOT_REGULAR|CONFIG_NOT_READABLE)
                printf '%s\n' 'inherited config path points to readable regular file: FAIL'
                printf '%s\n' 'config not writable by MCP process: UNVERIFIED'
                printf '%s\n' 'linux_posture declared in inherited config: UNVERIFIED'
                ;;
            *) report_unverified ;;
        esac
    else
        printf '%s\n' 'config inspection reason: CONFIG_FILE_ACCESSIBLE'
        printf '%s\n' 'inherited config path points to readable regular file: PASS'
        if [ -w "$config" ]; then
            printf '%s\n' 'config not writable by MCP process: FAIL'
        else
            printf '%s\n' 'config not writable by MCP process: PASS'
        fi
        # Narrow textual check for the documented example layout only.
        # This does not establish which config the live server parsed.
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
    fi
fi
printf '%s\n' 'Effective loaded config, live tool registry, actual script executable and Tunnel profile: UNVERIFIED'
printf '%s\n' 'Confirm live registration with run_script(name=linux_posture) and inspect host-side deployment independently.'
