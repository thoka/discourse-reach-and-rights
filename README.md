# **Discourse Reach and Rights** Plugin

This plugin enables an infobox about configured permissions (who is allowed to create/respond/read) for categories.

## Features
- **Hierarchical Table (Default)**: A modern, minimalist display showing only the highest permission level per group using color-coded badges.
- **Classic Table (`classic`)**: A detailed matrix view showing See/Reply/Create status for each group.
- **Compact View (`short`)**: A streamlined display grouping groups by permission level with icons.
- **Join/Request Action Buttons**:
  - `user-plus` icon: Join groups that allow public admission.
  - `paper-plane` icon: Request membership for groups that allow it.
- **Configurable Colors**: Admin-defined colors for permission level badges (Create, Reply, See).
- **Interactive Links**: Group names link to group pages, and the category name in the title links to the category page.
- **Detailed Notification Tracking**: Displays specific subscription counts (Watching, Tracking, Muted) using official Discourse icons.
- **Aggregate Summary Row**: Shows total actual user subscriptions for the entire category at the bottom of the table.
- **Localization**: Full support for German and English, including localized automatic group names (e.g., "jeder", "Team").
- **Automatic Detection**: Using `[reach-and-rights]` without a category ID inside a topic automatically detects the category from the topic.

## BBCode

Primary tag: `[reach-and-rights]` (supports `category` and `view` attributes).
Alias (deprecated): `[show-permissions]` for backward compatibility.

Use:

```
[reach-and-rights]

[reach-and-rights category=123]
```

## Current Status

- API endpoint implemented for per-category permissions (logged-in + can see category).
- BBCode `[reach-and-rights]` emits a placeholder element and renders data from the endpoint.

## Usage

Example BBCode:
- `[reach-and-rights category=5]`
- `[reach-and-rights category=5 view="classic"]` (Detailed matrix view)
- `[reach-and-rights category=5 view="short"]` (Icon list by level)
- `[reach-and-rights category=5 class="custom-class"]`
- `[reach-and-rights]` (automatically detects the current category when used inside a topic)

Also works with `[show-permissions]` for existing posts.

## Configuration

You can set the default view for all `[reach-and-rights]` tags in the site settings:
- `discourse_reach_and_rights_default_view`: Choose between `table` (modern, default), `classic`, and `short`.
- `discourse_reach_and_rights_color_create`: Hex color for the "Create" badge.
- `discourse_reach_and_rights_color_reply`: Hex color for the "Reply" badge.
- `discourse_reach_and_rights_color_see`: Hex color for the "See" badge.
- `discourse_reach_and_rights_min_trust_level`: Minimum trust level required to see the tag (default: 0).

## Rake Tasks

### Append tag to all category descriptions

To automatically add the `[reach-and-rights]` tag to all existing category description topics (the "About the... category" topics), you can run:

```bash
rake discourse_reach_and_rights:append_to_categories
```

This task will scan all categories and append the tag to the first post of the category's definition topic if it's not already present.


## API

- **Endpoint:** `GET /c/:category_id/permissions`
- **Auth:** logged-in users only.
  - The user must meet the `discourse_reach_and_rights_min_trust_level`.
  - The user must be able to see the category **OR** there must be at least one group associated with the category that the user can join or request membership for.
  - If these conditions are not met, the tag will be automatically hidden in the frontend.
- **Response:**
  ```json
  {
    "category_id": 1,
    "category_name": "General",
    "group_permissions": [
      {
        "permission_type": 1,
        "permission": "full",
        "group_name": "admins",
        "group_display_name": "Admins",
        "group_id": 1,
        "can_join": false,
        "can_request": false,
        "is_member": false,
        "group_url": "/g/admins"
      }
    ]
  }
  ```

