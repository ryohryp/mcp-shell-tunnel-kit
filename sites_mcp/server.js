import { describePolicy, routeCapability } from "./policy.js";
import { loadTargets } from "./target-registry.js";

function defaultEnv() {
  return globalThis.process?.env ?? {};
}

export async function describe_control_plane() {
  return {
    status: "ok",
    policy: describePolicy(),
  };
}

export async function list_targets(_args = {}, env = defaultEnv()) {
  try {
    return {
      status: "ok",
      targets: loadTargets(env),
      metadata_only: true,
      live_status: false,
    };
  } catch (error) {
    return {
      status: "failed",
      error: "invalid_configuration",
      detail: String(error?.message ?? error),
    };
  }
}

export async function route_request({ capability, target_id = null } = {}, env = defaultEnv()) {
  const routed = routeCapability(capability);
  if (routed.status !== "ok") return routed;

  let target = null;
  if (target_id !== null) {
    if (typeof target_id !== "string" || !target_id.trim()) {
      return {
        status: "failed",
        error: "invalid_input",
        detail: "target_id must be a non-empty string when supplied",
      };
    }

    let targets;
    try {
      targets = loadTargets(env);
    } catch (error) {
      return {
        status: "failed",
        error: "invalid_configuration",
        detail: String(error?.message ?? error),
      };
    }

    target = targets.find((candidate) => candidate.id === target_id) ?? null;
    if (!target) {
      return {
        status: "failed",
        error: "unknown_target",
        detail: "target_id is not present in the declarative Sites registry",
      };
    }

    if (
      routed.route === "host_local_executor" &&
      !target.capabilities.includes(capability)
    ) {
      return {
        status: "failed",
        error: "capability_not_declared",
        detail: "the target metadata does not declare the requested host-local capability",
      };
    }
  }

  return {
    ...routed,
    target_id: target?.id ?? target_id,
    target_metadata_only: target ? true : null,
  };
}

export const tools = Object.freeze([
  {
    name: "describe_control_plane",
    title: "Describe MCP Shell Control Plane",
    description:
      "Return the Sites control-plane boundary and the capabilities that must remain on the host-local executor.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
    readOnlyHint: true,
    openWorldHint: false,
    handler: describe_control_plane,
  },
  {
    name: "list_targets",
    title: "List Declared MCP Shell Targets",
    description:
      "List non-secret declarative target metadata. This is not live status and contains no connection details.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
    readOnlyHint: true,
    openWorldHint: false,
    handler: list_targets,
  },
  {
    name: "route_request",
    title: "Route MCP Shell Capability",
    description:
      "Classify whether a requested capability belongs in Sites or must be handled by the host-local executor.",
    inputSchema: {
      type: "object",
      required: ["capability"],
      additionalProperties: false,
      properties: {
        capability: { type: "string" },
        target_id: { type: "string" },
      },
    },
    readOnlyHint: true,
    openWorldHint: false,
    handler: route_request,
  },
]);
