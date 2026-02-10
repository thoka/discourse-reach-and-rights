const REACH_AND_RIGHTS_MATCHER =
  /\[(reach-and-rights|show-permissions)[^\]]*\]/;

function addReachAndRights(buffer, state, attributes, applyDataAttributes) {
  let token = new state.Token("span_open", "span", 1);
  token.attrs = [["class", "discourse-reach-and-rights"]];
  applyDataAttributes(token, attributes, "category");
  applyDataAttributes(token, attributes, "view");
  buffer.push(token);

  token = new state.Token("text", "", 0);
  token.content = "";
  buffer.push(token);

  token = new state.Token("span_close", "span", -1);
  buffer.push(token);
}

function reachAndRights(
  buffer,
  matches,
  state,
  { parseBBCodeTag, applyDataAttributes }
) {
  const parsed = parseBBCodeTag(matches[0], 0, matches[0].length);

  if (
    parsed?.tag === "reach-and-rights" ||
    parsed?.tag === "show-permissions"
  ) {
    addReachAndRights(buffer, state, parsed.attrs || {}, applyDataAttributes);
  } else {
    let token = new state.Token("text", "", 0);
    token.content = matches[0];
    buffer.push(token);
  }
}

export function setup(helper) {
  helper.allowList([
    "span.discourse-reach-and-rights",
    "span.discourse-visible-permissions",
    "span[data-category=*]",
  ]);

  helper.registerPlugin((md) => {
    md.core.textPostProcess.ruler.push("reach-and-rights", {
      matcher: REACH_AND_RIGHTS_MATCHER,
      onMatch: reachAndRights,
    });
  });
}
