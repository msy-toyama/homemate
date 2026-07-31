//
//  JoinByCodeView.swift
//  HomeMate
//
//  受け取った招待コード（または QR）で世帯共有へ参加する画面。
//  コード → 公開DBで共有URLを解決 → CloudKit 共有を受け入れる。
//

import SwiftUI
import os

private let joinLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "join")

struct JoinByCodeView: View {
    /// ディープリンク等から渡された初期コード。あれば自動で参加を試みる。
    var initialCode: String? = nil

    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case input
        case joining
        case success
    }

    @State private var code: String = ""
    @State private var phase: Phase = .input
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var didAutoSubmit = false

    private let codeService = InviteCodeService()
    private let shareService = CloudShareService()

    private var normalizedCode: String { InviteCodeService.normalize(code) }
    private var canSubmit: Bool { normalizedCode.count == 8 && phase != .joining }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .input, .joining:
                    inputView
                case .success:
                    successView
                }
            }
            .background(HMColor.background)
            .navigationTitle("joinCode.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .onAppear {
            guard !didAutoSubmit, let initial = initialCode else { return }
            didAutoSubmit = true
            code = InviteCodeService.format(InviteCodeService.normalize(initial))
            if InviteCodeService.normalize(code).count == 8 {
                submit()
            }
        }
    }

    // MARK: - Input

    private var inputView: some View {
        ScrollView {
            VStack(spacing: HMSpacing.l) {
                VStack(spacing: HMSpacing.s) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(HMColor.accent)
                    Text("joinCode.hint")
                        .font(HMTypography.body)
                        .foregroundStyle(HMColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, HMSpacing.m)

                HMCard {
                    TextField("joinCode.placeholder", text: $code)
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { submit() }
                        .disabled(phase == .joining)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.alert)
                        .multilineTextAlignment(.center)
                }

                HMPrimaryButton(title: phase == .joining ? "joinCode.joining" : "joinCode.submit",
                                systemImage: "checkmark.circle.fill",
                                isEnabled: canSubmit) {
                    submit()
                }

                if QRScannerView.isSupported {
                    HMSecondaryButton(title: "joinCode.scan", systemImage: "qrcode.viewfinder") {
                        errorMessage = nil
                        showScanner = true
                    }
                    .disabled(phase == .joining)
                }
            }
            .padding(HMSpacing.m)
        }
    }

    private var successView: some View {
        VStack(spacing: HMSpacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(HMColor.success)
            Text("joinCode.success.title")
                .font(HMTypography.title)
                .fontWeight(.bold)
            Text("joinCode.success.message")
                .font(HMTypography.body)
                .foregroundStyle(HMColor.secondaryText)
                .multilineTextAlignment(.center)
            HMPrimaryButton(title: "common.done", systemImage: "checkmark") {
                dismiss()
            }
            .padding(.top, HMSpacing.s)
        }
        .padding(HMSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { value in
                showScanner = false
                handleScanned(value)
            }
            .ignoresSafeArea()
            .navigationTitle("joinCode.scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { showScanner = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleScanned(_ value: String) {
        // 1) iCloud 共有 URL はそのまま受け入れる。
        if let url = URL(string: value), url.scheme == "https", url.host?.contains("icloud") == true {
            _Concurrency.Task { await accept(url: url) }
            return
        }
        // 2) アプリのディープリンク / ユニバーサルリンク（.../join?code=XXXX）のコードを抽出。
        if let scanned = codeFromDeepLink(value) {
            code = InviteCodeService.format(InviteCodeService.normalize(scanned))
            submit()
            return
        }
        // 3) それ以外は生のコードとして扱う。
        code = InviteCodeService.format(InviteCodeService.normalize(value))
        submit()
    }

    /// `homemate://join?code=XXXX` や `https://.../join?code=XXXX` からコードを取り出す。
    private func codeFromDeepLink(_ value: String) -> String? {
        guard let comps = URLComponents(string: value) else { return nil }
        let isJoinPath = comps.host == "join" || comps.path.hasSuffix("/join") || comps.path == "join"
        guard isJoinPath else { return nil }
        return comps.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func submit() {
        guard canSubmit else {
            if normalizedCode.count != 8 {
                errorMessage = LanguageManager.localized("joinCode.error.invalid")
            }
            return
        }
        errorMessage = nil
        phase = .joining
        let usedCode = normalizedCode
        _Concurrency.Task {
            do {
                let invite = try await codeService.lookup(code: usedCode)
                await accept(url: invite.shareURL, usedCode: usedCode)
            } catch let error as InviteCodeError {
                present(error: message(for: error))
            } catch {
                joinLogger.error("コード照合に失敗: \(error.localizedDescription, privacy: .private)")
                present(error: LanguageManager.localized("joinCode.error.generic"))
            }
        }
    }

    private func accept(url: URL, usedCode: String? = nil) async {
        phase = .joining
        do {
            try await shareService.acceptShare(from: url)
            NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: nil)
            HMHaptics.success()
            phase = .success
            // 使い切りの招待コードは参加成功後に破棄する（ベストエフォート）。
            if let usedCode {
                _Concurrency.Task { try? await codeService.delete(code: usedCode) }
            }
        } catch {
            joinLogger.error("共有の受け入れに失敗: \(error.localizedDescription, privacy: .private)")
            present(error: LanguageManager.localized("joinCode.error.generic"))
        }
    }

    private func present(error: String) {
        phase = .input
        errorMessage = error
    }

    private func message(for error: InviteCodeError) -> String {
        switch error {
        case .invalidCode:
            return LanguageManager.localized("joinCode.error.invalid")
        case .notFound:
            return LanguageManager.localized("joinCode.error.notFound")
        case .expired:
            return LanguageManager.localized("joinCode.error.expired")
        }
    }
}
