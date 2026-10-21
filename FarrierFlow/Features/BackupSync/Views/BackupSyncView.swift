import AuthenticationServices
import SwiftData
import SwiftUI

private enum BackupSyncLayout {
    static let subtitleGap: CGFloat = 2
    static let rowGap: CGFloat = 8
    static let contentGap: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let sectionGap: CGFloat = 28
    static let cardRadius: CGFloat = 20
    static let symbolSide: CGFloat = 24
}

enum BackupSyncRoute: Hashable { case account }

struct BackupSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var body: some View {
        NavigationStack {
            BackupSyncView()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .navigationDestination(for: InvoiceHistoryRoute.self) { route in
                    switch route {
                    case .list: InvoiceHistoryView(container: context.container)
                    case .detail(let identity): InvoiceHistoryDetailView(identity: identity, container: context.container)
                    }
                }
        }
    }
}

struct BackupSyncView: View {
    @Environment(\.backupSync) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var confirmsSignOut = false
    @State private var confirmsInvoicingTakeover = false
    @State private var confirmsCloudDeletion = false
    @State private var authorizesCloudDeletion = false
    @State private var localHistoryCount = 0
    @State private var historyUnavailable = false
    @State private var showsHistory = false
    @State private var showsReview = false

    var body: some View {
        Form {
            if let model, let deletion = model.deletion, deletion.isFenced {
                deletionSection(model, deletion: deletion)
            } else if let model, model.accountState == .connected {
                protectionSection(model)
            } else {
                Section {
                    Text(BackupSyncCopy.benefits)
                        .accessibilityIdentifier("backup-sync-benefits")
                    if let model {
                        SignInWithAppleButton(.signIn) { request in
                            model.prepareAppleSignIn()?.configure(request)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let token = credential.identityToken else { model.nativeSignInFailed(); return }
                                Task { await model.completeAppleSignIn(identityToken: token) }
                            case .failure(let error):
                                if let appleError = error as? ASAuthorizationError, appleError.code == .canceled {
                                    model.cancelAppleSignIn()
                                } else { model.nativeSignInFailed() }
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(minHeight: 50)
                        .disabled(!model.isAvailable || model.isBusy)
                        .accessibilityIdentifier("backup-sync-sign-in")
                        if model.isBusy { ProgressView(BackupSyncCopy.signingIn) }
                        if let message = accountMessage(model.accountState) {
                            BackupStatusPill(title: message, tone: .warning)
                        }
                        if model.accountState == .signedOutWithUnconfirmedRevocation {
                            Button(BackupSyncCopy.signOut) { Task { await model.signOut() } }
                        }
                    }
                    Button {
                        Task { await model?.continueLocally(); dismiss() }
                    } label: {
                        rowActionLabel(BackupSyncCopy.continueLocally, symbol: "iphone")
                    }
                    .tint(ColorTokens.brandActionText)
                    .disabled(model?.isBusy == true)
                    .accessibilityIdentifier("backup-sync-continue-local")
                } header: {
                    zoneHeading(BackupSyncCopy.backupZone, identifier: "backup-sync-backup-heading")
                } footer: {
                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                        Text(BackupSyncCopy.optional)
                        Text(BackupSyncCopy.privacy)
                            .accessibilityIdentifier("backup-sync-privacy")
                        if model?.isAvailable != true { Text(BackupSyncCopy.unavailable) }
                    }
                }
            }

            if localHistoryCount > 0 || historyUnavailable {
                Section {
                    Group {
                        if #available(iOS 26, *) {
                            RecordNavigationLink(value: InvoiceHistoryRoute.list) { Text(InvoiceHistoryCopy.title) }
                        } else {
                            Button { showsHistory = true } label: { Text(InvoiceHistoryCopy.title) }
                        }
                    }
                        .accessibilityIdentifier("backup-sync-local-history")
                    if historyUnavailable {
                        BackupStatusPill(title: BackupSyncCopy.needsReview, tone: .warning)
                        Text(InvoiceHistoryCopy.failure)
                    } else {
                        LabeledContent {
                            BackupStatusPill(title: InvoiceHistoryCopy.notProtected, tone: .warning)
                        } label: {
                            Text(InvoiceHistoryCopy.localOnly)
                            Text(localHistoryCount, format: .number)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                } header: {
                    zoneHeading(BackupSyncCopy.attentionZone, identifier: "backup-sync-history-heading")
                }
            }
            if let model, model.accountState == .connected, model.deletion?.isFenced != true {
                accountSection(model)
                if model.deletionAvailable {
                    Section {
                        Button(role: .destructive) { confirmsCloudDeletion = true } label: {
                            rowActionLabel(BackupSyncCopy.deleteCloudAccount, symbol: "trash")
                        }
                        .tint(ColorTokens.destructive)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("backup-sync-delete")
                        .listRowBackground(ColorTokens.surface)
                    } header: {
                        zoneHeading(BackupSyncCopy.dangerZone, identifier: "backup-sync-danger-heading")
                    } footer: {
                        Text(BackupSyncCopy.deleteHint)
                            .accessibilityIdentifier("backup-sync-delete-hint")
                    }
                }
            }
            Section {
                VStack(spacing: 0) {
                    if let faqURL = URL(string: "https://farrierflow.vercel.app/support/#backup-sync") {
                        Link(destination: faqURL) {
                            helpLinkLabel(BackupSyncCopy.faq)
                        }
                        .accessibilityIdentifier("backup-sync-faq")
                    }
                    if URL(string: "https://farrierflow.vercel.app/support/#backup-sync") != nil,
                       URL(string: "https://farrierflow.vercel.app/privacy/") != nil {
                        Divider()
                            .padding(.horizontal, BackupSyncLayout.contentGap)
                    }
                    if let privacyURL = URL(string: "https://farrierflow.vercel.app/privacy/") {
                        Link(destination: privacyURL) {
                            helpLinkLabel("Privacy Policy")
                        }
                    }
                }
                .padding(.vertical, BackupSyncLayout.subtitleGap * 2)
                .background(
                    ColorTokens.surface,
                    in: RoundedRectangle(cornerRadius: BackupSyncLayout.cardRadius, style: .continuous)
                )
                .backupSyncCardRow()
            } header: {
                zoneHeading(BackupSyncCopy.helpZone, identifier: "backup-sync-help-heading")
            }
        }
        .listSectionSpacing(.custom(BackupSyncLayout.sectionGap))
        .farrierFlowScrollBackground()
        .navigationTitle(BackupSyncCopy.title)
        .sheet(isPresented: $showsHistory) {
            InvoiceHistorySheet(container: context.container).dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(isPresented: $showsReview) {
            SyncConflictReviewSheet(container: context.container).dynamicTypeSize(dynamicTypeSize)
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationDestination(for: SyncReviewRoute.self) { route in
            switch route {
            case .review: SyncConflictReviewView(container: context.container)
            case .invoiceRecovery: SyncInvoiceRecoveryView()
            }
        }
        .confirmationDialog(BackupSyncCopy.signOutQuestion, isPresented: $confirmsSignOut,
            titleVisibility: .visible) {
                Button(BackupSyncCopy.signOut, role: .destructive) { Task { await model?.signOut() } }
            } message: { Text(BackupSyncCopy.signOutExplanation) }
        .confirmationDialog(BackupSyncCopy.takeOverInvoicing, isPresented: $confirmsInvoicingTakeover,
            titleVisibility: .visible) {
                Button(BackupSyncCopy.takeOverInvoicing, role: .destructive) { model?.runtime?.requestInvoicingTakeover() }
            } message: { Text(BackupSyncCopy.takeOverConfirmation) }
        .confirmationDialog(BackupSyncCopy.deleteCloudQuestion, isPresented: $confirmsCloudDeletion,
            titleVisibility: .visible) {
                Button(BackupSyncCopy.deleteCloudAccount, role: .destructive) { authorizesCloudDeletion = true }
            } message: { Text(BackupSyncCopy.deletionConfirmation) }
        .sheet(isPresented: $authorizesCloudDeletion, onDismiss: {
            if model?.deletion?.state == .awaitingApple {
                Task { await model?.cancelCloudDeletion() }
            }
        }) {
            CloudDeletionAuthorizationSheet()
                .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
        .alert(item: Binding(get: { model?.alert }, set: { model?.alert = $0 })) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .task {
            refreshHistory()
            if let runtime = model?.runtime {
                do { try runtime.refreshStatus() }
                catch { model?.alert = FeatureAlert(title: BackupSyncCopy.statusFailureTitle, message: BackupSyncCopy.statusFailure) }
            }
        }
        .onChange(of: model?.runtime?.recordsVersion) { refreshHistory() }
    }

    private func refreshHistory() {
        do {
            localHistoryCount = try InvoiceHistoryArchiveReader(container: context.container).invoiceCount()
            historyUnavailable = false
        } catch { historyUnavailable = true }
    }

    private func zoneHeading(_ title: LocalizedStringResource, identifier: String) -> some View {
        Text(title)
            .accessibilityIdentifier(identifier)
    }

    private func actionLabel(_ title: LocalizedStringResource, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
            } else {
                Label { Text(title) } icon: { Image(systemName: symbol) }
            }
        }
        .lineLimit(nil)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private func rowActionLabel(_ title: LocalizedStringResource, symbol: String) -> some View {
        HStack(spacing: BackupSyncLayout.rowGap) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
            Text(title)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func helpLinkLabel(_ title: LocalizedStringResource) -> some View {
        HStack(spacing: BackupSyncLayout.rowGap) {
            Text(title)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: BackupSyncLayout.contentGap)
            Image(systemName: "arrow.up.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
        }
        .foregroundStyle(ColorTokens.brandActionText)
        .padding(.horizontal, BackupSyncLayout.contentGap)
        .padding(.vertical, BackupSyncLayout.rowGap)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func accountSection(_ model: BackupSyncModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: BackupSyncLayout.contentGap) {
                if let runtime = model.runtime, runtime.invoicingGeneration > 0 {
                    BackupDeviceRow(isThisIPhone: runtime.isInvoicingPhone)
                    if !runtime.isInvoicingPhone {
                        BackupSyncCardDivider()
                        Button { confirmsInvoicingTakeover = true } label: {
                            rowActionLabel(BackupSyncCopy.takeOverInvoicing, symbol: "iphone.gen3")
                        }
                        .tint(ColorTokens.brandActionText)
                        .disabled(!runtime.canTakeOverInvoicing || model.isBusy)
                        .accessibilityIdentifier("backup-sync-invoicing-takeover")
                    }
                }
                BackupSyncCardDivider()
                Button(role: .destructive) { confirmsSignOut = true } label: {
                    borderedActionLabel(
                        BackupSyncCopy.signOut,
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .farrierFlowBorderedAction(tint: ColorTokens.destructive)
                .disabled(model.isBusy)
                .accessibilityIdentifier("backup-sync-sign-out")
            }
            .backupSyncCard()
        } header: {
            zoneHeading(BackupSyncCopy.accountZone, identifier: "backup-sync-account-heading")
        } footer: {
            Text(BackupSyncCopy.signOutHint)
        }
    }

    private func deletionSection(_ model: BackupSyncModel, deletion: CloudDeletionController) -> some View {
        Section {
            BackupStatusPill(
                title: deletionMessage(deletion.state),
                tone: deletion.state == .complete ? .success : .warning,
                identifier: "backup-sync-deletion-state"
            )
            if deletion.state != .complete {
                Button { Task { await model.refreshCloudDeletion() } } label: {
                    actionLabel(BackupSyncCopy.checkDeletion, symbol: "arrow.clockwise")
                }
                    .farrierFlowPrimaryAction()
                    .controlSize(.large)
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("backup-sync-deletion-check")
            }
            if model.deletionAvailable, deletion.intent?.phase == .sent || deletion.intent?.phase == .prepared {
                Button { authorizesCloudDeletion = true } label: {
                    rowActionLabel(BackupSyncCopy.retryDeletion, symbol: "arrow.clockwise")
                }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("backup-sync-deletion-retry")
                if deletion.intent?.phase == .prepared {
                    Button { Task { await model.cancelCloudDeletion() } } label: {
                        rowActionLabel(BackupSyncCopy.cancelDeletion, symbol: "xmark")
                    }
                        .disabled(model.isBusy)
                }
            }
        } header: {
            zoneHeading(BackupSyncCopy.deleteCloudAccount, identifier: "backup-sync-deletion-heading")
        } footer: {
            Text(BackupSyncCopy.deletionLocalOnly)
        }
    }

    private func deletionMessage(_ state: CloudDeletionRunState) -> LocalizedStringResource {
        switch state {
        case .complete: BackupSyncCopy.deletionComplete
        case .pending: BackupSyncCopy.deletionPending
        case .submitting: BackupSyncCopy.deletionSubmitting
        case .awaitingApple: BackupSyncCopy.deletionAwaitingApple
        case .unconfirmed, .localOnly: BackupSyncCopy.deletionFailure
        }
    }

    private func protectionSection(_ model: BackupSyncModel) -> some View {
        Section {
            let state = model.runtime?.state ?? .pending
            VStack(alignment: .leading, spacing: BackupSyncLayout.contentGap) {
                BackupSummaryStatusRow(
                    title: statusMessage(state),
                    tone: statusTone(state),
                    systemImage: statusSystemImage(state),
                    lastSuccessfulSync: model.protectionStatus?.lastRecordSync,
                    locale: locale
                )
                .accessibilityIdentifier("backup-sync-status")
                BackupSyncCardDivider()
                if let status = model.protectionStatus {
                    VStack(alignment: .leading, spacing: BackupSyncLayout.contentGap) {
                        if status.conflictCount > 0 {
                            Group {
                                if #available(iOS 26, *) {
                                    NavigationLink(value: SyncReviewRoute.review) { Text(BackupSyncCopy.reviewTitle) }
                                } else {
                                    Button { showsReview = true } label: { Text(BackupSyncCopy.reviewTitle) }
                                }
                            }
                            .accessibilityIdentifier("backup-sync-review")
                        }
                        if status.pendingBillingHoldCount > 0 {
                            LabeledContent {
                                BackupStatusPill(title: BackupSyncCopy.needsReview, tone: .warning)
                            } label: {
                                Text(BackupSyncCopy.pendingBillingHold)
                                Text(status.pendingBillingHoldCount, format: .number)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                        VStack(spacing: BackupSyncLayout.rowGap) {
                            BackupProtectionProgressRow(
                                title: BackupSyncCopy.records,
                                completeValue: BackupSyncCopy.recordsBackedUp(status.protectedRecordCount, locale: locale),
                                systemImage: "doc.text",
                                protectedCount: status.protectedRecordCount,
                                totalCount: status.recordCount,
                                locale: locale
                            )
                            .accessibilityIdentifier("backup-sync-protection-progress")
                            BackupProtectionProgressRow(
                                title: BackupSyncCopy.photos,
                                completeValue: BackupSyncCopy.photosBackedUp(status.protectedPhotoCount, locale: locale),
                                systemImage: "photo.on.rectangle",
                                protectedCount: status.protectedPhotoCount,
                                totalCount: status.photoCount,
                                locale: locale
                            )
                        }
                    }
                }
                Button { Task { await model.retry() } } label: {
                    syncActionLabel(state)
                }
                .farrierFlowBorderedAction()
                .disabled(model.runtime?.state == .syncingRecords || model.runtime?.state == .syncingPhotos)
                .accessibilityIdentifier("backup-sync-retry")
            }
            .backupSyncCard()
        } header: {
            zoneHeading(BackupSyncCopy.backupZone, identifier: "backup-sync-backup-heading")
        } footer: {
            Text(BackupSyncCopy.protectionExplanation)
                .accessibilityIdentifier("backup-sync-protection-explanation")
        }
    }

    private func syncActionLabel(_ state: BackupSyncRunState) -> some View {
        borderedActionLabel(
            state == .failed ? BackupSyncCopy.tryAgain : BackupSyncCopy.syncNow,
            systemImage: "arrow.triangle.2.circlepath",
            isProgressing: state == .syncingRecords || state == .syncingPhotos
        )
    }

    private func borderedActionLabel(
        _ title: LocalizedStringResource,
        systemImage: String,
        isProgressing: Bool = false
    ) -> some View {
        HStack(spacing: BackupSyncLayout.rowGap) {
            if isProgressing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private func statusSystemImage(_ state: BackupSyncRunState) -> String {
        switch state {
        case .upToDate:
            "checkmark.icloud"
        case .syncingRecords, .syncingPhotos:
            "arrow.triangle.2.circlepath"
        default:
            statusTone(state).systemImage
        }
    }

    private func statusTone(_ state: BackupSyncRunState) -> StatusTone {
        switch state {
        case .upToDate:
            .success
        case .syncingRecords, .syncingPhotos, .pending:
            .active
        case .waitingForConnection, .localOnly:
            .neutral
        case .waitingForSavedChanges, .needsReview, .missingPhotos, .updateRequired:
            .warning
        case .failed:
            .destructive
        }
    }

    private func statusMessage(_ state: BackupSyncRunState) -> LocalizedStringResource {
        switch state {
        case .localOnly: BackupSyncCopy.localOnly
        case .pending: BackupSyncCopy.pending
        case .syncingRecords: BackupSyncCopy.syncingRecords
        case .syncingPhotos: BackupSyncCopy.syncingPhotos
        case .upToDate: localHistoryCount > 0 || historyUnavailable ? BackupSyncCopy.activeProtected : BackupSyncCopy.protected
        case .waitingForConnection: BackupSyncCopy.offline
        case .waitingForSavedChanges: BackupSyncCopy.saveDraft
        case .needsReview: BackupSyncCopy.needsReview
        case .missingPhotos: BackupSyncCopy.missingPhotos
        case .updateRequired: BackupSyncCopy.updateRequired
        case .failed: BackupSyncCopy.syncFailed
        }
    }

    private func accountMessage(_ state: CloudAccountSessionState) -> LocalizedStringResource? {
        switch state {
        case .waitingForConnection: BackupSyncCopy.offline
        case .needsMatchingAccount: BackupSyncCopy.matchingAccount
        case .failed: BackupSyncCopy.signInFailure
        case .signedOutWithUnconfirmedRevocation: BackupSyncCopy.unconfirmedSignOut
        case .localOnly, .working, .connected: nil
        }
    }
}

private struct BackupStatusPill: View {
    private static let minimumWidth: CGFloat = 112

    let title: LocalizedStringResource
    let tone: StatusTone
    let systemImage: String?
    var identifier: String?

    init(
        title: LocalizedStringResource,
        tone: StatusTone,
        systemImage: String? = nil,
        identifier: String? = nil
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.identifier = identifier
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.tight) {
            Image(systemName: systemImage ?? tone.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tone.emphasis)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
            if let identifier {
                Text(title)
                    .accessibilityIdentifier(identifier)
            } else {
                Text(title)
            }
        }
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(ColorTokens.textPrimary)
        .lineLimit(nil)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, SpacingTokens.compact)
        .padding(.vertical, SpacingTokens.tight)
        .frame(minWidth: Self.minimumWidth, minHeight: 28, alignment: .leading)
        .background(tone.background, in: Capsule())
        .overlay {
            Capsule()
                .stroke(tone.emphasis.opacity(0.45), lineWidth: 0.5)
        }
    }
}

private struct BackupSummaryStatusRow: View {
    let title: LocalizedStringResource
    let tone: StatusTone
    let systemImage: String
    let lastSuccessfulSync: Date?
    let locale: Locale

    var body: some View {
        HStack(alignment: .top, spacing: BackupSyncLayout.contentGap) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone.emphasis)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BackupSyncLayout.subtitleGap) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let lastSuccessfulSync {
                    Text(lastSyncMessage(lastSuccessfulSync))
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                } else {
                    Text(BackupSyncCopy.noSyncYet)
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func lastSyncMessage(_ date: Date) -> LocalizedStringResource {
        let calendar = Calendar.autoupdatingCurrent
        let time = date.formatted(.dateTime.locale(locale).hour().minute())
        if calendar.isDateInToday(date) {
            return BackupSyncCopy.lastSyncToday(time)
        }
        if calendar.isDateInYesterday(date) {
            return BackupSyncCopy.lastSyncYesterday(time)
        }
        let dateAndTime = date.formatted(
            .dateTime.locale(locale).month(.abbreviated).day().hour().minute()
        )
        return BackupSyncCopy.lastSyncDate(dateAndTime)
    }
}

private struct BackupDeviceRow: View {
    let isThisIPhone: Bool

    private var tone: StatusTone { isThisIPhone ? .success : .warning }

    var body: some View {
        HStack(spacing: BackupSyncLayout.contentGap) {
            Image(systemName: "iphone.gen3")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
            Text(isThisIPhone ? BackupSyncCopy.invoicingHere : BackupSyncCopy.invoicingElsewhere)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer(minLength: BackupSyncLayout.contentGap)
            Image(systemName: isThisIPhone ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tone.emphasis)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct BackupProtectionProgressRow: View {
    let title: LocalizedStringResource
    let completeValue: LocalizedStringResource
    let systemImage: String
    let protectedCount: Int
    let totalCount: Int
    let locale: Locale

    private var isComplete: Bool {
        totalCount == 0 || protectedCount >= totalCount
    }

    private var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(min(max(protectedCount, 0), totalCount)) / Double(totalCount)
    }

    private var tone: StatusTone {
        isComplete ? .success : .warning
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BackupSyncLayout.rowGap) {
                rowLabel
                Spacer(minLength: BackupSyncLayout.contentGap)
                protectionValue
            }
            VStack(alignment: .leading, spacing: BackupSyncLayout.rowGap) {
                rowLabel
                protectionValue
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rowLabel: some View {
        HStack(spacing: BackupSyncLayout.rowGap) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var protectionValue: some View {
        HStack(spacing: BackupSyncLayout.rowGap) {
            Text(
                isComplete
                    ? completeValue
                    : BackupSyncCopy.counts(protected: protectedCount, total: totalCount, locale: locale)
            )
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.trailing)
            if isComplete {
                Image(systemName: "checkmark.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(StatusTone.success.emphasis)
                    .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                    .accessibilityHidden(true)
            } else {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(tone.emphasis)
                    .frame(width: BackupSyncLayout.symbolSide, height: BackupSyncLayout.symbolSide)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct BackupSyncCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(ColorTokens.border)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

extension View {
    fileprivate func backupSyncCard() -> some View {
        padding(BackupSyncLayout.cardPadding)
            .background(
                ColorTokens.surface,
                in: RoundedRectangle(cornerRadius: BackupSyncLayout.cardRadius, style: .continuous)
            )
            .backupSyncCardRow()
    }

    fileprivate func backupSyncCardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct CloudDeletionAuthorizationSheet: View {
    @Environment(\.backupSync) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(BackupSyncCopy.deletionConfirmation)
                    Text(BackupSyncCopy.deletionRetention)
                        .accessibilityIdentifier("backup-sync-deletion-retention")
                }
                Section {
                    SignInWithAppleButton(.continue) { request in
                        model?.prepareCloudDeletion()?.configure(request)
                    } onCompletion: { result in
                        Task {
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let token = credential.identityToken, let code = credential.authorizationCode else {
                                    model?.cloudDeletionFailed(); dismiss(); return
                                }
                                await model?.completeCloudDeletion(identityToken: token, authorizationCode: code)
                            case .failure(let error):
                                if let error = error as? ASAuthorizationError, error.code == .canceled {
                                    await model?.cancelCloudDeletion()
                                } else { model?.cloudDeletionFailed() }
                            }
                            dismiss()
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(minHeight: 50)
                    .disabled(model?.isBusy != false)
                    .accessibilityIdentifier("backup-sync-deletion-apple")
                } footer: { Text(BackupSyncCopy.deletionAppleExplanation) }
            }
            .farrierFlowScrollBackground()
            .navigationTitle(BackupSyncCopy.deleteCloudAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { Task { await model?.cancelCloudDeletion(); dismiss() } }
                        .disabled(model?.isBusy == true)
                }
            }
        }
        .interactiveDismissDisabled(model?.isBusy == true)
    }
}

enum BackupSyncCopy {
    static let backupZone = LocalizedStringResource("backupSync.zone.backup", defaultValue: "Backup")
    static let accountZone = LocalizedStringResource("backupSync.zone.account", defaultValue: "Account & Devices")
    static let dangerZone = LocalizedStringResource("backupSync.zone.danger", defaultValue: "Danger Zone")
    static let helpZone = LocalizedStringResource("backupSync.zone.help", defaultValue: "Help")
    static let attentionZone = LocalizedStringResource("backupSync.zone.attention", defaultValue: "Needs Attention")
    static let signOutHint = LocalizedStringResource("backupSync.zone.signOutHint", defaultValue: "Signing out pauses backup on this iPhone.")
    static let deleteHint = LocalizedStringResource("backupSync.zone.deleteHint", defaultValue: "Deletes the cloud copy. Keeps records on this iPhone.")
    static let statusTitle = LocalizedStringResource("backupSync.statusTitle", defaultValue: "Status")
    static let noSyncYet = LocalizedStringResource("backupSync.noSyncYet", defaultValue: "No successful sync yet")
    static let faq = LocalizedStringResource("backupSync.faq", defaultValue: "Backup & Sync FAQ")
    static let syncFailed = LocalizedStringResource("backupSync.syncFailed", defaultValue: "Sync Failed")
    static let relatedChangesTitle = LocalizedStringResource("backupSync.review.relatedChanges.title", defaultValue: "Related Cloud Changes")
    static let relatedChangesExplanation = LocalizedStringResource("backupSync.review.relatedChanges.explanation", defaultValue: "These records change together with your choices.")
    static let invoiceRecoveryTitle = LocalizedStringResource("backupSync.recovery.title", defaultValue: "Review Invoice History")
    static let invoiceRecoveryExplanation = LocalizedStringResource("backupSync.recovery.explanation", defaultValue: "Keep these invoices on this iPhone to continue syncing.")
    static let invoiceRecoveryContinue = LocalizedStringResource("backupSync.recovery.continue", defaultValue: "Keep History & Continue")
    static let invoiceRecoveryConfirmation = LocalizedStringResource("backupSync.recovery.confirmation", defaultValue: "Original invoices stay on this iPhone only. Their numbers and payment details will not change. Export PDFs for a separate copy. Safe records can then sync.")
    static let invoiceRecoveryFailure = LocalizedStringResource("backupSync.recovery.failure", defaultValue: "Recovery could not be confirmed. Your original invoices and pending changes are kept. Save any open edits, reconnect and review again. Different currencies or incompatible histories cannot be merged.")
    static let loadingReview = LocalizedStringResource("backupSync.recovery.loading", defaultValue: "Loading cloud history…")
    static let keepLocalSettings = LocalizedStringResource("backupSync.recovery.keepLocalSettings", defaultValue: "Keep iPhone Settings")
    static let useCloudSettings = LocalizedStringResource("backupSync.recovery.useCloudSettings", defaultValue: "Use Cloud Settings")
    static let recoverySettings = LocalizedStringResource("backupSync.recovery.settings", defaultValue: "Business Settings")
    static let recoveryNumbering = LocalizedStringResource("backupSync.recovery.numbering", defaultValue: "Original invoice numbers and payments stay unchanged.")
    static let pendingBillingHold = LocalizedStringResource("backupSync.recovery.pendingHold", defaultValue: "Billing safeguard awaiting sync")
    static let activeProtected = LocalizedStringResource("backupSync.activeProtected", defaultValue: "Current data is backed up")
    static let updateRequired = LocalizedStringResource("backupSync.updateRequired", defaultValue: "Update App to Sync")
    static let deleteCloudAccount = LocalizedStringResource("backupSync.deletion.title", defaultValue: "Delete Cloud Account")
    static let deleteCloudQuestion = LocalizedStringResource("backupSync.deletion.question", defaultValue: "Permanently delete your cloud account?")
    static let deletionConfirmation = LocalizedStringResource("backupSync.deletion.confirmation", defaultValue: "This permanently removes your FarrierFlow cloud account, backed-up business records and cloud photos. Other iPhones lose access. This cannot be undone.")
    static let deletionRetention = LocalizedStringResource("backupSync.deletion.retention", defaultValue: "Records and photos already on this iPhone are kept. Deleting your cloud account does not cancel your App Store subscription.")
    static let deletionAppleExplanation = LocalizedStringResource("backupSync.deletion.apple", defaultValue: "Confirm with the same Apple account.")
    static let deletionLocalOnly = LocalizedStringResource("backupSync.deletion.localOnly", defaultValue: "Local records are kept. Backup is off.")
    static let deletionComplete = LocalizedStringResource("backupSync.deletion.complete", defaultValue: "Cloud account deletion is complete. Your records and photos on this iPhone have been kept.")
    static let deletionPending = LocalizedStringResource("backupSync.deletion.pending", defaultValue: "Your cloud account deletion is in progress. Sync has stopped. The server will retry unfinished cleanup.")
    static let deletionSubmitting = LocalizedStringResource("backupSync.deletion.submitting", defaultValue: "Requesting cloud account deletion…")
    static let deletionAwaitingApple = LocalizedStringResource("backupSync.deletion.awaitingApple", defaultValue: "Deletion has not been sent. Continue with Apple to confirm, or cancel to keep your cloud account.")
    static let checkDeletion = LocalizedStringResource("backupSync.deletion.check", defaultValue: "Check Deletion Progress")
    static let retryDeletion = LocalizedStringResource("backupSync.deletion.retry", defaultValue: "Retry with Apple")
    static let cancelDeletion = LocalizedStringResource("backupSync.deletion.cancel", defaultValue: "Cancel Deletion")
    static let deletionFailureTitle = LocalizedStringResource("backupSync.deletion.failure.title", defaultValue: "Cloud Deletion Not Confirmed")
    static let deletionFailure = LocalizedStringResource("backupSync.deletion.failure", defaultValue: "Your local records have not been removed. Check deletion progress before signing in or syncing again. A request that may have reached the server cannot be safely cancelled.")
    static let invoicingTitle = LocalizedStringResource("backupSync.invoicing.title", defaultValue: "Invoicing iPhone")
    static let invoicingHere = LocalizedStringResource("backupSync.invoicing.here", defaultValue: "This iPhone")
    static let invoicingElsewhere = LocalizedStringResource("backupSync.invoicing.elsewhere", defaultValue: "Another iPhone")
    static let invoicingExplanation = LocalizedStringResource("backupSync.invoicing.explanation", defaultValue: "Only one iPhone creates invoices, so offline invoice numbers do not collide. A replacement iPhone can take over while online.")
    static let takeOverInvoicing = LocalizedStringResource("backupSync.invoicing.takeOver", defaultValue: "Make This My Invoicing iPhone")
    static let takeOverConfirmation = LocalizedStringResource("backupSync.invoicing.confirmation", defaultValue: "This requires an internet connection. The other iPhone will stop creating invoices when it next syncs. Any invoices it issued while offline are kept for review, not silently renumbered.")
    static let continueLocally = LocalizedStringResource("backupSync.continueLocally", defaultValue: "Continue Without Signing In")
    static func counts(protected: Int, total: Int, locale: Locale) -> LocalizedStringResource {
        LocalizedStringResource("backupSync.counts", defaultValue: "\(protected.formatted(.number.locale(locale))) of \(total.formatted(.number.locale(locale)))")
    }
    static func recordsBackedUp(_ count: Int, locale: Locale) -> LocalizedStringResource {
        LocalizedStringResource(
            "backupSync.recordsBackedUp",
            defaultValue: "\(count.formatted(.number.locale(locale))) records backed up"
        )
    }
    static func photosBackedUp(_ count: Int, locale: Locale) -> LocalizedStringResource {
        LocalizedStringResource(
            "backupSync.photosBackedUp",
            defaultValue: "\(count.formatted(.number.locale(locale))) photos backed up"
        )
    }
    static func lastSyncToday(_ time: String) -> LocalizedStringResource {
        LocalizedStringResource("backupSync.lastSync.today", defaultValue: "Last sync today at \(time)")
    }
    static func lastSyncYesterday(_ time: String) -> LocalizedStringResource {
        LocalizedStringResource("backupSync.lastSync.yesterday", defaultValue: "Last sync yesterday at \(time)")
    }
    static func lastSyncDate(_ dateAndTime: String) -> LocalizedStringResource {
        LocalizedStringResource("backupSync.lastSync.date", defaultValue: "Last sync \(dateAndTime)")
    }
    static let reviewTitle = LocalizedStringResource("backupSync.review.title", defaultValue: "Review Changes")
    static let reviewExplanation = LocalizedStringResource("backupSync.review.explanation", defaultValue: "Choose the version to keep. Both versions are kept until you confirm.")
    static let reviewConfirmation = LocalizedStringResource("backupSync.review.confirmation", defaultValue: "Your choices replace the conflicting versions. Records with different IDs are not combined, and issued invoices are not renumbered.")
    static let relatedReview = LocalizedStringResource("backupSync.review.related", defaultValue: "These histories could not be combined safely. No records have been replaced. Overlapping business settings or issued invoice numbers need review before sync can continue.")
    static let reviewFailure = LocalizedStringResource("backupSync.review.failure", defaultValue: "The changes could not be applied safely. Save or cancel any open edit, then reload and review all related records. No choices have been applied.")
    static let noConflicts = LocalizedStringResource("backupSync.review.none", defaultValue: "There are no conflicting changes to review.")
    static let thisIPhone = LocalizedStringResource("backupSync.review.iPhone", defaultValue: "This iPhone")
    static let cloudVersion = LocalizedStringResource("backupSync.review.cloud", defaultValue: "Cloud")
    static let chooseVersion = LocalizedStringResource("backupSync.review.choose", defaultValue: "Choose a Version")
    static let keepVersion = LocalizedStringResource("backupSync.review.version", defaultValue: "Version to Keep")
    static let keepIPhone = LocalizedStringResource("backupSync.review.keepIPhone", defaultValue: "Keep This iPhone’s Version")
    static let useCloud = LocalizedStringResource("backupSync.review.useCloud", defaultValue: "Use the Cloud Version")
    static let applyChoices = LocalizedStringResource("backupSync.review.apply", defaultValue: "Apply Reviewed Choices")
    static let title = LocalizedStringResource("backupSync.title", defaultValue: "Backup & Sync")
    static let restoreBusiness = LocalizedStringResource("backupSync.restoreBusiness", defaultValue: "Restore My Business")
    static let benefitsTitle = LocalizedStringResource("backupSync.benefits.title", defaultValue: "Keep Your Business Safe")
    static let benefits = LocalizedStringResource("backupSync.benefits", defaultValue: "Back up your records and photos.")
    static let optional = LocalizedStringResource("backupSync.optional", defaultValue: "Optional. Free for every user.")
    static let privacyTitle = LocalizedStringResource("backupSync.privacy.title", defaultValue: "Your Business Stays Yours")
    static let privacy = LocalizedStringResource("backupSync.privacy", defaultValue: "Your business data is not sold or used for ads.")
    static let analytics = LocalizedStringResource("backupSync.analytics", defaultValue: "Anonymous app analytics and subscription processing are separate. Signing in does not send your business records to those services.")
    static let signingIn = LocalizedStringResource("backupSync.signingIn", defaultValue: "Signing in…")
    static let localOnly = LocalizedStringResource("backupSync.localOnly", defaultValue: "Backup Off")
    static let unavailable = LocalizedStringResource("backupSync.unavailable", defaultValue: "Backup & Sync is not configured in this build. Your records remain on this iPhone.")
    static let protectionTitle = LocalizedStringResource("backupSync.protection.title", defaultValue: "Cloud Protection")
    static let records = LocalizedStringResource("backupSync.records", defaultValue: "Records")
    static let photos = LocalizedStringResource("backupSync.photos", defaultValue: "Photos")
    static let lastRecordSync = LocalizedStringResource("backupSync.lastRecordSync", defaultValue: "Last successful sync")
    static let protectionExplanation = LocalizedStringResource(
        "backupSync.protection.explanation",
        defaultValue: "Protects your clients, horses, appointments, invoices, and photos so they can be recovered on another iPhone."
    )
    static let syncNow = LocalizedStringResource("backupSync.syncNow", defaultValue: "Sync Now")
    static let tryAgain = LocalizedStringResource("backupSync.tryAgain", defaultValue: "Try Again")
    static let pending = LocalizedStringResource("backupSync.pending", defaultValue: "Waiting to Sync")
    static let syncingRecords = LocalizedStringResource("backupSync.syncingRecords", defaultValue: "Syncing Records…")
    static let syncingPhotos = LocalizedStringResource("backupSync.syncingPhotos", defaultValue: "Syncing Photos…")
    static let protected = LocalizedStringResource("backupSync.protected", defaultValue: "Everything is backed up")
    static let offline = LocalizedStringResource("backupSync.offline", defaultValue: "Offline")
    static let saveDraft = LocalizedStringResource("backupSync.saveDraft", defaultValue: "Save or Cancel Open Edit")
    static let needsReview = LocalizedStringResource("backupSync.needsReview", defaultValue: "Review Needed")
    static let missingPhotos = LocalizedStringResource("backupSync.missingPhotos", defaultValue: "Photos Missing")
    static let statusFailureTitle = LocalizedStringResource("backupSync.statusFailure.title", defaultValue: "Couldn’t Check Backup")
    static let statusFailure = LocalizedStringResource("backupSync.statusFailure", defaultValue: "Backup could not finish. Your local records have been kept. Try syncing again.")
    static let matchingAccount = LocalizedStringResource("backupSync.matchingAccount", defaultValue: "These records belong to a different Apple account. Sign in with the account used to back up this business.")
    static let signInFailure = LocalizedStringResource("backupSync.signInFailure.message", defaultValue: "Your records are still on this iPhone. Try signing in again when you have an internet connection.")
    static let signOut = LocalizedStringResource("backupSync.signOut", defaultValue: "Sign Out")
    static let signOutQuestion = LocalizedStringResource("backupSync.signOut.question", defaultValue: "Stop syncing this iPhone?")
    static let signOutExplanation = LocalizedStringResource("backupSync.signOut.explanation", defaultValue: "Signing out stops cloud backup and sync on this iPhone. Your local records and existing cloud backup are kept. Other iPhones stay signed in.")
    static let unconfirmedSignOut = LocalizedStringResource("backupSync.signOut.unconfirmed", defaultValue: "Sync has stopped, but sign-out could not be confirmed. Connect to the internet and retry signing out.")
}
