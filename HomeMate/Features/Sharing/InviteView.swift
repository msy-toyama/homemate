//
//  InviteView.swift
//  HomeMate
//
//  ブランドされた招待画面。iCloud の生 URL を見せずに、
//  QR コードとアプリ独自の招待コードで世帯共有へ招く。
//  「LINEなどで送る」では招待コード入りのやさしい文面を共有できる。
//

import SwiftUI
import CoreData
import CloudKit
import os

private let inviteLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "invite")

struct InviteView: View {
    let home: Home

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    /// 招待できない事由（案内文の出し分けに使う）。
    private enum FailReason {
        case notSignedIn
        case transient
    }

    /// 共有（QR/URL）の準備状態。
    private enum ShareState {
        case loading
        case ready(url: URL, share: CKShare?, container: CKContainer)
        case failed(FailReason)
    }

    /// 招待コード（公開DB発行）の状態。QR とは独立して扱う。
    private enum CodeState {
        case generating
        case ready(String)
        case failed
    }

    @State private var shareState: ShareState = .loading
    @State private var codeState: CodeState = .generating
    @State private var showManage = false
    @State private var showShareSheet = false
    @State private var didCopyCode = false

    private let shareService = CloudShareService()
    private let codeService = InviteCodeService()

    var body: some View {
        NavigationStack {
            Group {
                switch shareState {
                case .loading:
                    loadingView
                case let .failed(reason):
                    failedView(reason: reason)
                case let .ready(url, share, container):
                    readyView(url: url, share: share, container: container)
                }
            }
            .background(HMColor.background)
            .navigationTitle("invite.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .task { await prepareShare() }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: HMSpacing.m) {
            ProgressView()
            Text("invite.preparing")
                .font(HMTypography.caption)
                .foregroundStyle(HMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(reason: FailReason) -> some View {
        VStack(spacing: HMSpacing.m) {
            Image(systemName: reason == .notSignedIn ? "icloud.slash" : "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(HMColor.secondaryText)
            Text(reason == .notSignedIn ? "invite.failed.account" : "invite.failed")
                .font(HMTypography.body)
                .multilineTextAlignment(.center)
            if reason != .notSignedIn {
                HMSecondaryButton(title: "common.retry", systemImage: "arrow.clockwise") {
                    shareState = .loading
                    _Concurrency.Task { await prepareShare() }
                }
            }
        }
        .padding(HMSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func readyView(url: URL, share: CKShare?, container: CKContainer) -> some View {
        ScrollView {
            VStack(spacing: HMSpacing.l) {
                header
                qrCard(url: url)
                codeCard(url: url)
                shareButton(url: url)
                if let share {
                    manageButton(share: share, container: container)
                }
                Text("invite.expiresNote")
                    .font(HMTypography.caption2)
                    .foregroundStyle(HMColor.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(HMSpacing.m)
        }
        .sheet(isPresented: $showManage) {
            if let share {
                CloudSharingController(share: share,
                                       container: container,
                                       title: CloudShareService.invitationTitle(for: home),
                                       onStopSharing: {
                                           home.isShared = false
                                           try? viewContext.save()
                                           dismiss()
                                       })
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems(url: url))
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: HMSpacing.s) {
            Image(systemName: "person.2.badge.plus.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(HMColor.accent)
            Text(LanguageManager.localized("invite.heading", home.displayName))
                .font(HMTypography.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("invite.subtitle")
                .font(HMTypography.body)
                .foregroundStyle(HMColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HMSpacing.s)
    }

    private func qrCard(url: URL) -> some View {
        HMCard {
            VStack(spacing: HMSpacing.s) {
                if let image = QRCode.image(from: url.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(HMSpacing.s)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 120))
                        .foregroundStyle(HMColor.tertiaryText)
                        .frame(width: 200, height: 200)
                }
                Text("invite.qr.hint")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func codeCard(url: URL) -> some View {
        HMCard(style: .tinted(HMColor.accent)) {
            VStack(spacing: HMSpacing.xs) {
                Text("invite.code.label")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)

                switch codeState {
                case .generating:
                    ProgressView()
                        .padding(.vertical, HMSpacing.s)
                case let .ready(code):
                    Text(InviteCodeService.format(code))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(HMColor.primaryText)
                        .textSelection(.enabled)
                    Button {
                        copyCode(code)
                    } label: {
                        Label(didCopyCode ? "invite.code.copied" : "invite.code.copy",
                              systemImage: didCopyCode ? "checkmark" : "doc.on.doc")
                            .font(HMTypography.caption.weight(.semibold))
                            .foregroundStyle(HMColor.accent)
                    }
                    .buttonStyle(.plain)
                    Text("invite.code.hint")
                        .font(HMTypography.caption2)
                        .foregroundStyle(HMColor.tertiaryText)
                        .multilineTextAlignment(.center)
                case .failed:
                    Text("invite.code.failed")
                        .font(HMTypography.caption2)
                        .foregroundStyle(HMColor.tertiaryText)
                        .multilineTextAlignment(.center)
                    HMSecondaryButton(title: "common.retry", systemImage: "arrow.clockwise") {
                        _Concurrency.Task { await generateCode(for: url) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func shareButton(url: URL) -> some View {
        HMPrimaryButton(title: "invite.share.button", systemImage: "square.and.arrow.up") {
            showShareSheet = true
        }
    }

    private func manageButton(share: CKShare, container: CKContainer) -> some View {
        HMSecondaryButton(title: "invite.manage", systemImage: "person.2.badge.gearshape") {
            showManage = true
        }
    }

    // MARK: - Actions

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = InviteCodeService.format(code)
        HMHaptics.impact(.light)
        withAnimation { didCopyCode = true }
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { didCopyCode = false }
        }
    }

    /// 共有シートに渡す項目。コードが発行済みならコード入り文面、
    /// 未発行でも QR 画像と汎用文面で送れるようにする。
    private func shareItems(url: URL) -> [Any] {
        var items: [Any] = []
        if case let .ready(code) = codeState {
            items.append(LanguageManager.localized("invite.share.message",
                                                   home.displayName,
                                                   InviteCodeService.format(code)))
        } else {
            items.append(LanguageManager.localized("invite.share.messageNoCode", home.displayName))
        }
        if let image = QRCode.image(from: url.absoluteString) {
            items.append(image)
        }
        return items
    }

    private func prepareShare() async {
        let account = await CloudAccountService().currentStatus()
        guard account.canShare else {
            shareState = .failed(account.isTransient ? .transient : .notSignedIn)
            return
        }
        do {
            let url = try await shareService.shareURL(for: home)
            let container = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)
            let share = shareService.existingShare(for: home)

            // 共有が確立したのでローカルの共有フラグを確定する。
            if !home.isShared {
                home.isShared = true
                try? viewContext.save()
            }

            shareState = .ready(url: url, share: share, container: container)
            await generateCode(for: url)
        } catch {
            inviteLogger.error("共有の準備に失敗: \(error.localizedDescription, privacy: .private)")
            shareState = .failed(.transient)
        }
    }

    /// 招待コードを発行（またはキャッシュから復元）する。共有準備とは独立。
    private func generateCode(for url: URL) async {
        codeState = .generating
        if let homeId = home.id, let cached = codeService.cachedValidCode(forHomeId: homeId) {
            codeState = .ready(cached)
            return
        }
        do {
            let code = try await codeService.create(shareURL: url, homeName: home.displayName)
            if let homeId = home.id {
                codeService.cacheCode(code, forHomeId: homeId)
            }
            codeState = .ready(code)
        } catch {
            inviteLogger.error("招待コードの発行に失敗: \(error.localizedDescription, privacy: .private)")
            codeState = .failed
        }
    }
}

// MARK: - UIActivityViewController ラッパー

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
