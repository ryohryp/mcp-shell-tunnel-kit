import test from "node:test";
import assert from "node:assert/strict";
import { validatePublicUrl, validateResolvedPublicUrl, validateAction, LIMITS } from "../policy.js";
import { createSession, prepareGoal } from "../contracts.js";

test("allows public https", () => assert.equal(validatePublicUrl("https://example.com/a").status, "ok"));
for (const url of [
  "http://127.0.0.1/",
  "http://10.0.0.1/",
  "http://169.254.169.254/computeMetadata/v1/",
  "http://metadata.google.internal/",
  "file:///etc/passwd",
  "javascript:alert(1)",
  "https://user:pass@example.com/",
]) {
  test(`blocks unsafe destination: ${url}`, () => assert.equal(validatePublicUrl(url).status, "failed"));
}
test("rejects arbitrary javascript action", () => {
  assert.equal(validateAction({type:"evaluate_js", script:"document.cookie"}).status, "failed");
});
test("requires semantic ref for click", () => {
  assert.equal(validateAction({type:"click", ref:"button_1"}).status, "ok");
  assert.equal(validateAction({type:"click"}).status, "failed");
});
test("caps goal action budget", () => {
  assert.equal(prepareGoal({goal:"Find documentation",start_url:"https://example.com",max_actions:LIMITS.maxActions}).status,"ok");
  assert.equal(prepareGoal({goal:"Find documentation",start_url:"https://example.com",max_actions:LIMITS.maxActions+1}).status,"failed");
});
test("session is isolated and unauthenticated", () => {
  const s=createSession({start_url:"https://example.com"});
  assert.equal(s.authenticated_profile,false);
  assert.equal(s.mode,"isolated_public_read");
});

test("blocks DNS names resolving to private addresses", async () => {
  const fakeLookup=async()=>[{address:"10.1.2.3",family:4}];
  assert.equal((await validateResolvedPublicUrl("https://public-looking.example/",fakeLookup)).status,"failed");
});
test("allows DNS names resolving only to public addresses", async () => {
  const fakeLookup=async()=>[{address:"93.184.216.34",family:4}];
  assert.equal((await validateResolvedPublicUrl("https://example.com/",fakeLookup)).status,"ok");
});
test("fill_text stays disabled until a safe field policy exists", () => {
  assert.equal(validateAction({type:"fill_text",ref:"field_1",text:"x"}).status,"failed");
});
