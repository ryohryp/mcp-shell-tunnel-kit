#!/bin/sh
# Example stdio target for the Tunnel. Use an absolute script path in the profile.
set -eu
: "${MCP_SHELL_BIN:=/opt/mcp-shell/bin/mcp-shell}"
: "${MCP_SHELL_SEC_CONFIG_FILE:=/opt/mcp-shell/security.yaml}"
export MCP_SHELL_SEC_CONFIG_FILE
# Do not set MCP_SHELL_ALLOW_UNSAFE=1. Refuse an inherited unsafe setting.
unset MCP_SHELL_ALLOW_UNSAFE
exec "$MCP_SHELL_BIN"
