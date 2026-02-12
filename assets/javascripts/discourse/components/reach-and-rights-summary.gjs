import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ReachAndRightsDetails from "./modal/reach-and-rights-details";

export default class ReachAndRightsSummary extends Component {
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service reachAndRightsCache;

  @tracked data = null;
  @tracked loading = false;

  _lastCategoryId = null;

  get effectiveData() {
    if (!this || this.isDestroyed || this.isDestroying) {
      return null;
    }
    if (this.reachAndRightsCache) {
      this.reachAndRightsCache._cacheVersion;
    }
    const categoryId = this.categoryId;
    if (!categoryId) {
      return null;
    }
    const cached = this.reachAndRightsCache?._cache?.get?.(categoryId)?.data;
    return cached || this.data;
  }

  get categoryId() {
    if (!this || this.isDestroyed || this.isDestroying) {
      return null;
    }
    const args = this.args || {};
    const outletArgs = args.outletArgs || {};
    const rawId =
      args.categoryId ||
      args.category?.id ||
      outletArgs.category?.id ||
      args.topic?.category_id ||
      outletArgs.topic?.category_id ||
      outletArgs.composer?.category_id;

    const parsed = parseInt(rawId, 10);
    return isNaN(parsed) || parsed <= 0 ? null : parsed;
  }

  get isFirstPost() {
    const args = this.args || {};
    const outletArgs = args.outletArgs || {};

    if (outletArgs.composer) {
      return (
        outletArgs.composer.action === "createTopic" ||
        !!outletArgs.composer.creatingTopic
      );
    }

    if (args.topic || outletArgs.topic) {
      return false;
    }

    return true;
  }

  get shouldShow() {
    if (!this.siteSettings.discourse_reach_and_rights_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (
      this.currentUser.trust_level <
      this.siteSettings.discourse_reach_and_rights_min_trust_level
    ) {
      return false;
    }
    return !!this.categoryId;
  }

  get totalReach() {
    return this.effectiveData?.category_notification_totals?.total_reach || 0;
  }

  get expectedNotificationCount() {
    const data = this.effectiveData;
    if (!data?.category_notification_totals) {
      return 0;
    }
    const watching = data.category_notification_totals["3"] || 0;
    const watchingFirst = data.category_notification_totals["4"] || 0;
    return this.isFirstPost ? watching + watchingFirst : watching;
  }

  @action
  async fetchData() {
    const categoryId = this.categoryId;
    if (!categoryId || categoryId === this._lastCategoryId) {
      return;
    }
    this._lastCategoryId = categoryId;

    const category = this.args.category || this.args.outletArgs?.category;
    if (category?.reach_and_rights) {
      this.reachAndRightsCache.setPermissions(
        categoryId,
        category.reach_and_rights
      );
      this.data = category.reach_and_rights;
      return;
    }

    this.loading = true;
    try {
      this.data = await this.reachAndRightsCache.getPermissions(categoryId);
    } catch {
      this.data = null;
    } finally {
      this.loading = false;
    }
  }

  @action
  showDetails(event) {
    event.preventDefault();
    const data = this.effectiveData;
    if (data) {
      const categoryId = this.categoryId;
      const category = this.args.category || this.args.outletArgs?.category;
      if (this.siteSettings.discourse_reach_and_rights_debug_enabled) {
        // eslint-disable-next-line no-console
        console.log("ReachAndRightsSummary [Debug] Opening modal:", {
          categoryId,
          data,
          category,
        });
      }
      this.modal.show(ReachAndRightsDetails, {
        model: {
          data,
          categoryId,
          category,
        },
      });
    }
  }

  <template>
    {{#if this.shouldShow}}
      <button
        class="discourse-reach-and-rights-summary btn permissions-summary-trigger"
        {{didInsert this.fetchData}}
        {{didUpdate this.fetchData @categoryId}}
        {{didUpdate this.fetchData @outletArgs.category.id}}
        {{didUpdate this.fetchData @topic.category_id}}
        {{on "click" this.showDetails}}
      >
        {{#if this.loading}}
          <span class="loading-placeholder">{{i18n
              "js.discourse_reach_and_rights.loading"
            }}</span>
        {{else if this.effectiveData}}
          <div class="notification-levels-container compact">
            <span
              class="notification-level-item reach-total"
              title={{i18n "js.discourse_reach_and_rights.total_reach"}}
            >
              {{dIcon "eye"}}
              <span class="notification-count">{{this.totalReach}}</span>
            </span>

            <span
              class="notification-level-item notifications-total"
              title={{i18n
                "js.discourse_reach_and_rights.potential_notifications"
              }}
            >
              {{dIcon "paper-plane"}}
              <span
                class="notification-count"
              >{{this.expectedNotificationCount}}</span>
            </span>
          </div>
        {{/if}}
      </button>
    {{/if}}
  </template>
}
