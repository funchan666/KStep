import SwiftUI
import StoreKit

struct MembershipView: View {
    var rewardKind: AllowanceKind? = nil
    var exportRequired = false
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var benefitColumnWidth: CGFloat = 144
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var ads: RewardedAds
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedID: String?
    @State private var attemptedPurchaseAction = false
    @State private var purchaseTask: Task<Void, Never>?
    @State private var rewardTask: Task<Void, Never>?
    @State private var requestedReward = false
    @State private var acknowledgedLuckyReward = false
    private let contentWidth: CGFloat = 480

    private var plans: [SKProduct] {
        (commerce.policy?.products ?? []).compactMap { entry in
            commerce.products.first { $0.productIdentifier == entry.id }
        }
    }
    private var selectedPlan: SKProduct? {
        plans.first(where: { $0.productIdentifier == selectedID }) ?? plans.first
    }
    private var purchasing: Bool { commerce.preparingPurchase || commerce.busy || purchaseTask != nil }
    private var interactionLocked: Bool { purchasing || commerce.loadingPlans || ads.busy || ads.isPresenting }
    private var purchaseFeedback: String? {
        guard attemptedPurchaseAction else { return nil }
        return commerce.error ?? commerce.message
    }

    var body: some View {
        GeometryReader { viewport in
            let artworkHeight = min(max(viewport.size.height * 0.42, 176), 352)
            let pinsCheckout = viewport.size.height >= 560 && !typeSize.isAccessibilitySize
            ScrollViewReader { scroll in
                StageScrollView { topInset in
                    VStack(spacing: 24) {
                        membershipHeader(topInset: topInset, artworkHeight: artworkHeight)
                        membershipDetails(pinsCheckout: pinsCheckout)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if pinsCheckout, !commerce.premium, let plan = selectedPlan {
                        checkout(for: plan)
                            .frame(maxWidth: contentWidth)
                            .stageColumn()
                            .padding(.vertical, 10)
                            .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
                    }
                }
                .onChange(of: purchaseFeedback) { _, feedback in
                    guard feedback != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        scroll.scrollTo("membership.purchaseFeedback")
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            IconButton(symbol: .close, label: "Close") {
                cancelRewardRequest()
                dismiss()
            }
            .stageGlass(Circle(), interactive: true)
            .disabled(purchasing || ads.isPresenting)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .stageColumn().padding(.top, 8)
        }
        .kstepScreenBackground().foregroundStyle(.white)
        .task {
            async let rights: Void = commerce.refresh()
            await commerce.loadPlans()
            await rights
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in quota.resetIfNeeded() }
        .onDisappear {
            purchaseTask?.cancel(); purchaseTask = nil
            if !ads.isPresenting { cancelRewardRequest() }
        }
        .onChange(of: ads.completedReward) { _, completion in
            if requestedReward, completion != nil { dismiss() }
        }
        .interactiveDismissDisabled(purchasing || ads.isPresenting)
        .fullScreenCover(item: $ads.luckyReward, onDismiss: {
            if acknowledgedLuckyReward && requestedReward { dismiss() }
        }) { reward in
            LuckyRewardView(message: reward.message) {
                acknowledgedLuckyReward = true
                ads.luckyReward = nil
            }
                .presentationBackground(.clear)
        }
    }

    private func membershipHeader(topInset: CGFloat, artworkHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                LocalizedText("Rehearsal pass")
                    .font(.stage(.largeTitle, weight: .heavy, display: true))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if commerce.premium {
                    LocalizedText("Your membership is active")
                        .font(.stage(.subheadline, weight: .semibold))
                        .foregroundStyle(KStepStyle.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    if let expiration = commerce.expiration {
                        let date = expiration.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
                        LocalizedText("Access through %@.", date)
                            .font(.stage(.footnote))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if exportRequired {
                    LocalizedText("Export is included with Plus.")
                        .font(.stage(.subheadline, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            membershipBenefits
        }
        .foregroundStyle(KStepStyle.paper)
        .frame(maxWidth: contentWidth, alignment: .leading)
        .stageColumn()
        .padding(.top, topInset + artworkHeight * 0.60)
        .background(alignment: .top) {
            StagePhoto(artwork: "PlusArtwork").frame(height: topInset + artworkHeight)
        }
    }

    private func membershipDetails(pinsCheckout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if commerce.premium {
                renewalDisclosure
            } else {
                if api.session == nil { ConnectionPanel() }
                if !plans.isEmpty { planPicker }
                if plans.isEmpty, commerce.loadingPlans || commerce.loadingProducts || purchasing {
                    HStack(spacing: 10) {
                        loadingMark(width: 24)
                        LocalizedText(purchaseButtonTitle).font(.stage(.subheadline))
                    }
                }
                if let error = commerce.plansError {
                    ErrorNote(message: error)
                    Button("Retry") { Task { await commerce.loadPlans() } }
                        .buttonStyle(CompactActionStyle()).disabled(interactionLocked)
                }
                if !pinsCheckout, let plan = selectedPlan {
                    checkout(for: plan)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if purchaseFeedback != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let error = commerce.error { ErrorNote(message: error) }
                        if let message = commerce.message {
                            LocalizedText(message)
                                .font(.stage(.subheadline)).foregroundStyle(KStepStyle.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .id("membership.purchaseFeedback")
                }
                restoreLink
                PolicyLinks(compact: true)
            }

            if !exportRequired, !commerce.premium, api.session != nil { rewardOption }
        }
        .frame(maxWidth: contentWidth, alignment: .leading)
        .kstepPage(top: 0)
    }

    private var purchaseButtonTitle: String {
        if commerce.loadingProducts || commerce.loadingPlans { return "Checking with Apple…" }
        if commerce.preparingPurchase { return "Preparing your subscription…" }
        if commerce.busy { return "Confirming your purchase…" }
        return "Subscribe"
    }

    private var membershipBenefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText("Included with Plus")
                .font(.stage(.headline))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { benefitRows }
            } else {
                ViewThatFits(in: .horizontal) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                        GridItem(.flexible(), alignment: .topLeading)
                    ], alignment: .leading, spacing: 12) { benefitRows }
                        .frame(minWidth: benefitColumnWidth * 2 + 12)
                    VStack(alignment: .leading, spacing: 12) { benefitRows }
                }
            }
        }
        .foregroundStyle(KStepStyle.paper)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stageGlass(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var benefitRows: some View {
        benefit(.play, "Unlimited lesson views")
        benefit(.download, "Unlimited offline downloads")
        benefit(.home, "No ads on launch")
        benefit(.edit, "Export edited videos as MP4")
        benefit(.sound, "Export audio as M4A")
    }

    private func benefit(_ symbol: KStepGlyph, _ title: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Glyph(symbol: symbol, size: 18, tint: KStepStyle.accent)
            LocalizedText(title)
                .font(.stage(.footnote, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            LocalizedText("Choose a plan")
                .font(.stage(.title3, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)
            ForEach(plans, id: \.productIdentifier) { plan in
                planOption(plan)
            }
        }
    }

    private func planOption(_ product: SKProduct) -> some View {
        let selected = selectedPlan?.productIdentifier == product.productIdentifier
        let shape = RoundedRectangle(cornerRadius: 16)
        return Button { selectedID = product.productIdentifier } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    planName(product).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    planPrice(product, selected: selected, alignment: .trailing)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    planName(product)
                    planPrice(product, selected: selected, alignment: .leading)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .foregroundStyle(KStepStyle.paper)
            .background(selected ? KStepStyle.raised : KStepStyle.surface, in: shape)
            .overlay { shape.strokeBorder(selected ? KStepStyle.accent : KStepStyle.line).allowsHitTesting(false) }
            .contentShape(shape)
        }.buttonStyle(PressStyle()).disabled(interactionLocked)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("membership.plan.\(product.productIdentifier)")
    }

    private func planName(_ product: SKProduct) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: product.localizedTitle).font(.stage(.headline))
            billingPeriod(for: product)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func planPrice(_ product: SKProduct, selected: Bool, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(verbatim: commerce.price(product))
                .environment(\.layoutDirection, .leftToRight)
                .font(.stage(.title3, weight: .bold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            LocalizedText("Selected")
                .font(.stage(.caption2, weight: .semibold))
                .foregroundStyle(KStepStyle.accent)
                .opacity(selected ? 1 : 0)
                .accessibilityHidden(true)
        }
    }

    private func billingPeriod(for product: SKProduct) -> some View {
        let label: LocalizedText
        if let period = product.subscriptionPeriod, period.numberOfUnits == 1, period.unit == .month {
            label = LocalizedText("Billed monthly")
        } else if let period = product.subscriptionPeriod, period.numberOfUnits == 1, period.unit == .year {
            label = LocalizedText("Billed yearly")
        } else {
            label = LocalizedText("Billed every %@", commerce.period(product, locale: locale))
        }
        return label
            .font(.stage(.caption))
            .foregroundStyle(KStepStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func checkout(for product: SKProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    checkoutPrice(for: product).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    purchaseAction(planID: product.productIdentifier).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    checkoutPrice(for: product)
                    purchaseAction(planID: product.productIdentifier)
                }
            }
            renewalDisclosure
        }.foregroundStyle(KStepStyle.paper)
    }

    private func checkoutPrice(for product: SKProduct) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: commerce.price(product))
                .environment(\.layoutDirection, .leftToRight)
                .font(.stage(.headline, weight: .bold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            billingPeriod(for: product)
        }.accessibilityElement(children: .combine)
    }

    private var renewalDisclosure: some View {
        LocalizedText("Renews automatically. Cancel in your Apple account at least 24 hours before renewal.")
            .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func purchaseAction(planID: String) -> some View {
        Button { subscribe(planID: planID) } label: {
            HStack(spacing: 8) {
                if purchasing {
                    loadingMark(width: 22, tint: KStepStyle.ink)
                }
                LocalizedText(purchaseButtonTitle).font(.stage(.headline, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .frame(minWidth: 132, maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(KStepStyle.ink)
            .background(KStepStyle.accent, in: Capsule())
            .contentShape(Capsule())
        }.buttonStyle(PressStyle())
            .disabled(interactionLocked || selectedPlan == nil)
            .accessibilityIdentifier("membership.subscribe")
    }

    private func subscribe(planID: String) {
        guard !interactionLocked, selectedPlan?.productIdentifier == planID else { return }
        attemptedPurchaseAction = true
        purchaseTask = Task {
            await commerce.purchase(planID: planID)
            purchaseTask = nil
        }
    }

    private var rewardOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedText("Or, keep it free").font(.stage(.headline))
            ForEach(rewardKind.map { [$0] } ?? AllowanceKind.allCases) { kind in
                if quota.canRequestReward(for: kind, premium: commerce.premium) {
                    LocalizedText(quota.rewardSummary(for: kind)).font(.stage(.footnote)).foregroundStyle(KStepStyle.secondary)
                    if quota.completedAds(kind) >= 3 { AllowanceResetText() }
                    ActionButton(title: kind == .watch ? "Get more views" : "Get more downloads",
                                 primary: false, busy: ads.busy || ads.isPresenting) {
                        requestedReward = true
                        rewardTask = Task { await ads.watch(commerce: commerce, quota: quota, kind: kind) }
                    }.disabled(purchasing || ads.isPreparingAppOpen || ads.busy || ads.isPresenting)
                }
            }
            if ads.busy {
                HStack(spacing: 12) {
                    loadingMark(width: 28)
                    LocalizedText("Loading ad…").font(.stage(.footnote))
                    Spacer(minLength: 12)
                    Button("Cancel") { cancelRewardRequest() }
                        .buttonStyle(CompactActionStyle())
                }
            }
            LocalizedText(quota.unlimited ? "Unlimited views today" : "\(quota.watchesLeft) views left today")
            LocalizedText(quota.downloadsUnlimited ? "Unlimited downloads today" : "\(quota.downloadsLeft) downloads left today")
            AllowanceResetText()
            LocalizedText("Ad rewards unlock when the corresponding allowance runs out.")
                .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = ads.error { ErrorNote(message: error) }
            if let error = quota.error { ErrorNote(message: error) }
            if let message = ads.message {
                LocalizedText(message).font(.stage(.footnote)).foregroundStyle(KStepStyle.accent)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(KStepStyle.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func cancelRewardRequest() {
        rewardTask?.cancel()
        rewardTask = nil
        ads.cancelRewardLoading()
    }

    private func loadingMark(width: CGFloat, tint: Color = KStepStyle.accent) -> some View {
        Image("KStepLoadingMark").renderingMode(.template).resizable().scaledToFit()
            .foregroundStyle(tint)
            .frame(width: width, height: 14)
            .phaseAnimator([false, true]) { content, dimmed in
                content.opacity(reduceMotion || scenePhase != .active ? 1 : (dimmed ? 0.35 : 1))
            } animation: { _ in
                reduceMotion || scenePhase != .active ? nil : .easeInOut(duration: 0.6)
            }
            .accessibilityHidden(true)
    }

    private var restoreLink: some View {
        Button {
            attemptedPurchaseAction = true
            commerce.restore()
        } label: {
            LocalizedText("Restore purchases")
                .font(.stage(.footnote, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(KStepStyle.paper)
                .overlay { Capsule().strokeBorder(KStepStyle.secondary.opacity(0.55)).allowsHitTesting(false) }
                .contentShape(Capsule())
        }.disabled(interactionLocked).buttonStyle(PressStyle())
            .accessibilityIdentifier("membership.restore")
    }
}

struct AccountView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var ads: RewardedAds
    @EnvironmentObject private var accountAccess: AccountAccessFlow
    @State private var paywall = false
    private let contentWidth: CGFloat = 520

    private var unavailable: Bool {
        accountAccess.isBusy || commerce.busy || commerce.preparingPurchase || ads.busy || ads.isPresenting
    }

    var body: some View {
        GeometryReader { viewport in
            let artworkHeight = min(max(viewport.size.height * 0.42, 176), 320)
            StageScrollView { topInset in
                VStack(spacing: 18) {
                    profileHeader(topInset: topInset, artworkHeight: artworkHeight)
                    VStack(alignment: .leading, spacing: 24) {
                        if api.session != nil { membershipButton }
                        AccountSettingsSection()
                        LocalizedText("Version %@", api.configuration.version)
                            .font(.stage(.caption))
                            .foregroundStyle(KStepStyle.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: contentWidth, alignment: .leading)
                    .kstepPage(top: 0)
                }
            }
        }.kstepScreenBackground().foregroundStyle(KStepStyle.paper)
            .sheet(isPresented: $paywall) { MembershipView() }
    }

    private func profileHeader(topInset: CGFloat, artworkHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                LocalizedText("My studio")
                    .font(.stage(.largeTitle, display: true))
                    .accessibilityAddTraits(.isHeader)
                if let session = api.session {
                    LocalizedText("ID · %@", session.userId.value)
                        .font(.caption.monospaced())
                        .foregroundStyle(KStepStyle.paper.opacity(0.84))
                        .textSelection(.enabled)
                }
            }.fixedSize(horizontal: false, vertical: true)
            if api.session != nil { allowance }
            else { ConnectionPanel() }
        }
        .frame(maxWidth: contentWidth, alignment: .leading)
        .stageColumn()
        .padding(.top, topInset + artworkHeight * 0.50)
        .background(alignment: .top) {
            StagePhoto(artwork: "ProfileStudio", imageAlignment: .top)
                .frame(height: topInset + artworkHeight)
        }
    }

    private var membershipButton: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        return Button { paywall = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    LocalizedText(commerce.premium ? "Plus active" : "Free plan")
                        .font(.stage(.caption, weight: .semibold))
                        .foregroundStyle(KStepStyle.paperSecondary)
                    LocalizedText(commerce.premium ? "Manage membership" : "Explore Plus")
                        .font(.stage(.headline))
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Glyph(symbol: .back, size: 14, tint: KStepStyle.ink).rotationEffect(.degrees(180))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .foregroundStyle(KStepStyle.ink)
            .background(KStepStyle.paper, in: shape)
            .contentShape(shape)
        }.buttonStyle(PressStyle()).disabled(unavailable)
            .accessibilityIdentifier("account.membership")
    }

    private var allowance: some View {
        VStack(alignment: .leading, spacing: 12) {
            allowanceHeading

            if !commerce.premium, let error = quota.error {
                LocalizedText(error).font(.stage(.footnote))
                    .foregroundStyle(KStepStyle.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if commerce.premium || quota.usage != nil {
                if typeSize.isAccessibilitySize {
                    stackedBalances
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            balance(for: .watch)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            balance(for: .download)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        stackedBalances
                    }
                }
                if !commerce.premium {
                    Divider().overlay(KStepStyle.line)
                    AllowanceResetText()
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().tint(KStepStyle.accent).accessibilityHidden(true)
                    LocalizedText("Checking today’s allowance…")
                        .font(.stage(.footnote))
                        .foregroundStyle(KStepStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stageGlass(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var allowanceHeading: some View {
        let title = LocalizedText("Remaining today").font(.stage(.headline))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        if AllowanceKind.allCases.contains(where: { quota.canRequestReward(for: $0, premium: commerce.premium) }) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    title.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    rewardEntry.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title
                    rewardEntry
                }
            }
        } else {
            title
        }
    }

    private var rewardEntry: some View {
        Button { paywall = true } label: {
            LocalizedText("Get more").font(.stage(.footnote, weight: .semibold))
                .foregroundStyle(KStepStyle.accent)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle()).disabled(unavailable)
            .accessibilityLabel(LocalizedStringKey("Get more daily views and downloads"))
    }

    private var stackedBalances: some View {
        VStack(alignment: .leading, spacing: 14) {
            balance(for: .watch)
            balance(for: .download)
        }
    }

    private func balance(for kind: AllowanceKind) -> some View {
        let unlimited = commerce.premium || quota.isUnlimited(kind)
        let title = kind == .watch ? "Lesson views" : "Downloads"
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Glyph(symbol: kind == .watch ? .play : .download, size: 14, tint: KStepStyle.accent)
                LocalizedText(title)
                    .font(.stage(.footnote, weight: .medium))
                    .foregroundStyle(KStepStyle.paper)
            }
            if unlimited {
                LocalizedText("Unlimited").font(.stage(.title3, weight: .semibold))
            } else {
                Text(quota.remaining(kind), format: .number.locale(locale))
                    .font(.stage(.largeTitle, weight: .semibold)).monospacedDigit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

struct LuckyRewardView: View {
    let message: String
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    StageArtwork(kind: .pass, height: 108)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.88)
                        .accessibilityHidden(true)
                    LocalizedText("A little luck, on us").font(.stage(.headline)).foregroundStyle(.white)
                    LocalizedText("No ad is available right now. \(message)")
                        .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    ActionButton(title: "Keep exploring", action: dismiss)
                }.padding(20).frame(maxWidth: 360)
                    .background(KStepStyle.surface, in: RoundedRectangle(cornerRadius: 28))
                    .padding(24).frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }.background(Color.black.opacity(0.68).ignoresSafeArea())
            .accessibilityAddTraits(.isModal).interactiveDismissDisabled()
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { appeared = true } }
    }
}


struct AllowanceResetText: View {
    @Environment(\.locale) private var locale
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let next = QuotaStore.nextReset(after: context.date)
            LocalizedText("Resets %@ (local time)", localTime(next))
                .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private func localTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

}
