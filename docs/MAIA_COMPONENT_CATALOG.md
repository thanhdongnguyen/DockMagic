# Maia native component catalog

Baseline: `bbVKHJo / base-maia`, 63 registry UI components. Source archive and
checksums remain immutable under `research/shadcn-bbVKHJo-2026-09-17`. This is the
active native mapping, superseding archived recommendations.

| Registry component | Native coverage / decision |
| --- | --- |
| `accordion` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `alert` | DSStatusCard; icon + text + semantic role |
| `alert-dialog` | dsAlert + DSDialogButton; default/cancel/destructive actions |
| `aspect-ratio` | Native aspectRatio for media and production renderers |
| `avatar` | Brand/media identity containers; authored assets preserved |
| `badge` | DSStatusBadge, DSPlanBadge |
| `breadcrumb` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `button` | DSButtonStyle, DSIconButtonStyle |
| `button-group` | Shared buttons; DSSegmentedControl for single-choice groups |
| `calendar` | Calendar grid/editor compositions with native DatePicker |
| `card` | DSCard, DSSettingsSection |
| `carousel` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `chart` | DSChartFrame, DSChartLegend, DSChartTooltip; domain renderer |
| `checkbox` | DSCheckboxStyle |
| `collapsible` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `combobox` | DSSelect(searchable: true) |
| `command` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `context-menu` | System app/Dock menu native exception; app actions use DSMenu |
| `dialog` | dsDialog + DSAlertContent |
| `drawer` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `dropdown-menu` | DSMenu + DSMenuContent + DSMenuButton |
| `empty` | DSEmptyState |
| `field` | DSField |
| `form` | DSField + native editing + feature validation |
| `hover-card` | DockHoverChrome and window-scoped leases |
| `input` | DSInputStyle / DSTextInput / DSSecureInput |
| `input-group` | DSInputChrome around icon/editor/action group |
| `input-otp` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `item` | DSSettingsRow / DSActionRow / DSMetricInline |
| `label` | DSField label and accessibility linkage |
| `menubar` | Native macOS app menu exception |
| `navigation-menu` | Settings navigation rows; native NavigationSplitView |
| `pagination` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `popover` | dsPopover |
| `progress` | DSProgress, native spinner |
| `radio-group` | DSRadioGroup; DSSegmentedControl for compact single selection |
| `resizable` | Native window/split view behavior |
| `scroll-area` | Native ScrollView/NSScrollView; DashboardHistoryViewport |
| `select` | DSSelect |
| `separator` | DSDivider |
| `sheet` | dsDialog; system Share/file panels native |
| `sidebar` | Shared Settings navigation composition |
| `skeleton` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `slider` | DSSlider / DSNativeSlider; thumbless visual with native interaction |
| `sonner` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `spinner` | DSLoadingState and native ProgressView |
| `switch` | DSSwitchStyle; documented blue enabled track |
| `table` | Shared numeric rows and feature tables; no generic data-table demand |
| `tabs` | DSSegmentedControl and Settings navigation |
| `textarea` | DSTextArea |
| `toast` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `toggle` | Toggle + DSCheckboxStyle/DSSwitchStyle |
| `toggle-group` | DSSegmentedControl for single selection |
| `tooltip` | Native help for controls, DSChartTooltip for plots |
| `kbd` | DSTypography.keycap + semantic keycap geometry |
| `native-select` | System app menu native; app-owned DSSelect |
| `direction` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `attachment` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `bubble` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `message-scroller` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `questionnaire` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `marker` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |
| `message` | Deferred: no current DockMagic feature requires this primitive. Inspect the pinned source before future implementation. |

## Composition ownership

Foundation and primitives: `DockMagic/DesignSystem`. Dashboard shell, shared
usage cards/history viewport/plan badge/export actions: `Views/Shared`. `DSConnectionForm`, `DSRendererColorRow`, `DSDashboardHeader` and
`DSIdentityContainer` share feature composition. Feature code owns data,
capability, formatting and actions; supplied media/artwork stays content.

## Resource upgrades

Geist: official revision `10dc7658f13c38a474cde201bb09a4617267545b`, OFL-1.1.
HugeIcons Free Stroke Rounded: npm `@hugeicons/core-free-icons` 4.3.3, MIT.
`script/import_maia_icons.py` imports only the manifest subset from a checksum-
verified archive; it parses paths without executing package JavaScript. Normal
builds use bundled SVG/OTF resources and require no registry/network access.
Native `resources.json` records SHA256 for each font/icon/license and palette.
Compare new upstream sources, review tokens/geometry, regenerate selected assets,
update the manifest, and rerun QA before changing any pinned version.
