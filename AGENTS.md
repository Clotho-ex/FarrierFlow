# FarrierFlow Agent Instructions

## Required Context

Before planning or implementing any task, read:

- `PRODUCT.md`
- `DESIGN.md`
- `ARCHITECTURE.md`
- `DATA_MODEL.md`
- `ROADMAP.md`

Identify the currently authorized roadmap slice and implement only that slice
unless the user explicitly authorizes a different scope. If these documents
contradict one another, stop and report the contradiction instead of silently
choosing an interpretation.

Deferred roadmap features must not receive placeholder screens, models,
directories, services, or abstractions.

## Platform

- Native SwiftUI application.
- Deployment target: iOS 18.0.
- Build against the latest stable iOS 26 SDK.
- Swift 6 with strict concurrency checking.
- iPhone only for the first release.
- Do not add third-party dependencies without explicit approval.

## Product

FarrierFlow is a local-first business application for independent farriers.

The core workflow will eventually be:

Appointment → horse history → completed work → hoof photographs → invoice → payment status → next appointment.

Optimize for speed, reliability, outdoor readability, and one-handed use.

## Native Interface

Prefer standard SwiftUI components:

- TabView
- NavigationStack
- List
- Form
- Section
- ToolbarItem
- Menu
- Picker
- DatePicker
- searchable
- swipeActions
- sheet
- alert
- confirmationDialog
- ContentUnavailableView

Do not create custom tab bars, navigation bars, back buttons, form controls, or manually simulated Liquid Glass.

Standard components should inherit the correct appearance automatically on iOS 18 and iOS 26.

Use iOS 26-only APIs only as optional enhancements behind availability checks.

## Design

The app should feel professional, durable, calm, native, and field-ready.

Avoid:

- Western or rustic themes
- Excessive horseshoe imagery
- Gradients
- Nested cards
- Glass content cards
- Oversized dashboard headings
- Decorative icon containers
- Generic SaaS dashboard styling
- Invented navigation patterns

Support:

- Light and Dark Mode
- Dynamic Type
- VoiceOver
- Reduce Motion
- Increased Contrast

## Architecture

Organize source code by feature.

Views should render state and send actions. Do not place persistence, financial calculations, notification logic, or file management directly inside SwiftUI view bodies.

Keep business rules in small, testable types.

Do not add speculative abstractions, unnecessary protocols, or dependency injection frameworks.

## Persistence

Use SwiftData as the local source of truth.

Model these relationships correctly:

- A client can own multiple horses.
- A client can have horses at multiple barns.
- A barn can contain horses owned by multiple clients.
- A horse has one client and one current barn.
- An appointment belongs to one barn and contains one or more horses.

Do not attach a barn directly to one client.

## Workflow

Before implementation:

1. Inspect the existing project.
2. State which files will change.
3. Implement one complete vertical slice.
4. Build the project.
5. Run relevant tests.
6. Verify persistence after relaunch.
7. Report the commands and results.

Do not modify unrelated files or silently expand the requested scope.

A task is not complete until the application builds and relevant tests pass.
