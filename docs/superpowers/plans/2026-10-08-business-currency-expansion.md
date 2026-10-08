# Business Currency Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe persisted multi-currency business workflows for FarrierFlow's English-language farrier markets while preserving existing USD data.

**Architecture:** `BusinessProfile` owns one supported ISO currency in a new V2 SwiftData schema. Currency flows through the existing Service to WorkItem to Invoice and Payment snapshots; shared money parsing and formatting replace USD-only helpers. A native Business picker owns selection, and persistence rules lock it once monetary records exist.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XCTest UI tests, iOS 18 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-10-08-business-currency-expansion-design.md`

## Global Constraints

- Preserve existing user data and production store identity; V1 records migrate to USD with no conversion.
- Support only USD, TRY, GBP, EUR, CAD, AUD, NZD, and ZAR.
- Use native SwiftUI controls and existing feature boundaries; add no dependency or generalized Settings surface.
- Keep subscription price localization Apple/StoreKit-owned.
- Stop at ready-to-commit; do not commit, push, upload, submit, release, or mutate App Store Connect.

## Review Focus

- Existing V1 stores reopen with all relationships and USD semantics intact.
- Locale-specific decimal entry cannot silently change magnitude.
- Changing a locked currency cannot relabel existing money.
- Every financial snapshot remains in one supported business currency.
- PDF and export never display an unsupported currency as if valid.

---

### Task 1: Supported Currency Domain and Money Utilities

**Files:**
- Create: `FarrierFlow/Core/Money/BusinessCurrency.swift`
- Create: `FarrierFlow/Core/Money/MoneyInputParser.swift`
- Modify: `FarrierFlow/Core/Money/MoneyFormatter.swift`
- Delete: `FarrierFlow/Core/Money/USDPriceParser.swift`
- Test: `FarrierFlowTests/Core/Money/BusinessCurrencyTests.swift`
- Test: `FarrierFlowTests/Core/Money/MoneyInputParserTests.swift`
- Modify: `FarrierFlowTests/Core/Money/MoneyAvailabilityTests.swift`

**Interfaces:**
- Produces `BusinessCurrency`, `MoneyInputParser`, and `MoneyFormatter.currency(minorUnits:currencyCode:locale:)`.

- [ ] Write failing tests for the supported-code set, locale defaulting, localized formatting, localized decimal input, grouping, overflow, and unsupported currency.
- [ ] Run the focused money tests and verify the expected compile/assertion failures.
- [ ] Implement the minimal currency, parser, and formatter APIs.
- [ ] Run the focused money tests to green.

### Task 2: Persisted Business Currency and V1-to-V2 Migration

**Files:**
- Create: `FarrierFlow/Core/Persistence/Schema/FarrierFlowSchemaV2.swift`
- Create: `FarrierFlow/Core/Persistence/Migrations/FarrierFlowSchemaV1Models.swift`
- Create: `FarrierFlow/Core/Persistence/Migrations/FarrierFlowMigrationPlan.swift`
- Modify: `FarrierFlow/Core/Persistence/Schema/*.swift`
- Modify: `FarrierFlow/Core/Persistence/ModelContainerFactory.swift`
- Modify: `FarrierFlow/Features/BusinessProfile/*`
- Test: `FarrierFlowTests/Core/Persistence/ModelContainerFactoryTests.swift`
- Test: `FarrierFlowTests/Core/Persistence/PersistentStoreReopenTests.swift`
- Test: `FarrierFlowTests/Features/BusinessProfile/BusinessProfileRulesTests.swift`
- Test: `FarrierFlowTests/Features/BusinessProfile/BusinessProfileEditorModelTests.swift`

**Interfaces:**
- Consumes `BusinessCurrency`.
- Produces current V2 model aliases and `BusinessProfile.currencyCode`.

- [ ] Write failing tests for profile validation/defaulting, selection persistence, locking, and V1-store migration.
- [ ] Run focused tests and verify failures are caused by missing V2 currency behavior.
- [ ] Add V2 schema, lightweight migration, profile currency ownership, and native picker state.
- [ ] Run focused profile and migration tests to green.

### Task 3: Currency Propagation Through Services and Visits

**Files:**
- Modify: `FarrierFlow/Features/Services/*`
- Modify: `FarrierFlow/Features/Visits/*`
- Modify: `FarrierFlow/Features/Horses/*`
- Modify: `FarrierFlow/Core/Persistence/DomainGraphValidator.swift`
- Test: corresponding focused Service, Visit, and domain-validator tests.

**Interfaces:**
- Consumes the persisted business currency and shared money utilities.
- Produces same-currency Service and WorkItem graphs.

- [ ] Write failing tests for new Service currency, non-USD WorkItem editing, supported-currency graph validation, and mixed/unsupported rejection.
- [ ] Run focused tests and verify the expected failures.
- [ ] Replace USD-only creation, parsing, formatting, and validation with business-currency behavior.
- [ ] Run focused Service, Visit, and graph tests to green.

### Task 4: Invoices, Payments, PDFs, and Export

**Files:**
- Modify: `FarrierFlow/Features/Invoices/*`
- Modify: `FarrierFlow/Features/Export/*`
- Test: corresponding focused Invoice, PDF, Payment, and Export tests.

**Interfaces:**
- Consumes same-currency WorkItems and shared formatting.
- Produces supported-currency invoice/payment snapshots, PDFs, and CSV displays.

- [ ] Write failing GBP/EUR invoice, payment, PDF, and export behavior tests plus unsupported-currency rejection tests.
- [ ] Run focused tests and verify failures are caused by USD-only paths.
- [ ] Generalize invoice eligibility, generation, display, PDF, and export validation.
- [ ] Run focused Invoice and Export tests to green.

### Task 5: UI, Localization, Documentation, and Verification

**Files:**
- Modify: `FarrierFlow/Features/BusinessProfile/Views/BusinessProfileEditorView.swift`
- Modify: `FarrierFlow/Features/Services/Views/ServiceEditorView.swift`
- Modify: `FarrierFlow/Resources/Localizable.xcstrings`
- Modify: `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `ROADMAP.md`
- Modify/Test: focused Business setup and currency UI coverage.

- [ ] Add failing UI coverage for detected selection, owner override, locked currency, and localized price display.
- [ ] Implement native picker/read-only presentation and localized copy.
- [ ] Run focused UI coverage, migration/reopening gates, affected unit/integration tests, catalog validation, iOS 18/iOS 26 builds, and `git diff --check` serially.
- [ ] Audit the complete diff and manually verify setup, Service price, Invoice, PDF, relaunch, Dynamic Type, VoiceOver, Light, and Dark behavior.
- [ ] Update the unit ledger to `ready-to-commit` and stop without committing.
