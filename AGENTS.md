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

## Resource-constrained verification policy

The development machine is an 8 GB M3 MacBook Air.

Local execution must prioritize system responsiveness and avoid sustained memory
pressure.

### During implementation

For each individual edit or small group of related edits:

1. Run only the smallest relevant focused test target.
2. Do not run both iOS 18 and iOS 26.
3. Do not run UI tests unless the change directly affects UI behavior.
4. Do not run a complete build when the focused test command already compiles
   the affected target.
5. Do not run independent commands concurrently.
6. Confirm the previous command and all child processes have exited before
   starting another command.

### Checkpoint verification

Run one broader unit/integration suite only after a coherent implementation
checkpoint is complete.

Use one platform for intermediate verification. Prefer the primary iOS 26
destination unless the change specifically concerns iOS 18 compatibility or
migration.

### Final slice verification only

Run the following only after implementation and focused reviews are complete:

1. Full iOS 18 unit/integration suite
2. Full iOS 26 unit/integration suite
3. Focused iOS 18 UI flow
4. Full iOS 26 UI suite
5. Migration and persistent-reopening gates
6. iOS 18 build
7. iOS 26 build
8. `git diff --check`

Run these serially. Never use parallel test workers, simulator clones,
concurrent destinations, or overlapping `xcodebuild` processes.

### Command configuration

For test commands:

- set parallel testing to disabled
- use a maximum of one parallel testing worker
- target one simulator destination
- do not boot additional simulators
- do not retry timed-out tests until surviving processes are inspected and
  terminated

### Resource-stop condition

Before starting a command, check for an existing `xcodebuild`, `xctest`, or
active simulator test runner.

If memory pressure is already elevated or swap is increasing:

- do not start another command
- terminate stale test/build processes
- shut down unused simulators
- report that verification was deferred due to local resource pressure

A full verification suite must not be repeated unless source code changed after
the previous successful run.
