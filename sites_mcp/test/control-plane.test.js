import assert from "node:assert/strict";
import test from "node:test";

import {
  describe_control_plane,
  list_targets,
  route_request,
} from "../server.js";
import { routeCapability } from "../policy.js";
import { loadTargets, validateTarget } from "../target-registry.js";

const EXECUTION_CAPABILITIES = [
  "filesystem_read",
  "filesystem_write",
  "git_read",
  "git_write",
  "command_run",
  "live_status",
  "service_control",
];

test("execution-related capabilities always stay on the host-local executor", () => {
  for (const capability of EXECUTION_CAPABILITIES) {
    assert.deepEqual(routeCapability(capability), {
      status: "ok",
      capability,
      route: "host_local_executor",
      requires_host_local_executor: true,
      requires_browser_executor: false,
    });
  }
});

test("Sites-only capabilities remain read-only control-plane operations", () => {
  for (const capability of ["policy_info", "target_discovery"]) {
    const routed = routeCapability(capability);
    assert.equal(routed.status, "ok");
    assert.equal(routed.route, "sites_control_plane");
    assert.equal(routed.requires_host_local_executor, false);
    assert.equal(routed.requires_browser_executor, false);
  }
});

test("browser reads route to the distinct browser executor without executing in Sites", () => {
  assert.deepEqual(routeCapability("browser_read"), {
    status: "ok",
    capability: "browser_read",
    route: "browser_executor",
    requires_host_local_executor: false,
    requires_browser_executor: true,
  });
});

test("safe declarative target metadata is accepted", () => {
  const target = validateTarget({
    id: "example-linux",
    label: "Example Linux target",
    platform: "linux",
    executor: "host_local_executor",
    capabilities: ["filesystem_read", "git_read", "command_run"],
    tags: ["example", "non-secret"],
  });

  assert.equal(target.id, "example-linux");
  assert.equal(target.executor, "host_local_executor");
  assert.deepEqual(target.capabilities, [
    "filesystem_read",
    "git_read",
    "command_run",
  ]);
});

test("connection details and credentials cannot be represented in target metadata", () => {
  for (const forbidden of [
    ["hostname", "vm.internal"],
    ["url", "https://example.invalid"],
    ["ip", "10.0.0.1"],
    ["token", "secret"],
    ["tunnel_id", "tunnel-123"],
    ["private_key", "secret"],
  ]) {
    const [field, value] = forbidden;
    assert.throws(
      () =>
        validateTarget({
          id: "example-linux",
          label: "Example Linux target",
          platform: "linux",
          executor: "host_local_executor",
          capabilities: ["filesystem_read"],
          [field]: value,
        }),
      /unsupported fields/
    );
  }
});

test("list_targets returns metadata only and ignores unrelated environment secrets", async () => {
  const env = {
    MCP_SHELL_TARGETS_JSON: JSON.stringify([
      {
        id: "example-linux",
        label: "Example Linux target",
        platform: "linux",
        executor: "host_local_executor",
        capabilities: ["filesystem_read"],
        tags: ["example"],
      },
    ]),
    UNRELATED_SECRET: "must-not-leak",
  };

  const result = await list_targets({}, env);
  assert.equal(result.status, "ok");
  assert.equal(result.metadata_only, true);
  assert.equal(result.live_status, false);
  assert.equal(result.targets.length, 1);
  assert.doesNotMatch(JSON.stringify(result), /must-not-leak/);
});

test("invalid registry configuration fails closed", () => {
  assert.throws(
    () =>
      loadTargets({
        MCP_SHELL_TARGETS_JSON: JSON.stringify([
          {
            id: "example-linux",
            label: "Example Linux target",
            platform: "linux",
            executor: "host_local_executor",
            capabilities: ["policy_info"],
          },
        ]),
      }),
    /host-local capability IDs/
  );
});

test("route_request checks declared target capabilities without executing anything", async () => {
  const env = {
    MCP_SHELL_TARGETS_JSON: JSON.stringify([
      {
        id: "read-only-linux",
        label: "Read-only Linux target",
        platform: "linux",
        executor: "host_local_executor",
        capabilities: ["filesystem_read", "git_read"],
      },
    ]),
  };

  const ok = await route_request(
    { capability: "filesystem_read", target_id: "read-only-linux" },
    env
  );
  assert.equal(ok.status, "ok");
  assert.equal(ok.route, "host_local_executor");

  const denied = await route_request(
    { capability: "command_run", target_id: "read-only-linux" },
    env
  );
  assert.equal(denied.status, "failed");
  assert.equal(denied.error, "capability_not_declared");
});

test("describe_control_plane documents the non-execution boundary", async () => {
  const result = await describe_control_plane();
  assert.equal(result.status, "ok");
  assert.equal(result.policy.role, "sites_control_plane");
  assert.match(
    result.policy.invariants.join("\n"),
    /Sites does not execute shell commands/
  );
  assert.match(
    result.policy.invariants.join("\n"),
    /Execution remains on the host-local mcp-shell executor/
  );
});
