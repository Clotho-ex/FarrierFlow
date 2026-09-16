# FarrierFlow Local Screenshot Pipeline

## Status and boundary

This workflow is local-only preparation for the seven-frame v1.0.1 App Store
storyboard. It builds and launches the DEBUG app in an isolated simulator,
captures deterministic UI with AXe through `asc`, composes local marketing PNGs
with Koubou 0.18.1, and generates an offline review bundle.

It intentionally has no upload, apply, approval, metadata, submission, or
release command. Running it is not authorization to change App Store Connect.

## Deterministic fixture contract

- Reference instant: `2026-09-06T13:41:00Z` (9:41 AM in America/New_York).
- Status bar: 9:41, full cellular/Wi-Fi, charged battery at 100%.
- Locale: English (United States).
- Time zone: America/New_York.
- Fixture scenario: DEBUG-only `app-store-showcase`.
- Fixture stages: `active` for the Run Sheet and Visit editor; `completed` for
  Invoice 0148, Horse History, and next-appointment assistance.
- Every screenshot state uses its own isolated persistent store.
- Screenshot mode fails closed if an isolated store is not supplied.

The isolated launch path supplies `NoOpAnalyticsClient` and
`UITestSubscriptionClient`. It does not configure PostHog or RevenueCat, does
not collect attribution, and does not contact a subscription or analytics
service. The DEBUG unit-test app host uses the same isolated dependency path so
focused fixture tests do not initialize production telemetry providers.

## Local dependencies

The wrapper validates tools but never installs, removes, or downgrades them.

- Xcode 26 with an installed iOS 26 simulator runtime.
- `asc` 5.3.2.
- AXe 1.8.0.
- `jq`.
- Koubou 0.18.1 in an isolated environment.

The default Koubou convention is:

```bash
~/.local/share/farrierflow-tools/koubou-0.18.1/bin
```

Override it without changing the repository:

```bash
FARRIERFLOW_KOUBOU_BIN=/absolute/path/to/koubou-0.18.1/bin \
  scripts/local-screenshots.sh doctor
```

The wrapper prepends this directory only for `asc screenshots frame`. It does
not modify the shell's global `PATH`, and it never changes a global Koubou
installation.

## Commands

```bash
scripts/local-screenshots.sh doctor
scripts/local-screenshots.sh build
scripts/local-screenshots.sh capture
scripts/local-screenshots.sh capture 01-today-run-sheet
scripts/local-screenshots.sh compose
scripts/local-screenshots.sh compose 03-work-to-invoice
scripts/local-screenshots.sh review
scripts/local-screenshots.sh all
```

`capture`, `compose`, and `all` generate screenshots 1, 2, 3, 4, 6, and 7.
Screenshot 5 remains blocked until approved original synthetic hoof photographs
are supplied. Requesting screenshot 5 directly fails with an actionable error.
Screenshot 6 uses the real visit editor and currently shows the hoof-photo
affordances with a count of zero; it does not fabricate photo content while the
approved source-asset requirement remains unresolved.

Set `FARRIERFLOW_SCREENSHOT_UDID` to use a specific simulator. Without it, the
wrapper creates or reuses one simulator named `FarrierFlow Screenshots`. It
never erases or shuts down unrelated simulators. An override simulator that was
already booted remains booted; a simulator booted by the wrapper is shut down
when the command exits.

## Outputs

All generated artifacts are ignored by Git:

```text
output/screenshots/
├── DerivedData/
├── raw/
├── composed/
├── koubou/
└── review/
```

Each rerun replaces the owned output for its requested scope. It does not
accumulate timestamped or ambiguous alternatives.

## Approved creative anchors

The latest automated Slide 01 and Slide 03 proofs are
**APPROVED VISUAL REFERENCE — v1.0.1**:

```text
output/screenshots/creative-proof/new/01-today-run-sheet.png
output/screenshots/creative-proof/new/03-work-to-invoice.png
```

Their source-of-truth creative files are:

```text
.asc/screenshots/creative-proof.yml
.asc/screenshots/creative/01-today-run-sheet.html
.asc/screenshots/creative/03-work-to-invoice.html
.asc/screenshots/creative/field-book.css
```

Render and validate only these approved anchors with:

```bash
scripts/local-screenshots-creative-proof.sh doctor
scripts/local-screenshots-creative-proof.sh render
```

The creative renderer uses the existing global Koubou 0.20.0 installation for
HTML/CSS templates and the premium iPhone frame. The isolated Koubou 0.18.1
environment remains unchanged and is used only where `asc` 5.3.2 requires its
pinned renderer. Neither wrapper installs, removes, or downgrades tooling.

The Figma files `01-today-run-sheet.jpg` and `06-work-to-invoice.jpg` remain
historical comparison and quality-baseline references. The approved automated
proofs above are now the visual anchors for later work on Slides 02, 04, 05, 06,
and 07. Do not regenerate or redesign those remaining slides without explicit
authorization.

## Review and publication boundary

Open `output/screenshots/review/index.html` locally after `review` or `all`.
The review bundle is evidence for visual QA only. Uploading, approving, planning
remote changes, or applying screenshots requires a separate explicit release
authorization after the v1.0 review boundary permits it.
