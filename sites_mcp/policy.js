const ROUTES = Object.freeze({
  policy_info: "sites_control_plane",
  target_discovery: "sites_control_plane",
  browser_read: "browser_executor",
  filesystem_read: "host_local_executor",
  filesystem_write: "host_local_executor",
  git_read: "host_local_executor",
  git_write: "host_local_executor",
  command_run: "host_local_executor",
  live_status: "host_local_executor",
  service_control: "host_local_executor",
});

export const KNOWN_CAPABILITIES = Object.freeze(Object.keys(ROUTES));

export function routeCapability(capability) {
  if (typeof capability !== "string" || !Object.hasOwn(ROUTES, capability)) {
    return {
      status: "failed",
      error: "invalid_input",
      detail: "capability must be one of the documented control-plane capability IDs",
    };
  }

  const route = ROUTES[capability];
  return {
    status: "ok",
    capability,
    route,
    requires_host_local_executor: route === "host_local_executor",
    requires_browser_executor: route === "browser_executor",
  };
}

export function describePolicy() {
  return {
    version: "0.1.0",
    role: "sites_control_plane",
    execution_boundary: {
      sites: [
        "policy_info",
        "target_discovery",
      ],
      browser_executor: ["browser_read"],
      host_local_executor: [
        "filesystem_read",
        "filesystem_write",
        "git_read",
        "git_write",
        "command_run",
        "live_status",
        "service_control",
      ],
    },
    target_registry: {
      declarative_only: true,
      live_status: false,
      allowed_fields: [
        "id",
        "label",
        "platform",
        "executor",
        "capabilities",
        "tags",
      ],
      forbidden_examples: [
        "hostname",
        "url",
        "ip",
        "token",
        "credential",
        "tunnel_id",
        "private_key",
      ],
    },
    invariants: [
      "Sites does not execute shell commands.",
      "Sites does not read or write target filesystems.",
      "Sites does not perform Git operations against target workspaces.",
      "Sites does not store target connection details or credentials.",
      "Sites routes browser_read to a distinct browser executor and does not proxy browser actions.",
      "Execution remains on the host-local mcp-shell executor reached through the Secure MCP Tunnel.",
    ],
  };
}
