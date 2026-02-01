import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import VisiblePermissionsDetails from "./modal/visible-permissions-details";

const PERMISSIONS_CACHE = new Map();

export default class VisiblePermissionsSummary extends Component {
  @service modal;
  @service siteSettings;
  @service currentUser;

  @tracked data = null;
  @tracked loading = false;
  
  _lastCategoryId = null;

  get categoryId() {
    const args = this.args || {};
    const outletArgs = args.outletArgs || {};
    return (
      args.category?.id ||
      outletArgs.category?.id ||
      args.topic?.category_id ||
      outletArgs.topic?.category_id ||
      outletArgs.composer?.category_id
    );
  }

  get shouldShow() {
    if (!this.siteSettings.discourse_visible_permissions_enabled) {return false;}
    if (!this.currentUser) {return false;}
    if (this.currentUser.trust_level < this.siteSettings.discourse_visible_permissions_min_trust_level) {return false;}
    return !!this.categoryId;
  }

  get notificationTotals() {
    if (!this.data?.category_notification_totals) {return [];}
    return [3, 4, 2, 0].map((lvl) => {
      const count = this.data.category_notification_totals[lvl] || 0;
      if (count > 0) {
        let icon = "bell";
        if (lvl === 3) {icon = "d-watching";}
        else if (lvl === 4) {icon = "d-watching-first";}
        else if (lvl === 2) {icon = "d-tracking";}
        else if (lvl === 0) {icon = "d-muted";}
        return { count, icon };
      }
      return null;
    }).filter(Boolean);
  }

  @action
  async fetchData() {
    const categoryId = this.categoryId;
    // eslint-disable-next-line no-console
    console.log("VisiblePermissionsSummary Debug: fetchData with categoryId:", categoryId);
    if (!categoryId || categoryId === this._lastCategoryId) {return;}
    this._lastCategoryId = categoryId;

    // First check if the data is already in components args (from CategorySerializer)
    const category = this.args.category || this.args.outletArgs?.category;
    if (category?.visible_permissions) {
      this.data = category.visible_permissions;
      return;
    }

    if (PERMISSIONS_CACHE.has(categoryId)) {
      console.log("VisiblePermissionsSummary Debug: Cache SUCCESS 😇", categoryId);
      this.data = PERMISSIONS_CACHE.get(categoryId);
      return;
    }
    this.loading = true;
    try {
      const data = await ajax(`/c/${categoryId}/permissions.json`);
      console.log("VisiblePermissionsSummary Debug: AJAX SUCCESS 😍", categoryId);
      PERMISSIONS_CACHE.set(categoryId, data);
      this.data = data;
    } catch {
      this.data = null;
    } finally {
      this.loading = false;
    }
  }

  @action
  showDetails(event) {
    event.preventDefault();
    if (this.data) {
      const categoryId = this.categoryId;
      // eslint-disable-next-line no-console
      console.log("VisiblePermissionsSummary Debug: opening modal with categoryId", categoryId);
      this.modal.show(VisiblePermissionsDetails, {
        model: { 
          data: this.data, 
          categoryId 
        },
      });
    }
  }

  <template>
    {{#if this.shouldShow}}
      <div 
        class="discourse-visible-permissions-summary"
        {{didInsert this.fetchData}}
        {{didUpdate this.fetchData @outletArgs.category.id}}
        {{didUpdate this.fetchData @topic.category_id}}
      >
        {{#if this.loading}}
          <span class="loading-placeholder">{{i18n "discourse_visible_permissions.loading"}}</span>
        {{else if this.data}}
          <a href {{on "click" this.showDetails}} class="permissions-summary-trigger">
            <span
              class="sum-symbol"
              title={{i18n "js.discourse_visible_permissions.potential_notifications"}}
            > &Sigma;</span>
            <!-- 
            <span class="summary-label">{{i18n "discourse_visible_permissions.potential_notifications"}}:</span>
            -->
            <div class="notification-levels-container compact">
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
