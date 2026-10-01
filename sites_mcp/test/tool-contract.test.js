import assert from "node:assert/strict";
import test from "node:test";

import { tools } from "../server.js";

test("Sites exports exactly the three reviewed control-plane tools", () => {
  assert.deepEqual(
    tools.map((tool) => tool.name),
    ["describe_control_plane", "list_targets", "route_request"]
  );
});

test("all Site tools are read-only and closed-world", () => {
  for (const tool of tools) {
    assert.equal(tool.readOnlyHint, true, `${tool.name} must remain read-only`);
    assert.equal(tool.openWorldHint, false, `${tool.name} must remain closed-world`);
    assert.equal(typeof tool.handler, "function");
  }
});

test("describe and list tools accept no input fields", () => {
  for (const name of ["describe_control_plane", "list_targets"]) {
    const tool = tools.find((candidate) => candidate.name === name);
    assert.deepEqual(tool.inputSchema, {
      type: "object",
      additionalProperties: false,
      properties: {},
    });
  }
});

test("route_request keeps a narrow classification-only schema", () => {
  const tool = tools.find((candidate) => candidate.name === "route_request");

  assert.deepEqual(tool.inputSchema, {
    type: "object",
    required: ["capability"],
    additionalProperties: false,
    properties: {
      capability: { type: "string" },
      target_id: { type: "string" },
    },
  });
});

test("tool names do not expose execution or transport primitives", () => {
  const serialized = tools.map((tool) => tool.name).join("\n");
  assert.doesNotMatch(
    serialized,
    /(shell|exec|command|filesystem|git_|service|proxy|relay|http|fetch)/i
  );
});
