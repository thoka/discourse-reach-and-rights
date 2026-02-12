# Development Notes: Discourse Reach and Rights

This document summarizes technical insights, pitfalls, and useful information gathered during the development of this plugin.

## 1. CSS and Assets
*   **Asset Registration (Crucial):** Stylesheets located in `assets/stylesheets/` are **not** automatically loaded by Discourse. They must be explicitly registered in `plugin.rb` using `register_asset "stylesheets/file.scss"`. This was the primary reason styles didn't appear initially.
*   **Specificity & Scope:** Discourse uses high-specificity styles for `.cooked` content in posts. While asset registration is the first required step, you may still need specific selectors (e.g., `.cooked .my-container a`) to override default link styles or theme-specific overrides.
*   **Icons:** Every SVG icon used in the frontend via `iconHTML` must be registered in `plugin.rb` using `register_svg_icon "icon-name"`. 
    - Prefer solid icons (e.g., `eye`) over regular ones (`far-eye`) for better visibility in badge contexts.
    - Specific Discourse notification icons (e.g., `d-watching`, `d-tracking`, `d-watching-first`, `d-muted`) are pre-styled in many themes and should be preferred for notification context.

## 2. Localization (I18n)
*   **Automatic Groups:** Groups like `everyone`, `admins`, `moderators`, and `staff` are handled specially. Instead of technical slugs, use localized strings via Discourse translation keys (e.g., `groups.default_names.everyone`).
*   **Placeholders:** When using placeholders (e.g., `category_name: "%{category_name}"`), ensure `I18n.t()` is called correctly in Javascript. HTML within placeholders should be pre-formatted or handled carefully to avoid XSS.

## 3. Frontend Integration
*   **Decorators:** `api.decorateCookedElement` is the reliable way to manipulate BBCode or CSS classes in posts. It ensures logic runs when posts are lazy-loaded or viewed in the composer preview.
*   **Site Settings in JS:** Access site settings via `api.container.lookup("service:site-settings")`.
*   **Ajax Requests:** Use the `ajax` module (`discourse/lib/ajax`) to ensure CSRF tokens and paths are handled correctly.
*   **Tooltips:** Native `title` attributes on elements within `.cooked` may be affected by `pointer-events: none` on child icons. Use a wrapping container (like `.d-icon-container`) and ensure pointer events bubble correctly.

## 4. Backend & Permissions
*   **Guardian:** The `Guardian` class is central to permission checks. If you need to show data for categories a user cannot "see" (but could join), you must explicitly bypass or extend the logic in the controller (e.g., checking for `public_admission` of associated groups).
*   **CategoryGroup Map:** The `CategoryGroup` table links categories to groups using `permission_type` (1=Full, 2=Create/Reply, 3=Read Only).
*   **Sorting:** For better UX, permissions should be returned sorted by `permission_type` (highest access level first).

## 5. Notification Logic & Overrides
Discourse uses a multi-layered system for category notification levels:
*   **Group Defaults (`GroupCategoryNotificationDefault`):** These define the baseline for all members of a specific group in a specific category.
*   **User Overrides (`CategoryUser`):** These records store individual user choices. They **always** take precedence over group-based defaults.
*   **Precedence & Aggregation:** To calculate "real" notification numbers across the entire category ("Unique Reach"), we use a SQL Common Table Expression (CTE) approach:
    1.  **Access Population**: Identify everyone who can see the category (via group memberships or public access).
    2.  **Notification Inputs**: Gather all `CategoryUser` overrides and `GroupCategoryNotificationDefault` defaults for that population.
    3.  **Deduplication**: Use a weighted priority to select exactly one "winning" level per active user. **Note**: `Watching` (3) is prioritized over `Watching First Post` (4) because it represents a higher level of engagement (ALL posts vs. only the first).
    4.  **Count**: Group the resulting unique users by their winning level. This prevents inflated numbers for users in multiple groups.
*   **Levels:**
    *   `0`: Muted
    *   `1`: Regular (Normal)
    *   `2`: Tracking
    *   `3`: Watching
    *   `4`: Watching First Post
*   **Active Users Only**: All calculations (Unique Reach, Group counts, Bulk stats) explicitly exclude non-human users (system, bots) AND inactive/staged users. This is enforced via `active AND NOT staged` checks in SQL and `.activated.not_staged` in ActiveRecord scopes. This ensures that counts match active community size and exclude deleted or unactivated accounts.
*   **Deduplication**: In SQL queries, `COUNT(DISTINCT user_id)` is used to ensure users in multiple groups are only counted once for category-wide reach.

## 6. Reach Statistics (Background)
*   **Performance**: To avoid heavy computations, reach metrics are calculated in bulk.
*   **Mailing List Mode**: Users with `mailing_list_mode: true` are counted as "Watching" unless they have an explicit `muted` level for that category.
*   **Hierarchy**: "Watching First Post" totals always include all users from the "Watching" pool, as they technically receive the first post as well.
*   **Availability**: Stats are merged into the `categories` array in the `SiteSerializer` for global availability and injected into `BasicCategorySerializer` responses.
*   **Updates**: Managed via `Jobs::UpdateReachStats` (Scheduled) and synchronized via `MessageBus` for active clients.

## 7. Testing
*   **System Specs:** Follow the Discourse development patterns for system tests.
    *   **Sessions:** To test anonymous states, use `using_session` or ensure `sign_out` is handled properly before visiting pages.
    *   **Assertions:** For AJAX-heavy UI, use `expect(page).to have_css()` as it includes built-in waiting logic.
*   **Rake Tasks:** Rake tasks must be manually required in specs using `Rake.application.rake_require` because they are not auto-loaded in the test environment.

## 7. Common Pitfalls
*   **Server Restarts:** Changes to `plugin.rb` or any files in `config/` (like site settings or routes) **require** a full server restart to take effect.
*   **Caching:** If styles don't appear after registration, a hard refresh (`Ctrl + F5`) or clearing `tmp/` might be necessary to force the asset compiler.

## 8. Hidden Groups
*   **Visibility:** In line with Discourse's privacy model, groups are only shown by name if the current user has visibility rights (determined via `Guardian`).
*   **Obfuscation:** If a group is "secret" or not visible to the user:
    - Its name is replaced with a localized "hidden" placeholder.
    - Its ID and URL are nulled out to prevent inference or accidental discovery.
    - However, its rights (permissions) and notification levels are still transferred to allow an accurate, though anonymous, overview of access and reach.
*   **Frontend Handling:** The table view detects the absence of a URL/ID and renders the group name as static text instead of a link.
