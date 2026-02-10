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

  constructor() {
    super(...arguments);
    // console.log("Initial Args:", JSON.stringify(this.args,null,2));
  }

  get effectiveData() {
    if (!this || this.isDestroyed || this.isDestroying) {
      return null;
    }
    // eslint-disable-next-line no-unused-expressions
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
      args.category?.id ||
      outletArgs.category?.id ||
      args.topic?.category_id ||
      outletArgs.topic?.category_id ||
      outletArgs.composer?.category_id;

    const parsed = parseInt(rawId, 10);
    return isNaN(parsed) || parsed <= 0 ? null : parsed;
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

  get notificationTotals() {
    const data = this.effectiveData;
    if (!data?.category_notification_totals) {
      return [];
    }
    return [3, 4, 2, 0]
      .map((lvl) => {
        const count = data.category_notification_totals[lvl] || 0;
        if (count > 0) {
          let icon = "bell";
          if (lvl === 3) {
            icon = "d-watching";
          } else if (lvl === 4) {
            icon = "d-watching-first";
          } else if (lvl === 2) {
            icon = "d-tracking";
          } else if (lvl === 0) {
            icon = "d-muted";
          }
          return { count, icon };
        }
        return null;
      })
      .filter(Boolean);
  }

  get totalReach() {
    return this.effectiveData?.category_notification_totals?.total_reach || 0;
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
      if (this.siteSettings.discourse_reach_and_rights_debug_enabled) {
        // eslint-disable-next-line no-console
        console.log("ReachAndRightsSummary [Debug] Opening modal:", {
          categoryId,
          data,
        });
      }
      this.modal.show(ReachAndRightsDetails, {
        model: {
          data,
          categoryId,
        },
      });
    }
  }

  <template>
    {{#if this.shouldShow}}
      <div
        class="discourse-reach-and-rights-summary"
        {{didInsert this.fetchData}}
        {{didUpdate this.fetchData @outletArgs.category.id}}
        {{didUpdate this.fetchData @topic.category_id}}
      >
        {{#if this.loading}}
          <span class="loading-placeholder">{{i18n
              "discourse_reach_and_rights.loading"
            }}</span>
        {{else if this.effectiveData}}
          <a
            href
            {{on "click" this.showDetails}}
            class="permissions-summary-trigger"
          >
            <span
              class="sum-symbol"
              title={{i18n
                "js.discourse_reach_and_rights.potential_notifications"
              }}
            ></span>
            {{!-- 
            <span class="summary-label">{{i18n "discourse_reach_and_rights.potential_notifications"}}:</span>
            --}}
            <div class="notification-levels-container compact">
              <span
                class="notification-level-item reach-total"
                title={{i18n "js.discourse_reach_and_rights.total_reach"}}
              >
                {{dIcon "eye"}}
                <span class="notification-count">{{this.totalReach}}</span>
              </span>

              {{#each this.notificationTotals as |lvl|}}
                <span class="notification-level-item">
                  {{dIcon lvl.icon}}
                  <span class="notification-count">{{lvl.count}}</span>
                </span>
              {{/each}}
            </div>
            {{dIcon "info-circle" class="details-icon"}}
          </a>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
