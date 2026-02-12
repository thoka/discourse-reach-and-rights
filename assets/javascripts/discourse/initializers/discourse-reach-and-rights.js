import { withPluginApi } from "discourse/lib/plugin-api";
import ReachAndRightsTable from "../components/reach-and-rights/table";
import ReachAndRightsSummary from "../components/reach-and-rights-summary";

export default {
  name: "discourse-reach-and-rights",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.discourse_reach_and_rights_enabled) {
      return;
    }

    withPluginApi((api) => {
      // Summary im Header vor dem "Thema erstellen" Button
      api.renderInOutlet("after-create-topic-button", ReachAndRightsSummary);
      api.renderInOutlet(
        "topic-footer-main-buttons-before-create",
        ReachAndRightsSummary
      );

      // BBCode decoration
      api.decorateCookedElement(
        (element, helper) => {
          const placeholders = element.querySelectorAll(
            ".discourse-reach-and-rights, .discourse-visible-permissions"
          );
          if (placeholders.length === 0) {
            return;
          }

          if (!helper || !helper.renderGlimmer) {
            return;
          }

          placeholders.forEach((placeholder) => {
            let categoryId = placeholder.dataset.category;
            const view = placeholder.dataset.view || "table";
            const showHeader = placeholder.dataset.showHeader;
            const style = placeholder.dataset.style;

            if (!categoryId && helper.model) {
              categoryId =
                helper.model.topic?.category_id || helper.model.category_id;
            }

            if (categoryId) {
              const parsedId = parseInt(categoryId, 10);

              // Wichtig für den Fallback in table.gjs
              placeholder.setAttribute("data-category-id", parsedId);
              placeholder.dataset.categoryId = parsedId;

              if (
                view === "modal" ||
                view === "summary" ||
                style === "summary"
              ) {
                helper.renderGlimmer(placeholder, ReachAndRightsSummary, {
                  categoryId: parsedId,
                  topic: helper.model?.topic || helper.model,
                });
              } else {
                helper.renderGlimmer(placeholder, ReachAndRightsTable, {
                  categoryId: parsedId,
                  topic: helper.model?.topic || helper.model,
                  view,
                  showHeader,
                  style,
                });
              }

              placeholder.classList.remove("discourse-reach-and-rights");
              placeholder.classList.remove("discourse-visible-permissions");
              placeholder.classList.add("discourse-reach-and-rights-rendered");
            } else {
              placeholder.innerHTML = "";
            }
          });
        },
        { id: "discourse-reach-and-rights-bbcode" }
      );
    });
  },
};
