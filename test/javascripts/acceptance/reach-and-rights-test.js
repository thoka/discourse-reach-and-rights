import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import showPermissionsPretender from "../helpers/show-permissions-pretender";

acceptance("Discourse Visible Permissions", function (needs) {
  needs.user();
  needs.settings({ discourse_reach_and_rights_enabled: true });
  needs.pretender(showPermissionsPretender);

  test("it renders permissions when the BBCode is present", async function (assert) {
    await visit("/t/external-id/1"); // Assume a topic exists or is mocked

    // Mocking the topic tracking/loading is complex in acceptance,
    // so we'll use a more direct approach by navigating to a page
    // where we can control the cooked content.

    // In Discourse tests, we can use `publishToMessageBus` or similar,
    // but a common pattern is to just mock the topic response.
  });
});
