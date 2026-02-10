# Architecture Overview: Discourse Reach and Rights

This plugin provides a dynamic info box for category permissions, integrated via BBCode.

## Core Flow
1. **Frontend Decoration**: `assets/javascripts/discourse/initializers/discourse-reach-and-rights.js` uses `api.decorateCookedElement` to find `[reach-and-rights]` placeholders.
2. **Data Fetch**: It calls `GET /c/:id/permissions.json`, handled by `PermissionsController#show`.
3. **Broadened Access**: The controller checks if a user meets `min_trust_level`. Even if a user cannot "see" a category (restricted content), metadata is returned if at least one associated group is joinable/requestable.
4. **Data Aggregation**: `PermissionsFetcher` (Service) gathers category groups, permission types, and user membership status. It sorts permissions by hierarchy (highest access level first) and then by group name.
5. **Notification Summary**: Displays an aggregate row (Total) at the bottom of the table using a multi-stage SQL aggregation (CTE) to ensure each user is counted exactly once with their highest applicable notification level.
6. **Dynamic Rendering**: The initializer renders the localized UI in distinct views:
   - **Summary**: Rendered via `before-create-topic-button` outlet on category pages, providing a quick glance at group access.
   - **Table**: Injected into posts via BBCode `[reach-and-rights]` for detailed breakdowns.

## Key Components
- **BBCode**: Handled via `lib/discourse_markdown/discourse-reach-and-rights.rb`.
- **Backend API**: Rails Engine routing in `config/routes.rb`.
- **Permissions & Notifications Service**: `app/services/discourse_reach_and_rights/permissions_fetcher.rb`.
- **Styling**: `assets/stylesheets/discourse-reach-and-rights.scss` (supports configurable colors via site settings).

## Data Model Reliance
- **CategoryGroup**: Primary source for mapping `category_id` -> `group_id` -> `permission_type` (1:Full, 2:Create/Reply, 3:Read).
- **GroupCategoryNotificationDefault**: Baseline notification levels for groups.
- **CategoryUser**: Individual user overrides for category notification levels.
- **ReachAndRightsStat**: Stores pre-calculated reach and notification metrics per category.

## Reach Statistics (Background Processing)
To avoid expensive on-the-fly calculations (especially for mailing list mode users), reach metrics are pre-calculated and persisted.

### Metrics
1. **Reach**: Total unique users who have at least "Read" access to the category.
2. **Watching**: Users receiving notifications for *all* posts. Includes:
   - Users with explicit "Watching" level.
   - Users in "Mailing List Mode" who have not muted the category.
3. **Watching First Post**: Users receiving notifications for *new topics*. Includes:
   - All users in the "Watching" group.
   - Users with explicit "Watching First Post" level.

### Persistence & Distribution
- **Storage**: PostgreSQL table `reach_and_rights_stats`.
- **Background Job**: `Jobs::UpdateReachStats` (Scheduled) runs periodically (hourly) to refresh all categories.
- **Initial Boot**: On plugin initialization, a deferred task checks if stats exist and runs the calculation if the table is empty.
- **Real-time Updates**: Changes are published via `MessageBus` to `/reach-and-rights/stats`.
- **Serialization**: 
  - Included in `BasicCategorySerializer` for individual category requests.
  - Merged into the `categories` array within `SiteSerializer` for global availability on app boot without additional API calls.

## Lessons Learned & Best Practices

### Glimmer Argument Binding in Decorators
When using `api.decorateCookedElement` with `helper.renderGlimmer`, arguments passed in the third parameter may not be immediately available in the component's `args` (they often appear as an empty Proxy in the constructor).

**Strategy for Robust Data Transfer:**
1. **DOM as Source of Truth**: Always write critical IDs (like `categoryId`) into the dataset of the placeholder element *before* calling `renderGlimmer`.
2. **Double-Decoration Prevention**: Immediately swap the identifying class (e.g., from `.discourse-reach-and-rights` to `.discourse-reach-and-rights-rendered`) to prevent Discourse from re-decorating the same element before Glimmer has finished booting.
3. **Fallback in `didInsert`**: In the Glimmer component, use the `element` parameter of the `didInsert` modifier to read from the dataset if `this.args` is empty.

### SVG Icons
Icons used in GJS templates (via `dIcon` helper) must be explicitly registered in `plugin.rb` using `register_svg_icon`, otherwise they will not be included in the client-side SVG subset.

### Important: Decorator vs. Glimmer Component Life-cycle
1. **Method Binding**: In `.gjs` components, ensure all methods called from the template (like `getTotalCount`) use the `@action` decorator to maintain `this` context, especially when used inside nested loops or conditionals.
2. **Defensive Programming**: Components rendered via BBCode might be initialized multiple times or before data is ready. Always use optional chaining (`this.data?.property`) in helper methods used by the template.
