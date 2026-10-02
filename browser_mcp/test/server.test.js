import test from "node:test";
import assert from "node:assert/strict";
import { tools } from "../server.js";

test("browser tool metadata does not claim actions are read-only", () => {
  const byName=Object.fromEntries(tools.map(t=>[t.name,t]));
  assert.equal(byName.browser_navigate.readOnlyHint,true);
  assert.equal(byName.browser_observe.readOnlyHint,true);
  assert.equal(byName.browser_act.readOnlyHint,false);
  assert.equal(byName.browser_execute_goal.readOnlyHint,false);
});
