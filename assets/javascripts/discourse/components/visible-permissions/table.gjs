import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VisiblePermissionsTable extends Component {
  @service siteSettings;
  @service currentUser;
  @service visiblePermissionsCache;

  @tracked data = null;
  @tracked loading = false;
  @tracked error = false;
  @tracked _element = null;
  @tracked showHeader = false;

  _lastCategoryId = null;

  constructor(...args) {
    super(...args);

    this.getTotalCount = this.getTotalCount.bind(this);

    if (this.args.data) {
      this.data = this.args.data;
      this.args = this.args.data;
    }
  }

  get shouldRender() {
    return !!this.currentUser;
  }

  get viewType() {
    return (
      this.args.view ||
      this.siteSettings.discourse_visible_permissions_default_view ||
      "table"
    );
  }

  get isShortView() {
    return this.viewType === "short";
  }

  get localizedTableTitle() {
    if (!this.data) {
      return "";
    }
    return i18n("js.discourse_visible_permissions.table_title", {
      category_name: this.data.category_name || "Unknown",
    });
  }

  @action
  async fetchData(element) {
    if (element instanceof HTMLElement) {
      this._element = element;
    }

    const currentElement =
      element instanceof HTMLElement ? element : this._element;

    if (this.loading) {
      return;
    }

    if (this.args.data && Object.keys(this.args.data).length > 0) {
      this.data = this.args.data;
      return;
    }

    let rawId = this.args.categoryId;

    const isValidId = (id) => {
      const parsed = parseInt(id, 10);
      return !isNaN(parsed) && parsed > 0;
    };

    if (!isValidId(rawId) && currentElement) {
      const container = currentElement.closest("[data-category-id]");
      rawId = container?.dataset?.categoryId;
    }

    const categoryId = parseInt(rawId, 10);

    if (isNaN(categoryId) || categoryId <= 0) {
      return;
    }

    const topic = this.args.topic || this.args.model?.topic;
    const modelCategory = this.args.category || this.args.model?.category;
    
    const categorySource = [modelCategory, topic?.category].find(c => c?.id === categoryId && c?.visible_permissions);
    
    if (categorySource?.visible_permissions) {
      this.visiblePermissionsCache.setPermissions(categoryId, categorySource.visible_permissions);
      this.data = categorySource.visible_permissions;
      this._lastCategoryId = categoryId;
      return;
    }

    this.loading = true;
    this.error = false;
    try {
      this.data = await this.visiblePermissionsCache.getPermissions(categoryId);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("VisiblePermissionsTable Error:", e);
      this.data = null;
      this.error = true;
    } finally {
      this.loading = false;
      this._lastCategoryId = categoryId;
    }
  }

  get processedPermissions() {
    if (!this.data?.group_permissions) {
      return [];
    }
    return this.data.group_permissions.map((perm) => {
      let permIcon, permColor, permTitle;
      if (perm.permission_type === 1) {
        permIcon = "plus";
        permColor =
          this.siteSettings.discourse_visible_permissions_color_create;
        permTitle = i18n("js.category.permissions.create");
      } else if (perm.permission_type === 2) {
        permIcon = "reply";
        permColor = this.siteSettings.discourse_visible_permissions_color_reply;
        permTitle = i18n("js.category.permissions.reply");
      } else if (perm.permission_type === 3) {
        permIcon = "eye";
        permColor = this.siteSettings.discourse_visible_permissions_color_see;
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
    return i18n(`js.discourse_visible_permissions.notification_levels.${key}`);
  }

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


  getCount(perm, lvl) {
    const counts = perm.notification_levels;
    if (!counts) {
      return "";
    }
    const count = counts[lvl] || 0;
    return count > 0 ? count : "";
  }

  getTotalCount(level) {
    // Defensiver Check verhindert Crash wenn 'this' oder 'data' fehlt
    if (!this?.data?.category_notification_totals) {
      return -1;
    }
    return this.data.category_notification_totals[level] || "";
  }

  get totalReach() {
    return this.data?.category_notification_totals?.total_reach || 0;
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class="discourse-visible-permissions-container view-{{this.viewType}}"
        {{didInsert this.fetchData}}
        {{didUpdate this.fetchData @categoryId}}
      >
        {{#if this.loading}}
          <div class="loading-placeholder">{{i18n
              "discourse_visible_permissions.loading"
            }}</div>
        {{else if this.error}}
          <div class="error-placeholder">{{i18n
              "discourse_visible_permissions.load_error"
            }}</div>
        {{else if this.data}}
          {{#if this.showHeader}}
          <h3 class="discourse-visible-permissions-title">
            {{this.localizedTableTitle}}
          </h3>
          {{/if}}

          {{#if this.isShortView}}
            <div
              class="discourse-visible-permissions-short-container cell view-short"
            >
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
            <table class="discourse-visible-permissions-table modern-view">
              <thead>
                <tr>
                  <th colspan="3">Berechtigungen</th>
                  <th colspan="5">Benachrichtigungen</th>
                </tr>  
                <tr>
                  <th class="group-name-header">{{i18n
                      "js.discourse_visible_permissions.group_name"
                    }}</th>
                  <th
                    class="users-count-header"
                    title={{i18n
                      "js.discourse_visible_permissions.group_users_count"
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
                          title={{i18n "js.discourse_visible_permissions.join"}}
                        >
                          {{dIcon "plus"}}
                        </a>
                      {{else if perm.can_request}}
                        <a
                          href={{perm.group_url}}
                          class="group-action-link request"
                          title={{i18n
                            "js.discourse_visible_permissions.request"
                          }}
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
                    {{i18n "js.discourse_visible_permissions.total"}}
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
