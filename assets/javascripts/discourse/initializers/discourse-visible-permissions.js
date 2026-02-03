import { withPluginApi } from "discourse/lib/plugin-api";
import VisiblePermissionsTable from "../components/visible-permissions/table";
import VisiblePermissionsSummary from "../components/visible-permissions-summary";

export default {
  name: "discourse-visible-permissions",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.discourse_visible_permissions_enabled) {
      return;
    }

    withPluginApi((api) => {
      // Summary im Header vor dem "Thema erstellen" Button
      api.renderInOutlet("after-create-topic-button", VisiblePermissionsSummary);
      api.renderInOutlet("topic-footer-main-buttons-before-create", VisiblePermissionsSummary);

      // BBCode decoration
      api.decorateCookedElement(
        (element, helper) => {
          const placeholders = element.querySelectorAll(".discourse-visible-permissions");
          if (placeholders.length === 0) {
            return;
          }

          if (!helper || !helper.renderGlimmer) {
            return;
          }

          placeholders.forEach((placeholder) => {
            let categoryId = placeholder.dataset.category;
            const view = placeholder.dataset.view || "table";

            if (!categoryId && helper.model) {
              categoryId = helper.model.topic?.category_id || helper.model.category_id;
            }

            if (categoryId) {
              const parsedId = parseInt(categoryId, 10);
              
              // Wichtig für den Fallback in table.gjs
              placeholder.setAttribute("data-category-id", parsedId);
              placeholder.dataset.categoryId = parsedId;

              helper.renderGlimmer(placeholder, VisiblePermissionsTable, {
                categoryId: parsedId,
                view,
              });

              placeholder.classList.remove("discourse-visible-permissions");
              placeholder.classList.add("discourse-visible-permissions-rendered");
            } else {
              placeholder.innerHTML = ""; 
            }
          });
        },
        { id: "discourse-visible-permissions-bbcode" }
      );
    });
  },
};
