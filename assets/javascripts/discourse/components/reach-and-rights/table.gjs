import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReachAndRightsTable extends Component {
  @service siteSettings;
  @service currentUser;
  @service reachAndRightsCache;

  @tracked data = null;
  @tracked loading = false;
  @tracked error = false;
  @tracked _element = null;
  @tracked _manualCategoryId = null;

  _lastCategoryId = null;

  get categoryId() {
    if (!this || this.isDestroyed || this.isDestroying) {
      return null;
    }

    if (this._manualCategoryId) {
      return this._manualCategoryId;
    }

    const args = this.args || {};
    let rawId = args.categoryId || args.model?.categoryId;

    const isValidId = (id) => {
      const parsed = parseInt(id, 10);
      return !isNaN(parsed) && parsed > 0;
    };

    if (!isValidId(rawId) && this._element) {
      const container = this._element.closest("[data-category-id]");
      rawId = container?.dataset?.categoryId;
    }

    const parsed = parseInt(rawId, 10);
    return isNaN(parsed) || parsed <= 0 ? null : parsed;
  }

  get effectiveData() {
    if (!this || this.isDestroyed || this.isDestroying) {
      return {};
    }

    // Consume version for reactivity to cache updates
    if (this.reachAndRightsCache) {
      this.reachAndRightsCache._cacheVersion;
    }

    const categoryId = this.categoryId;
    if (!categoryId) {
      return {};
    }

    // Prefer explicitly passed or locally fetched data, but only if it contains permissions
    if (
      this.data &&
      parseInt(this.data.category_id, 10) === categoryId &&
      this.data.group_permissions
    ) {
      return this.data;
    }

    // Fallback to cache lookup
    const cached = this.reachAndRightsCache?._cache?.get?.(categoryId)?.data;
    return cached || {};
  }

  get showHeader() {
    return this.args.showHeader !== "false" && this.args.showHeader !== false;
  }

  get shouldRender() {
    return !!this.currentUser;
  }

  get viewType() {
    return (
      this.args.view ||
      this.siteSettings.discourse_reach_and_rights_default_view ||
      "table"
    );
  }

  get isShortView() {
    return this.viewType === "short";
  }

  get localizedTableTitle() {
    const data = this.effectiveData;
    if (!this.hasData) {
      return "";
    }
    return i18n("js.discourse_reach_and_rights.table_title", {
      category_name: data.category_name || "Unknown",
    });
  }

  get hasData() {
    const data = this.effectiveData;
    return (
      data &&
      (data.group_permissions?.length > 0 || data.category_notification_totals)
    );
  }

  @action
  async fetchData(element) {
    if (element instanceof HTMLElement) {
      this._element = element;
    }

    if (this.loading) {
      return;
    }

    if (
      this.args.data?.group_permissions &&
      this.args.data.group_permissions.length > 0
    ) {
      this.data = this.args.data;
      return;
    }

    const categoryId = this.categoryId;

    if (!categoryId) {
      return;
    }

    const hasDetailedData =
      this.data &&
      parseInt(this.data.category_id, 10) === categoryId &&
      this.data.group_permissions;

    if (categoryId === this._lastCategoryId && hasDetailedData) {
      return;
    }

    if (this._element && !this._manualCategoryId) {
      this._manualCategoryId = categoryId;
    }

    if (this.data && parseInt(this.data.category_id, 10) !== categoryId) {
      this.data = null;
    }

    this._lastCategoryId = categoryId;

    this.loading = true;
    this.error = false;
    try {
      this.data = await this.reachAndRightsCache.getPermissions(categoryId);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("ReachAndRightsTable Error:", e);
      this.data = null;
      this.error = true;
    } finally {
      this.loading = false;
      this._lastCategoryId = categoryId;
    }
  }

  get processedPermissions() {
    const data = this.effectiveData;
    if (!data?.group_permissions) {
      return [];
    }
    return data.group_permissions.map((perm) => {
      let permIcon, permColor, permTitle;
      if (perm.permission_type === 1) {
        permIcon = "plus";
        permColor = this.siteSettings.discourse_reach_and_rights_color_create;
        permTitle = i18n("js.category.permissions.create");
      } else if (perm.permission_type === 2) {
        permIcon = "reply";
        permColor = this.siteSettings.discourse_reach_and_rights_color_reply;
        permTitle = i18n("js.category.permissions.reply");
      } else if (perm.permission_type === 3) {
        permIcon = "eye";
        permColor = this.siteSettings.discourse_reach_and_rights_color_see;
        permTitle = i18n("js.category.permissions.see");
      }

      return {
        ...perm,
        permIcon,
        permStyle: permColor
          ? htmlSafe(`background-color: ${permColor}`)
          : null,
        permTitle,
        defaultIcon: this.getNotificationIcon(perm.notification_level),
        defaultTitle: this.getNotificationTitle(perm.notification_level),
      };
    });
  }

  @action
  getNotificationIcon(lvl) {
    if (lvl === 3) {
      return "d-watching";
    }
    if (lvl === 4) {
      return "d-watching-first";
    }
    if (lvl === 2) {
      return "d-tracking";
    }
    if (lvl === 1) {
      return "bell";
    }
    if (lvl === 0) {
      return "d-muted";
    }
    return null;
  }

  @action
  getNotificationTitle(lvl) {
    if (lvl === null || lvl === undefined) {
      return "";
    }
    const key =
      lvl === 3
        ? "watching"
        : lvl === 4
          ? "watching_first_post"
          : lvl === 2
            ? "tracking"
            : lvl === 1
              ? "regular"
              : "muted";
    return i18n(`js.discourse_reach_and_rights.notification_levels.${key}`);
  }

  @action
  getNotificationTitleByName(level) {
    if (level === 3) {
      return "watching";
    }
    if (level === 4) {
      return "watching_first_post";
    }
    if (level === 2) {
      return "tracking";
    }
    if (level === 1) {
      return "regular";
    }
    if (level === 0) {
      return "muted";
    }
    return "";
  }

  @action
  getCount(perm, lvl) {
    const counts = perm.notification_levels;
    if (!counts) {
      return "";
    }
    const count = counts[lvl] || 0;
    return count > 0 ? count : "";
  }

  @action
  getTotalCount(level) {
    const data = this.effectiveData;
    if (!data?.category_notification_totals) {
      return -1;
    }
    return data.category_notification_totals[level] || "";
  }

  get totalReach() {
    return this.effectiveData?.category_notification_totals?.total_reach || 0;
  }

  get debugData() {
    const categoryId = this.categoryId;
    const data = this.effectiveData;
    const cacheEntry = this.reachAndRightsCache._cache.get(categoryId);
    const cacheKeys = Array.from(this.reachAndRightsCache._cache.keys()).join(
      ","
    );
    const localKeys = this.data ? Object.keys(this.data).join(",") : "null";
    const effectiveKeys = data ? Object.keys(data).join(",") : "none";
    const hasPerms = !!data?.group_permissions;

    return `ID: ${categoryId} (${typeof categoryId}) | Lcl: ${typeof this.data} [${localKeys}] | Cch: ${!!cacheEntry} | L: ${this.loading} | D: ${hasPerms} | Eff: [${effectiveKeys}] | Keys: [${cacheKeys}]`;
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class="discourse-reach-and-rights-container view-{{this.viewType}}"
        style={{@style}}
        {{didInsert this.fetchData}}
        {{didUpdate this.fetchData @categoryId}}
      >
        {{#if this.loading}}
          <div class="loading-placeholder">{{i18n
              "discourse_reach_and_rights.loading"
            }}</div>
        {{else if this.error}}
          <div class="error-placeholder">{{i18n
              "discourse_reach_and_rights.load_error"
            }}</div>
        {{else if this.hasData}}
          {{#if this.showHeader}}
            <h3 class="discourse-reach-and-rights-title">
              {{this.localizedTableTitle}}
            </h3>
          {{/if}}

          {{#if this.isShortView}}
            <div class="discourse-reach-and-rights-short-container cell">
              {{#each this.processedPermissions as |perm|}}
                <div class="permission-item cell">
                  <span class="group-name">{{perm.group_display_name}}</span>:
                  <div
                    class="permission-badge"
                    style={{perm.permStyle}}
                    title={{perm.permTitle}}
                  >
                    {{dIcon perm.permIcon}}
                  </div>
                </div>
              {{/each}}
            </div>
          {{else}}
            <table class="discourse-reach-and-rights-table modern-view">
              <thead>
                <tr>
                  <th colspan="3">Berechtigungen</th>
                  <th colspan="5">Benachrichtigungen</th>
                </tr>
                <tr>
                  <th class="group-name-header">{{i18n
                      "js.discourse_reach_and_rights.group_name"
                    }}</th>
                  <th
                    class="users-count-header"
                    title={{i18n
                      "js.discourse_reach_and_rights.group_users_count"
                    }}
                  >{{dIcon "users"}}</th>
                  <th class="permission-badge-header"></th>
                  <th class="notification-header default"></th>
                  <th
                    class="notification-header level-3"
                    title={{this.getNotificationTitle 3}}
                  >{{dIcon (this.getNotificationIcon 3)}}</th>
                  <th
                    class="notification-header level-4"
                    title={{this.getNotificationTitle 4}}
                  >{{dIcon (this.getNotificationIcon 4)}}</th>
                  <th
                    class="notification-header level-2"
                    title={{this.getNotificationTitle 2}}
                  >{{dIcon (this.getNotificationIcon 2)}}</th>
                  <th
                    class="notification-header level-0"
                    title={{this.getNotificationTitle 0}}
                  >{{dIcon (this.getNotificationIcon 0)}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each this.processedPermissions as |perm|}}
                  <tr
                    class="group-row
                      {{if
                        perm.is_direct
                        'direct-permission'
                        'inherited-permission'
                      }}"
                  >
                    <td class="group-name-cell cell">
                      <a
                        href={{perm.group_url}}
                        class="group-link"
                      >{{perm.group_display_name}}</a>

                      {{#if perm.can_join}}
                        <a
                          href={{perm.group_url}}
                          class="group-action-link join"
                          title={{i18n "js.discourse_reach_and_rights.join"}}
                        >
                          {{dIcon "plus"}}
                        </a>
                      {{else if perm.can_request}}
                        <a
                          href={{perm.group_url}}
                          class="group-action-link request"
                          title={{i18n "js.discourse_reach_and_rights.request"}}
                        >
                          {{dIcon "paper-plane"}}
                        </a>
                      {{/if}}
                    </td>
                    <td class="users-count-cell num">
                      {{perm.user_count}}
                    </td>
                    <td
                      class="permission-badge-cell cell"
                      title={{perm.permTitle}}
                    >
                      <div class="permission-badge" style={{perm.permStyle}}>
                        {{dIcon perm.permIcon}}
                      </div>
                    </td>
                    <td class="notification-cell default-cell cell">
                      {{#if perm.defaultIcon}}
                        <div
                          class="notification-badge default-notification"
                          title={{perm.defaultTitle}}
                        >
                          {{dIcon perm.defaultIcon}}
                        </div>
                      {{/if}}
                    </td>
                    <td class="notification-cell level-3 cell">{{this.getCount
                        perm
                        3
                      }}</td>
                    <td class="notification-cell level-4 cell">{{this.getCount
                        perm
                        4
                      }}</td>
                    <td class="notification-cell level-2 cell">{{this.getCount
                        perm
                        2
                      }}</td>
                    <td class="notification-cell level-0 cell">{{this.getCount
                        perm
                        0
                      }}</td>
                  </tr>
                {{/each}}
              </tbody>
              <tfoot>
                <tr class="summary-row">
                  <td class="group-name-cell cell">
                    {{i18n "js.discourse_reach_and_rights.total"}}
                  </td>
                  <td class="users-count-cell num" style="text-align: center;">
                    {{this.totalReach}}
                  </td>
                  <td colspan="2"></td>
                  <td
                    class="notification-cell level-3 cell"
                  >{{this.getTotalCount 3}}</td>
                  <td
                    class="notification-cell level-4 cell"
                  >{{this.getTotalCount 4}}</td>
                  <td
                    class="notification-cell level-2 cell"
                  >{{this.getTotalCount 2}}</td>
                  <td
                    class="notification-cell level-0 cell"
                  >{{this.getTotalCount 0}}</td>
                </tr>
              </tfoot>
            </table>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
