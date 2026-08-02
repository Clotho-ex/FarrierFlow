---
version: 1
slug: "farrierflow-app-rootview-swift"
primary_target: "FarrierFlow/App/RootView.swift"
related_targets: ["FarrierFlow/Features/Today/Views/TodayView.swift"]
---

# Root and Today Run Sheet Surface

- Scope: first-run owner setup, `RootView`, and Today. Mode: Operate.
- Audience: independent U.S. farrier working outdoors, standing, often one-handed.
- Job: record reusable owner setup once, then identify and complete the next valid step in the connected service cycle.
- Primary action: one deterministic Next action backed by current persisted records.
- Content proof: BusinessProfile identity, setup readiness, current-day Appointments, Visit state, uninvoiced Client-owned WorkItems, and Invoice status. No synthetic production data.
- Chosen direction: Field Book world with approved Run Sheet 1+3 composition. Native iOS surfaces use ruled alignment, compact operational annotation, restrained Survey Ink, and flat tonal hierarchy.
- First viewport: business identity and localized date, then one edge-to-edge action field. Scheduled state shows Next Stop and Open Appointment; active state replaces it with real Horse progress and Resume Visit. Remaining work continues below without duplicating the promoted record.
- Memorable moment: the same action field advances from Next Stop to active Visit through persisted work state; no dashboard switch, tile transition, or fabricated celebration.
- Constraints: iPhone only, iOS 18 baseline and iOS 26 primary, standard SwiftUI controls, Dynamic Type, VoiceOver, Increased Contrast, Reduce Motion, Dark Mode, one-handed reach, no custom navigation, no generic card dashboard, no western or rustic styling.
- Composition boundaries: generated images are structural north stars. Do not copy fixed heights, synthetic records, oversized type, or non-native chrome. Survey Ink field is reserved for a current-day Appointment or active Visit; setup, billing, and empty states remain flat native sections.
