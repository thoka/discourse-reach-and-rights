import { module, test } from "qunit";
import initializer from "discourse/plugins/discourse-reach-and-rights/discourse/initializers/discourse-reach-and-rights";

module("Unit | Initializers | discourse-reach-and-rights", function () {
  test("it exposes a valid initializer", function (assert) {
    assert.strictEqual(initializer.name, "discourse-reach-and-rights");
    assert.strictEqual(typeof initializer.initialize, "function");
  });
});
