# リリースチェックリスト / Release Checklist — ふたりボード (HomeMate) V1.0

## 1. 署名・識別子（Apple Developer 設定）
- [ ] Apple Developer Program 有効（有料アカウント）
- [ ] App ID: `com.yostfandy.HomeMate`（Capabilities: iCloud/CloudKit, App Groups, Push Notifications）
- [ ] Widget App ID: `com.yostfandy.HomeMate.HomeMateWidget`（Capabilities: App Groups）
- [ ] iCloud Container: `iCloud.com.yostfandy.HomeMate`（本番環境にスキーマをデプロイ）
- [ ] App Group: `group.com.yostfandy.HomeMate`（アプリ・Widget 両ターゲットに付与）
- [ ] Provisioning Profile（配布用）をアプリ・Widget の両方に用意
- [x] `aps-environment` を `production` に設定済み（entitlements 反映済み。Debug 実機検証時のみ必要に応じ `development` へ）

## 2. CloudKit
- [ ] Development スキーマを Production へデプロイ（CloudKit Dashboard）
- [ ] 共有（CKShare）の受け入れ動線を実機2台で確認
- [ ] サインインしていない iCloud アカウント時の案内表示を確認

## 3. ビルド設定
- [ ] `MARKETING_VERSION = 1.0`、`CURRENT_PROJECT_VERSION` をビルドごとに更新
- [ ] Release 構成で警告ゼロ（確認済み）
- [ ] Deployment Target iOS 17.0
- [ ] Widget が Embed Foundation Extensions に含まれている（確認済み）

## 4. 品質確認（実機）
- [ ] ダークモード表示
- [ ] Dynamic Type（特大文字）でレイアウト崩れがない
- [ ] VoiceOver で主要操作（完了・追加・共有）が辿れる
- [ ] 日本語／英語の言語切替で文言が正しい
- [ ] オンボーディングは最大4画面・2タブ構成を維持
- [ ] 買い物の連続追加が3秒以内のテンポで行える
- [ ] 「拒否／却下」の文言が存在しない（「今は難しい」を使用）
- [ ] メンタルロード表示に赤・順位づけがない
- [ ] 通知文言が責めない・急かさないトーン

## 5. App Store Connect
- [ ] スクリーンショット（6.7"／6.5"／5.5"／iPad 12.9"）日本語・英語
- [ ] アプリ名・サブタイトル・キーワード・説明文（docs/APP_STORE_METADATA.md）
- [ ] プライバシー「データの取り扱い」: データ収集なし（端末内ログのみ）を申告
- [ ] プライバシーポリシー URL（docs/PRIVACY.md をホスティング）
- [ ] サポート URL
- [ ] カテゴリ: Lifestyle / Productivity、年齢制限 4+
- [ ] 輸出コンプライアンス（標準的な暗号化のみ）

## 6. 最終
- [ ] Archive（実機/Generic iOS Device）→ Validate → App Store へアップロード
- [ ] TestFlight で内部テスト（共有・Widget・通知）
- [ ] 審査提出

## 既知の今後対応（V1 以降）
- アプリアイコンの最終デザイン差し替え（現在はプレースホルダ）
- Widget のディープリンク（タップで該当画面へ）
- App Intents による対話的ウィジェット
