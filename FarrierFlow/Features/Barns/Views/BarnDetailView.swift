import SwiftData
import SwiftUI

struct BarnDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model = BarnDetailModel()
    @State private var showsEditor = false
    @State private var showsHorseEditor = false
    @State private var showsExistingHorsePicker = false
    @State private var showsDeleteConfirmation = false

    let barnID: PersistentIdentifier

    var body: some View {
        Group {
            if let barn = model.barn {
                List {
                    Section {
                        VStack(
                            alignment: .leading,
                            spacing: SpacingTokens.tight
                        ) {
                            Text(barn.name)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            if let address = barn.address {
                                Text(address)
                                    .font(Typography.recordMetadata)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let contactNotes = barn.contactNotes {
                            LabeledContent("Contact Notes", value: contactNotes)
                        }
                    }
                    .listRowBackground(ColorTokens.surface)

                    Section {
                        if barn.horses.isEmpty {
                            Label(
                                "No horses yet",
                                systemImage: "figure.equestrian.sports"
                            )
                            .foregroundStyle(ColorTokens.textSecondary)
                        } else {
                            ForEach(
                                barn.horses.sorted {
                                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                },
                                id: \.id
                            ) { horse in
                                RecordNavigationLink(
                                    value: ClientRoute.horse(
                                        horse.id
                                    )
                                ) {
                                    HorseRow(
                                        horse: horse,
                                        context: .serviceLocationDetail
                                    )
                                }
                            }
                        }
                    } header: {
                        horsesSectionHeader
                            .textCase(nil)
                    }
                    .listRowBackground(ColorTokens.surface)
                }
                .listSectionSpacing(
                    .custom(SpacingTokens.recordSection)
                )
                .farrierFlowScrollBackground()
                .navigationTitle("Service Location")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if subscription.allowsMutations {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(
                                    "Add Existing Horse",
                                    systemImage: "arrow.right"
                                ) {
                                    showsExistingHorsePicker = true
                                }
                                Button("Edit", systemImage: "pencil") {
                                    showsEditor = true
                                }
                                .tint(ColorTokens.textSecondary)
                                Divider()
                                Button(
                                    "Delete",
                                    systemImage: "trash",
                                    role: .destructive
                                ) {
                                    showsDeleteConfirmation = true
                                }
                            } label: {
                                Label("Actions", systemImage: "ellipsis.circle")
                            }
                            .tint(ColorTokens.textSecondary)
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    BarnEditorDestination(barnID: barn.id)
                }
                .sheet(isPresented: $showsHorseEditor, onDismiss: reload) {
                    HorseEditorView(preselectedBarnID: barnID)
                }
                .sheet(isPresented: $showsExistingHorsePicker, onDismiss: reload) {
                    ExistingHorsePickerView(destinationBarnID: barnID)
                }
                .recordDeletionSheet(
                    .barn(barnID), isPresented: $showsDeleteConfirmation,
                    title: "Delete Service Location?", confirmationTitle: "Delete Service Location",
                    accessibilityPrefix: "barn-delete", alert: $model.alert
                ) { dismiss() }
            } else {
                ContentUnavailableView(
                    "Service Location Unavailable",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: barnID, in: ModelContext(context.container))
    }

    @ViewBuilder
    private var horsesSectionHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                Text("Horses")
                addHorseButton
            }
        } else {
            HStack(spacing: SpacingTokens.compact) {
                Text("Horses")
                Spacer(minLength: SpacingTokens.compact)
                addHorseButton
            }
        }
    }

    @ViewBuilder
    private var addHorseButton: some View {
        if subscription.allowsMutations {
            Button("Add Horse", systemImage: "plus") {
                showsHorseEditor = true
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: SpacingTokens.minimumTouchTarget)
        }
    }
}

private struct BarnEditorDestination: View {
    @Environment(\.modelContext) private var context

    let barnID: PersistentIdentifier

    var body: some View {
        if let record = try? context.existingModel(Barn.self, for: barnID) {
            BarnEditorView(barn: record)
        } else {
            ContentUnavailableView(
                "Service Location Unavailable",
                systemImage: "exclamationmark.circle"
            )
        }
    }
}
