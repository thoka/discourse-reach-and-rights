# Renaming Plan: From Permissions to Outreach (COMPLETED)

This document outlines the steps to pivot the plugin's identity to **Reach and Rights**, reflecting its focus on transparency and audience reach (Σ).

## Phase 1: Metadata & Ruby Namespace
- [x] **plugin.rb**: Update `name` to `discourse-reach-and-rights`.
- [x] **Ruby Classes**: Rename the base module `DiscourseReachAndRights`.
- [x] **File Paths**: Moved directories and files to match new naming.
- [x] **Site Settings**: Renamed to `discourse_reach_and_rights_*`.

## Phase 2: Frontend Integration
- [x] **Initializer**: Renamed to `discourse-reach-and-rights.js`.
- [x] **Components**: Renamed and classes updated to `reach-and-rights-*`.
- [x] **BBCode**: Added `[reach-and-rights]` and kept `[show-permissions]` for compatibility.

## Phase 3: Assets & Translations
- [x] **YAML**: Updated keys and improved descriptions.
- [x] **SCSS**: Renamed file and updated CSS classes.

## Phase 4: Migration
- [x] **Data Migration**: Created migration `20260210100000_rename_visible_permissions_to_reach_and_rights.rb`.
- [x] **Rake Task**: Updated namespace and BBCode detection.

## Status: Completed
Implementation finished on February 10, 2026. All request and service specs passing.