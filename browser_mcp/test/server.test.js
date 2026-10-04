import test from "node:test";
import assert from "node:assert/strict";
import { executeGoal, tools } from "../server.js";

test("browser tool metadata does not claim actions are read-only", () => {
  const byName=Object.fromEntries(tools.map(t=>[t.name,t]));
  assert.equal(byName.browser_navigate.readOnlyHint,true);
  assert.equal(byName.browser_observe.readOnlyHint,true);
  assert.equal(byName.browser_act.readOnlyHint,false);
  assert.equal(byName.browser_verify.readOnlyHint,true);
  assert.equal(byName.browser_execute_goal.readOnlyHint,false);
});

function runtimeFixture() {
  let url = "https://example.com/";
  let actions = 0;
  let phase = 0;
  const pages = [
    {url:"https://example.com/", snapshot:"page one", candidates:[{ref:"link_0",name:"Docs",href:"https://example.com/docs"}]},
    {url:"https://example.com/docs", snapshot:"docs page", candidates:[]},
  ];
  return {
    async navigate(next) { url = next; actions += 1; return {status:"ok",url}; },
    async snapshot() { return {status:"ok",...pages[phase]}; },
    async act(action) {
      assert.deepEqual(action,{type:"follow_link",ref:"link_0"});
      phase = 1;
      url = pages[1].url;
      actions += 1;
      return {status:"ok",url};
    },
    async verify() { return {status:"ok",...pages[phase],verification:{url_policy:"ok",snapshot:"ok"}}; },
    metrics() { return {actions,elapsed_ms:1}; },
  };
}

test("executeGoal completes on the initial verified snapshot", async () => {
  const runtime=runtimeFixture();
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:2},
    runtime,
    async () => ({decision:"complete"}),
  );
  assert.equal(result.status,"ok");
  assert.equal(result.actions,1);
  assert.equal(result.verification.semantic,"complete");
});

test("executeGoal only lets the judge choose supplied candidates", async () => {
  const runtime=runtimeFixture();
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:2},
    runtime,
    async () => ({decision:"act",candidate_ref:"link_99"}),
  );
  assert.equal(result.status,"failed");
  assert.equal(result.error,"judge_invalid");
});

test("executeGoal acts, verifies independently, then accepts semantic completion", async () => {
  const runtime=runtimeFixture();
  let calls=0;
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:2},
    runtime,
    async ({candidates}) => {
      calls += 1;
      if (calls === 1) {
        assert.deepEqual(candidates.map(x=>x.ref),["link_0"]);
        return {decision:"act",candidate_ref:"link_0"};
      }
      return {decision:"complete"};
    },
  );
  assert.equal(result.status,"ok");
  assert.equal(result.actions,2);
  assert.equal(result.url,"https://example.com/docs");
});

test("executeGoal reports judge failure separately from browser failure", async () => {
  const runtime=runtimeFixture();
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:2},
    runtime,
    async () => { throw new Error("jev unavailable"); },
  );
  assert.equal(result.status,"failed");
  assert.equal(result.error,"judge_failed");
});

test("executeGoal fails closed without a judge", async () => {
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:2},
    runtimeFixture(),
  );
  assert.equal(result.status,"failed");
  assert.equal(result.error,"judge_unavailable");
});

test("executeGoal preserves the caller action budget", async () => {
  const runtime=runtimeFixture();
  const result=await executeGoal(
    {goal:"Find docs",start_url:"https://example.com",max_actions:1},
    runtime,
    async () => ({decision:"act",candidate_ref:"link_0"}),
  );
  assert.equal(result.status,"failed");
  assert.equal(result.error,"budget_exceeded");
  assert.equal(result.actions,1);
});
