# おうちボード / HomeMate

# iOS Version 1.0 最終設計書

目的：日本語圏・英語圏のiOSユーザーを対象に、通算10万ダウンロード以上を狙えるMVPを設計する（中長期は100万DLを志向）。
技術方針：iOS専用、SwiftUI、Core Data + CloudKit、CloudKit Sharing、WidgetKit。
日本語名：おうちボード（旧称：ふたりボード）
英語名：HomeMate
日本語版ポジション：夫婦・同棲・家族・ルームシェアの家事分担・買い物・頼みごと共有アプリ
英語版ポジション：Roommates / Housemates / Couples向けのShared Chores & Groceriesアプリ

# 0. ブランド名の決定（2026更新）

100万DLを志向するにあたり、TAMをカップルに限定する「ふたりボード」から、世帯全体（夫婦・家族・同棲・ルームシェア）を包含する「おうちボード」へ日本語ブランドを刷新する。英語ブランドは roommate / housemate 文脈と相性が良く検索面でも有利なため「HomeMate」を維持する。

商標上の注意：日本語名を「ホームメイト」と表記しない（賃貸住宅情報の登録商標と混同・抵触の恐れ）。英語「HomeMate」も提出各国でアプリ名の重複・商標を必ず事前確認すること。

アプリ内ブランド文言（オンボーディング／招待文／ウィジェット／レビュー導線）も、日本語は「おうちボード」に統一する（コード反映は別タスク）。

---

# 1. 最終結論

Version 1.0は、iOS専用アプリとしてCloudKitを採用する。

理由は、V1の目的がAndroid/Web展開ではなく、まずiPhoneユーザーに対して高品質なMVPを出し、App Store検索、Widget、共有体験、口コミ招待によって10万ダウンロードを狙うことだからである。

CloudKitは、以下の条件では適切である。

* iOS専用で始める
* Appleらしいプライバシー感を出したい
* 独自バックエンド運用を避けたい
* 個人開発で高品質なV1を出したい
* iCloud同期・共有を使いたい
* Widgetや通知などiOSネイティブ体験を重視したい

ただし、CloudKitには制約がある。

* 共有にはiCloudが必要
* Androidユーザーは参加できない
* 独自招待コードやWeb招待の自由度は低い
* 招待分析はSupabase/Firebaseより弱い
* 将来的なAndroid/Web展開時にはバックエンド移行を検討する必要がある

したがって、最終方針は以下とする。

Version 1.0：CloudKitでiOSに集中する。
Version 1.1〜1.5：Widget、通知、ASO、オンボーディングを改善する。
PMF確認後：Android/Web要望が強ければSupabase/Firebase等への移行を検討する。

---

# 2. プロダクトビジョン

おうちボード / HomeMateは、同棲カップル、夫婦、ルームメイト、ハウスメイトが、家事・買い物・頼みごと・生活タスクを1画面で共有管理できる生活管理アプリである。

このアプリは、単なるToDoアプリではない。
単なる買い物リストでもない。
単なる家事分担アプリでもない。

このアプリの本質は、以下である。

生活の中で発生する「誰がやるか分からないこと」「LINEやWhatsAppで流れてしまう頼みごと」「買い忘れ」「家事の偏り」「気づく人ばかりが疲れる問題」を、やさしく見える化して解決する。

---

# 3. 10万iOSダウンロードを狙うための基本戦略

10万ダウンロードを狙うために、V1では以下を徹底する。

1. App Store検索で見つかる名前にする。
2. スクリーンショット1枚目で価値が伝わるようにする。
3. 初回起動から60秒以内にボード作成を完了させる。
4. 初回起動から90秒以内に最初の家事・買い物を追加させる。
5. 初回利用中にパートナーまたはルームメイトを招待させる。
6. Widgetで毎日見る理由を作る。
7. メンタルロードは重く見せず、3日後以降にやさしく表示する。
8. 日本語版と英語版でASOと訴求を分ける。
9. 機能を増やさず、ホーム画面・追加体験・共有体験を磨く。
10. リリース後にProduct Page OptimizationとCustom Product Pagesで検証する。

10万ダウンロードは、アプリを出すだけでは達成できない。
V1で必要なのは、ダウンロード後に「これは相手と使いたい」と感じてもらい、共有によって利用者が増える構造を作ることである。

---

# 4. ターゲットユーザー

## 4.1 日本語版ターゲット

日本語版「おうちボード」は、以下を狙う。

第1ターゲット：同棲カップル
第2ターゲット：新婚夫婦
第3ターゲット：共働き夫婦
第4ターゲット：子どもなし夫婦
第5ターゲット：軽く家事を共有したい家族

V1では子育て専用機能は入れない。
理由は、子育て領域に入ると、保育園、学校、習い事、持ち物、予防接種など要件が広がりすぎるためである。

## 4.2 英語版ターゲット

英語版「HomeMate」は、以下を狙う。

第1ターゲット：Roommates
第2ターゲット：Housemates
第3ターゲット：Couples
第4ターゲット：Students living together
第5ターゲット：Small shared households

英語版では、couplesよりもroommates / housematesを強めに打ち出す。
理由は、英語圏では「shared chores」「roommate chores」「grocery list」「cleaning schedule」という検索意図があり、ASO上も狙いやすいからである。

---

# 5. V1.0のコア価値

V1.0では、以下の5つだけに集中する。

1. 今日やることが1画面で分かる。
2. 家事を共有できる。
3. 買い物リストを共有できる。
4. 頼みごとがチャットで流れない。
5. Widgetで毎日確認できる。

メンタルロード可視化は重要だが、V1では主役にしすぎない。
裏側で自動記録し、3日以上利用した後にホーム画面内の週次カードとしてやさしく表示する。

---

# 6. V1.0で実装する機能

V1.0で実装する機能は以下に限定する。

1. 初回オンボーディング
2. iCloud状態確認
3. 共有ボード作成
4. CloudKit同期
5. CloudKit Sharingによるメンバー招待
6. 1画面ホームボード
7. 家事タスク
8. 繰り返しタスク
9. 担当者設定
10. 簡易交代制
11. 共有買い物リスト
12. お願い・確認待ち
13. メンタルロード自動記録
14. 週次ふりかえりカード
15. ありがとうリアクション
16. ローカル通知
17. Small Widget
18. Medium Widget
19. 日本語・英語ローカライズ
20. 初期テンプレート
21. 分析イベント
22. App Store用ASO設計

---

# 7. V1.0で実装しない機能

以下はV1.0では実装しない。

| 機能                 | 理由                                 |
| ------------------ | ---------------------------------- |
| Large Widget       | Small / Mediumの品質を優先する             |
| Lock Screen Widget | V1.1で追加候補                          |
| 本格カレンダー            | TimeTreeやGoogle Calendarと競合する      |
| チャット               | LINE / WhatsApp / iMessageに勝つ必要がない |
| 家計簿                | アプリの軸がブレる                          |
| 割り勘                | 英語圏roommateには有効だがV1では重い            |
| 支払い管理              | V1.2以降で検討                          |
| 位置情報共有             | プライバシー懸念が強い                        |
| AI入力               | まず手動追加UXを磨く                        |
| OCR / レシート読取       | 開発負荷が高い                            |
| 写真管理               | V1のコア価値ではない                        |
| 詳細Insightsタブ       | 初期ユーザーには重い                         |
| Android版           | V1ではiOSに集中                         |
| Web版               | V1ではiOSに集中                         |

---

# 8. 技術方針

## 8.1 採用技術

| 項目       | 採用                             |
| -------- | ------------------------------ |
| UI       | SwiftUI                        |
| 対象OS     | iOS 17以降                       |
| ローカルDB   | Core Data                      |
| iCloud同期 | NSPersistentCloudKitContainer  |
| 共有       | CloudKit Sharing / CKShare     |
| Widget   | WidgetKit                      |
| Widget操作 | App Intents                    |
| 通知       | UserNotifications / ローカル通知     |
| 分析       | Firebase Analytics または PostHog |
| クラッシュ監視  | Firebase Crashlytics           |
| 多言語      | String Catalog                 |
| 課金       | V1では実装しない                      |
| 広告       | V1では実装しない                      |

## 8.2 Core Data + CloudKitを採用する理由

SwiftDataも候補になるが、V1ではCore Data + CloudKitを推奨する。

理由：

* CloudKit連携と共有の実績が豊富
* NSPersistentCloudKitContainerで同期・共有を設計しやすい
* 複雑なデータモデルに対応しやすい
* 既存情報が多く、開発者が迷いにくい
* Widget用キャッシュとの分離設計がしやすい

## 8.3 アカウント方針

V1では独自アカウントを作らない。

ユーザー認証はiCloud前提とする。
アプリ内でメールアドレス、パスワード、電話番号ログインを実装しない。

共有機能を使うにはiCloudが必要。
iCloud未ログインの場合は、1人用ローカルモードとして利用可能にする。

## 8.4 iCloud未ログイン時の仕様

iCloud未ログインでも、ローカルで1人用ボードを作成できる。
ただし、共有機能、複数端末同期は利用できない。

表示文言：

日本語：

共有とiCloud同期を使うにはiCloudが必要です。
設定アプリでiCloudにサインインすると、パートナーやルームメイトとボードを共有できます。
今は1人用モードで始められます。

英語：

iCloud is required for sharing and sync.
Sign in to iCloud in Settings to share your board with a partner or roommate.
You can start in solo mode for now.

---

# 9. データ設計

## 9.1 Core Dataエンティティ

V1では以下のエンティティを作成する。

1. Home
2. Member
3. Task
4. GroceryItem
5. MentalLoadEvent
6. ThanksReaction
7. TemplateItem
8. WidgetCache

---

## 9.2 Home

共有ボード単位。

フィールド：

* id: UUID
* name: String
* homeType: String
* locale: String
* ownerMemberId: UUID
* createdAt: Date
* updatedAt: Date
* archivedAt: Date?
* isShared: Bool
* cloudShareId: String?

homeType：

* couple
* spouse
* roommates
* family
* solo

日本語では「ボード」と表示する。
英語では「Home」と表示する。

---

## 9.3 Member

Homeに参加しているユーザー。

フィールド：

* id: UUID
* homeId: UUID
* displayName: String
* avatarSymbol: String
* colorToken: String
* role: String
* isCurrentUser: Bool
* joinedAt: Date
* updatedAt: Date
* archivedAt: Date?

role：

* owner
* member

---

## 9.4 Task

家事・お願い・リマインダーを表す。

フィールド：

* id: UUID
* homeId: UUID
* title: String
* notes: String?
* taskType: String
* status: String
* createdByMemberId: UUID
* assignedToMemberId: UUID?
* dueAt: Date?
* repeatFrequency: String?
* repeatWeekdays: String?
* rotationPolicy: String
* effortLevel: Int
* completedByMemberId: UUID?
* completedAt: Date?
* createdAt: Date
* updatedAt: Date
* archivedAt: Date?

taskType：

* chore
* request
* reminder

status：

* active
* completed
* archived
* paused

rotationPolicy：

* fixed
* alternate
* anyone

effortLevel：

* 1 = 軽い
* 2 = 普通
* 3 = 重い

---

## 9.5 GroceryItem

買い物リストのアイテム。

フィールド：

* id: UUID
* homeId: UUID
* name: String
* category: String?
* quantity: String?
* notes: String?
* status: String
* createdByMemberId: UUID
* completedByMemberId: UUID?
* completedAt: Date?
* createdAt: Date
* updatedAt: Date
* archivedAt: Date?

status：

* active
* completed
* archived

---

## 9.6 MentalLoadEvent

メンタルロード計測用イベント。

フィールド：

* id: UUID
* homeId: UUID
* targetType: String
* targetId: UUID
* actorMemberId: UUID
* eventType: String
* noticePoints: Int
* planPoints: Int
* doPoints: Int
* thanksPoints: Int
* createdAt: Date

targetType：

* task
* grocery
* request

eventType：

* notice
* plan
* do
* thanks

---

## 9.7 ThanksReaction

ありがとうリアクション。

フィールド：

* id: UUID
* homeId: UUID
* targetType: String
* targetId: UUID
* fromMemberId: UUID
* toMemberId: UUID
* reactionType: String
* createdAt: Date

reactionType：

* thanks
* helpful
* nice
* amazing

---

## 9.8 WidgetCache

Widget表示用の軽量キャッシュ。

フィールド：

* id: UUID
* homeId: UUID
* homeName: String
* nextTaskTitle: String?
* nextTaskDueAt: Date?
* nextTaskAssigneeName: String?
* todayTaskCount: Int
* groceryCount: Int
* requestCount: Int
* updatedAt: Date

WidgetはCore Data本体を直接複雑に読みに行かない。
アプリ側でWidgetCacheを更新し、WidgetはApp Group経由で軽量データを読む。

---

# 10. CloudKit共有設計

## 10.1 共有単位

共有単位はHomeとする。

Homeに紐づく以下を共有対象にする。

* Member
* Task
* GroceryItem
* MentalLoadEvent
* ThanksReaction

## 10.2 招待方法

V1ではCloudKit Sharing標準フローを使う。

招待導線：

1. ボード画面右上のメンバーアイコンをタップ
2. 「メンバーを招待」をタップ
3. iOS標準共有画面を表示
4. LINE、iMessage、メール、AirDrop等で共有
5. 受信者がリンクを開く
6. アプリがインストール済みなら参加
7. 未インストールならApp Storeへ誘導

## 10.3 招待タイミング

以下のタイミングで招待を促す。

* ボード作成直後
* 初回タスク作成後
* 買い物を3件追加した後
* お願いを作成しようとした時
* 設定画面のメンバー管理

## 10.4 招待文言

日本語：

おうちボードで家事と買い物を共有しよう。
このリンクから参加できます。

英語：

Let’s manage chores and groceries together on HomeMate.
Join this shared home board here.

## 10.5 参加上限

V1では1ボード最大6人までを想定する。

日本語版では2人利用を中心に見せる。
英語版ではroommates / housemates向けに3〜6人利用にも自然に対応する。

## 10.6 CloudKit採用時の注意

共有にはiCloudが必要。
そのため、App Store説明文やオンボーディングで「iCloudが必要」という事実を自然に伝える。

文言：

日本語：

共有機能にはiCloudが必要です。

英語：

iCloud is required to share a board.

ただし、初回の価値訴求では強く出しすぎない。
共有を使う直前に案内する。

---

# 11. ナビゲーション設計

## 11.1 タブ構成

V1ではタブは2つにする。

1. ボード / Board
2. リスト / Lists

設定は右上アイコンから開く。

## 11.2 2タブにする理由

V1ではユーザーに迷わせないことを最優先する。

4タブ、5タブ構成は高機能に見えるが、初回ユーザーには重い。
V1では、ホームボードに価値を集中させる。

---

# 12. オンボーディング設計

## 12.1 基本方針

オンボーディングは最大4画面。
長い説明は禁止。
初回起動から60秒以内にボード作成を完了できるようにする。

## 12.2 画面1：価値訴求

日本語：

タイトル：

ふたりの暮らしを、1画面で。

本文：

家事、買い物、頼みごとをまとめて共有。
LINEで流れてしまう生活タスクを、ふたりで見える化できます。

ボタン：

はじめる

英語：

Title:

Home life, shared in one board.

Body:

Manage chores, groceries, and requests with roommates, housemates, or your partner.

Button:

Get Started

---

## 12.3 画面2：誰と使うか

日本語：

* パートナー・配偶者
* ルームメイト
* 家族
* まずは自分だけ

英語：

* Partner / Spouse
* Roommates
* Family
* Just me

この選択によって、初期テンプレートと文言を切り替える。

---

## 12.4 画面3：ボード作成

入力項目：

* ボード名
* 自分の表示名

日本語プレースホルダー：

ボード名：

例：Masaya & Sayuri
例：ふたり暮らし
例：シェアハウス301

表示名：

例：Masaya

英語プレースホルダー：

Home name:

Example: Our Apartment
Example: Room 301
Example: Alex & Jamie

Display name:

Example: Alex

---

## 12.5 画面4：テンプレート選択

日本語：

おすすめの生活タスクを追加しますか？
あとから自由に編集できます。

ボタン：

おすすめを追加して始める
テンプレートなしで始める

英語：

Add starter home tasks?
You can edit them anytime.

Buttons:

Start with recommended tasks
Start from scratch

---

# 13. ホームボード画面設計

## 13.1 目的

アプリを開いた瞬間に、今日やることが分かる画面にする。

## 13.2 画面構成

上から以下の順に表示する。

1. ヘッダー
2. 今日のサマリーカード
3. 次にやることカード
4. 今日のタスクリスト
5. 買い物プレビュー
6. お願い・確認待ち
7. 今週のふりかえり
8. クイック追加ボタン

---

## 13.3 ヘッダー

表示項目：

* ボード名
* 今日の日付
* メンバーアイコン
* 設定ボタン

日本語例：

おうちボード
6月28日（日）

英語例：

HomeMate
Sun, Jun 28

---

## 13.4 今日のサマリーカード

表示項目：

* 家事件数
* 買い物件数
* お願い件数

日本語例：

今日の暮らし
家事 3件
買い物 5件
お願い 1件

英語例：

Today at Home
3 chores
5 groceries
1 request

---

## 13.5 次にやることカード

最も重要なタスクを1件だけ表示する。

優先順位：

1. 期限切れ
2. 今日が期限
3. 自分が担当
4. お願いされたタスク
5. 繰り返しタスク
6. 作成日時が新しいタスク

日本語例：

次にやること
燃えるゴミを出す
担当：Masaya
今日 8:00まで

英語例：

Next up
Take out trash
Assigned to Alex
Due 8:00 AM

ボタン：

* 完了
* 詳細

---

## 13.6 今日のタスクリスト

最大5件表示する。
6件以上ある場合は「すべて見る」を表示する。

カード表示項目：

* チェックボックス
* タスク名
* 担当者アイコン
* 期限
* 繰り返しアイコン

---

## 13.7 買い物プレビュー

最大5件表示する。

日本語例：

買い物
牛乳
卵
トイレットペーパー
洗剤
コーヒー

英語例：

Groceries
Milk
Eggs
Toilet paper
Detergent
Coffee

右上に「追加」ボタンを置く。

---

## 13.8 お願い・確認待ち

表示内容：

* 自分に来ているお願い
* 自分が相手に送ったお願い
* 未確認状態のお願い

状態：

日本語：

* 未確認
* 確認済み
* 完了
* 今は難しい

英語：

* Pending
* Accepted
* Done
* Not now

「拒否」という表現は禁止する。
相手を責める印象を避けるため、「今は難しい」を使う。

---

## 13.9 今週のふりかえり

初日には表示しない。

表示条件：

* 利用開始から3日以上
* または完了タスク3件以上
* かつMentalLoadEventが3件以上ある

日本語例：

今週のふりかえり
今週はSayuriさんが買い物に気づくことが多かったようです。
次回は買い物チェックを交代してみますか？

英語例：

Weekly check-in
Alex noticed more grocery items this week.
Want to rotate grocery check-ins next time?

数値は必要以上に前面に出さない。
比率は詳細表示でのみ確認できる。

---

# 14. リスト画面設計

## 14.1 構成

上部にセグメント切替を配置する。

日本語：

* 家事
* 買い物
* お願い

英語：

* Chores
* Groceries
* Requests

---

## 14.2 家事リスト

表示項目：

* タスク名
* 担当者
* 期限
* 繰り返し
* 完了ボタン

フィルター：

* すべて
* 今日
* 自分
* 未完了
* 完了済み

---

## 14.3 買い物リスト

買い物リストでは、追加速度を最優先する。

入力欄は画面上部に固定する。

プレースホルダー：

日本語：

買うものを追加

英語：

Add grocery or supply

操作：

1. 商品名を入力
2. 追加
3. 入力欄を空にする
4. キーボードは閉じない
5. 連続追加できる

カテゴリや数量は任意。
追加時に必須にしない。

---

## 14.4 お願いリスト

表示項目：

* お願い内容
* 依頼者
* 相手
* 期限
* 状態
* 完了ボタン

自分に来ているお願いを上に表示する。
自分が送ったお願いはその下に表示する。

---

# 15. クイック追加設計

## 15.1 目的

思いついた瞬間に3秒で追加できるようにする。

## 15.2 起動導線

全主要画面右下に「＋」ボタンを配置する。
タップするとボトムシートを表示する。

## 15.3 ボトムシート構成

上部：

入力欄

日本語：

何を追加しますか？

英語：

What do you want to add?

中央：

タイプ選択チップ

日本語：

家事
買い物
お願い

英語：

Chore
Grocery
Request

下部：

* 担当者
* 期限
* 追加ボタン

## 15.4 自動タイプ判定

現在画面に応じてデフォルトタイプを変える。

* ボード画面：家事
* 家事リスト：家事
* 買い物リスト：買い物
* お願いリスト：お願い

---

# 16. 家事機能設計

## 16.1 家事タスク項目

作成時に設定できる項目：

* タスク名
* 担当者
* 期限
* 繰り返し
* 交代制
* メモ
* 通知

## 16.2 V1の交代制

V1では以下のみ実装する。

1. 固定担当
2. 毎回交代
3. 誰でもOK

「ランダム」「週ごと交代」「未完了が少ない人」はV1.1以降。

## 16.3 完了時の処理

完了ボタンを押すと以下を行う。

1. Task.statusをcompletedにする。
2. completedByMemberIdを現在メンバーにする。
3. completedAtを記録する。
4. MentalLoadEventにdoを記録する。
5. 繰り返しタスクの場合、次回タスクを生成する。
6. 交代制の場合、次回担当者を切り替える。
7. WidgetCacheを更新する。
8. 相手にありがとうリアクション導線を表示する。

---

# 17. 買い物リスト設計

## 17.1 目的

買い忘れを防ぎ、週に何度も使う理由を作る。

## 17.2 アイテム項目

* 商品名
* カテゴリ
* 数量
* メモ
* 追加者
* 完了者
* 作成日時
* 完了日時

## 17.3 カテゴリ

日本語：

* 食品
* 日用品
* 掃除用品
* 飲み物
* その他

英語：

* Food
* Household
* Cleaning
* Drinks
* Other

## 17.4 操作

* 入力して追加
* チェックで完了
* 完了済みは下部に折りたたみ
* 完了済みから再追加できる
* 最近買ったものを表示する

## 17.5 UX基準

買い物追加は3秒以内。
カテゴリ選択は任意。
数量入力は任意。
連続追加を妨げない。

---

# 18. お願い機能設計

## 18.1 目的

LINE、WhatsApp、iMessageで流れる頼みごとを生活タスクとして管理する。

## 18.2 作成項目

* お願い内容
* 相手
* 期限
* メモ
* 通知

## 18.3 状態

日本語：

* 未確認
* 確認済み
* 完了
* 今は難しい

英語：

* Pending
* Accepted
* Done
* Not now

## 18.4 通知文言

日本語：

Masayaさんからお願いがあります
「帰りに牛乳を買ってきて」

英語：

Masaya sent you a request
“Please pick up milk on your way home.”

## 18.5 禁止表現

以下は禁止。

* 拒否
* 却下
* 無視
* 未対応です
* まだやっていません

代わりに以下を使う。

* 今は難しい
* あとで確認
* 確認済み
* 完了

---

# 19. メンタルロード設計

## 19.1 目的

見えない生活負担を、相手を責めずに可視化する。

## 19.2 計測する行動

### Notice

気づいて追加した行動。

例：

* 家事を追加した
* 買い物を追加した
* お願いを作成した

### Plan

計画した行動。

例：

* 期限を設定した
* 担当者を設定した
* 繰り返しを設定した
* 通知を設定した

### Do

実行した行動。

例：

* タスクを完了した
* 買い物を完了した
* お願いを完了した

### Thanks

感謝した行動。

例：

* ありがとうを送った

## 19.3 表示ルール

初日には表示しない。
利用3日以上、または完了タスク3件以上で表示する。
比率は強く見せない。
文章中心で表示する。

## 19.4 表示例

日本語：

今週は買い物に気づく回数が少し偏っていました。
次回は買い物チェックを交代してみますか？

英語：

Grocery check-ins were a little uneven this week.
Want to rotate them next time?

## 19.5 禁止UI

以下は禁止。

* 赤色で偏りを警告する
* 個人ランキングにする
* 勝ち負けにする
* サボりと表現する
* 「あなたは少ない」と表示する
* 通知で相手を責める
* 強制的に改善を迫る

## 19.6 推奨UI

以下を推奨する。

* ふたり全体の達成感
* 感謝の促進
* 交代の提案
* やさしい文章
* 柔らかい色
* 週次の軽い振り返り

---

# 20. ありがとうリアクション

## 20.1 目的

家事管理を責め合いではなく、感謝が生まれる体験にする。

## 20.2 表示タイミング

相手がタスクを完了したとき、カードにありがとうボタンを表示する。

## 20.3 種類

日本語：

* ありがとう
* 助かった
* ナイス
* 最高

英語：

* Thanks
* Helpful
* Nice
* Amazing

## 20.4 通知文言

日本語：

Sayuriさんが「ありがとう」を送りました。

英語：

Alex sent you “Thanks”.

---

# 21. Widget設計

## 21.1 V1で実装するWidget

V1では以下のみ実装する。

1. Small Widget
2. Medium Widget

Large Widget、Lock Screen WidgetはV1.1以降。

## 21.2 Small Widget

目的：

次にやることを1件だけ見せる。

表示内容：

* タスク名
* 期限
* 担当者

日本語例：

次にやること
燃えるゴミ
今日 8:00

英語例：

Next Task
Take out trash
Today 8:00

## 21.3 Medium Widget

目的：

今日の生活状況をまとめて見せる。

表示内容：

* 今日の家事件数
* 買い物件数
* お願い件数
* 次のタスク

日本語例：

今日のボード
家事 3
買い物 5
お願い 1
次：風呂掃除

英語例：

Today’s Board
3 chores
5 groceries
1 request
Next: Bathroom cleaning

## 21.4 Widget操作

V1では表示品質を最優先する。

可能であればApp Intentsで以下を実装する。

* タスク完了
* 買い物チェック

ただし、Widget操作が不安定になる場合は、タップでアプリ内の該当画面を開く仕様にする。

## 21.5 Widgetキャッシュ

Widgetは本体DBを複雑に読みに行かない。
アプリ側でWidgetCacheを更新し、App Group経由でWidgetに渡す。

更新タイミング：

* タスク作成
* タスク完了
* 買い物追加
* 買い物完了
* お願い作成
* アプリ起動
* バックグラウンド復帰

---

# 22. 通知設計

## 22.1 通知種類

V1では以下を実装する。

1. タスク期限通知
2. 繰り返しタスク通知
3. お願い受信通知
4. ありがとう通知

## 22.2 通知方針

通知は責めるために使わない。
生活を忘れないために使う。

## 22.3 良い通知例

日本語：

風呂掃除の時間です。
今日の担当：Masaya

英語：

Time for bathroom cleaning.
Assigned to Alex.

## 22.4 悪い通知例

日本語：

Masayaさんがまだ家事をしていません。

英語：

Alex still hasn’t done the chore.

このような表現は禁止する。

---

# 23. UI/UX原則

## 23.1 世界最高品質MVPの基準

1. 迷わない。
2. 入力が速い。
3. 情報が1画面で分かる。
4. 相手を責めない。
5. 生活が軽くなる。
6. 毎日見たくなる。
7. 空の状態でも次に何をすればいいか分かる。
8. 日本語も英語も自然。
9. 片手操作しやすい。
10. Widgetまで含めて体験を設計する。

## 23.2 デザイン方針

雰囲気：

* やさしい
* 清潔
* 軽い
* 生活感がある
* 温かい
* ミニマル
* 責めない

避ける雰囲気：

* 管理されている感じ
* 採点されている感じ
* 仕事のタスク管理のような硬さ
* ランキング感
* 赤い警告だらけのUI

## 23.3 カード設計

* 角丸16〜20pt
* 左右余白16pt
* カード内余白16pt
* タップ領域44pt以上
* 重要情報は上部
* アイコンだけで意味を伝えない
* チェックボックスは押しやすくする

## 23.4 色設計

背景：

システム背景色

カード：

二次背景色

アクセント：

やさしいブルー、グリーン、または暖色系

赤色：

期限切れ以外には使わない

メンタルロード：

偏りを赤で表現しない

## 23.5 文言設計

日本語では「タスク」より「やること」「家事」「お願い」を使う。
英語では「tasks」だけでなく「chores」「groceries」「requests」を使う。

禁止表現：

* サボり
* 失敗
* 未達
* あなたは少ない
* まだやっていない
* 悪いバランス

推奨表現：

* 少し偏っています
* 交代してみますか？
* いい感じです
* 助かりました
* 次はこれをやりましょう

---

# 24. 日本語版ASO（おうちボード）

## 24.1 アプリ名（30字以内）

おうちボード：家事分担・買い物リスト共有

代替（現ブランド維持時）：ふたりボード：家事分担・買い物リスト

## 24.2 サブタイトル（30字以内）

夫婦・同棲・家族のタスク共有アプリ

## 24.3 キーワードフィールド（100字以内・カンマ区切り・スペース無し）

カップル,ルームシェア,二人暮らし,同居,世帯,タスク,やること,ゴミ出し,家事管理,生活管理,リマインダー,予定,主婦,新婚,共働き,買い忘れ,当番,献立,スケジュール,ToDo

注：アプリ名・サブタイトルに含む語（家事分担・買い物リスト・夫婦・同棲・家族・共有 等）はキーワード欄で重複させない。

## 24.4 プロモーションテキスト（170字以内・審査不要で随時変更可）

「次に何をするか」「誰がやるか」をひと目に。家事・買い物・お願いを1画面で共有し、LINEで流れる頼みごとも忘れません。見えない家事の負担もやさしく可視化。ウィジェットで毎日の“やること”をホーム画面に。今すぐ無料で始められます。

## 24.5 スクリーンショット構成

1枚目：家事・買い物・お願いを“1画面”で
2枚目：ふたりでも家族でも、すぐ共有
3枚目：買い忘れを、もうしない
4枚目：LINEで流れる「お願い」も忘れない
5枚目：見えない家事を、やさしく可視化
6枚目：ホーム画面ウィジェットで毎日確認

## 24.6 説明文冒頭

おうちボードは、夫婦・同棲カップル・家族・ルームシェアのための「暮らしの共有ボード」です。
家事、買い物、お願いごと、リマインダーを1つの画面でまとめて管理できます。

LINEで流れてしまう生活タスクを、みんなで見える化。
誰がやったかだけでなく、誰が気づいたかもやさしく確認できます。

---

# 25. 英語版ASO（HomeMate）

## 25.1 App Name（30字以内）

HomeMate: Shared Chores List

## 25.2 Subtitle（30字以内）

Groceries & Roommate Tasks

## 25.3 Keywords（100字以内・カンマ区切り・スペース無し）

roommate,housemate,flatmate,grocery,list,couples,household,cleaning,schedule,todo,family,reminder,trash,duties,planner,checklist,partner,split,task,home

注：App Name・Subtitle に含む語（shared / chores / groceries / roommate / tasks）はKeywordsで重複させない。

## 25.4 Promotional Text（170字以内）

See who does what, together. Share chores, groceries, and requests in one board—nothing lost in chat. Gently surface the invisible work, and keep every task on your Home Screen widget. Free to start.

## 25.5 スクリーンショット構成

1: One board for chores, groceries & requests
2: Share with your partner or whole household
3: Never forget the groceries again
4: Requests that don’t get lost in chat
5: See the invisible work, gently
6: Daily tasks on your Home Screen

## 25.6 Description冒頭

HomeMate is the shared home board for couples, roommates, housemates, and families.
Share chores, groceries, requests, and reminders in one simple board—out of messy group chats.

Start in 60 seconds. Invite your partner or roommate with one tap. iCloud sync, no account needed.

---

# 26. グロース設計

## 26.1 成長構造

このアプリは広告だけで伸ばさない。

成長構造：

1. 1人がボードを作る。
2. パートナーまたはルームメイトを招待する。
3. 相手が参加する。
4. 家事・買い物・お願いが増える。
5. Widgetと通知で継続する。
6. App Storeレビューが増える。
7. ASOで検索流入が増える。

## 26.2 招待導線

招待導線は以下に配置する。

* ボード作成直後
* 初回タスク追加後
* 買い物3件追加後
* お願い作成時
* 設定画面

## 26.3 レビュー依頼

レビュー依頼は初回起動時に出さない。

表示条件：

* タスクを5件以上完了
* ありがとうを受け取った
* 7日以上継続
* Widget設定画面を開いた

文言：

日本語：

おうちボードが暮らしの役に立っていたら、レビューで応援していただけると嬉しいです。

英語：

If HomeMate is making home life easier, a quick review would mean a lot.

---

# 27. 分析イベント

## 27.1 必須イベント

* app_opened
* onboarding_started
* onboarding_completed
* icloud_status_checked
* home_created
* template_added
* task_created
* task_completed
* grocery_created
* grocery_completed
* request_created
* request_accepted
* request_completed
* share_sheet_opened
* member_invite_started
* thanks_sent
* widget_guide_opened
* widget_tapped
* weekly_reflection_viewed

## 27.2 送信してはいけない情報

分析イベントに以下を送信してはいけない。

* タスク名
* 買い物アイテム名
* お願い内容
* メモ
* 個人名
* メールアドレス
* iCloud ID

イベント名と件数のみ送信する。

---

# 28. プライバシー方針

## 28.1 基本方針

生活情報はプライベートな情報である。
データ収集は最小限にする。

## 28.2 App Store上で説明すべきこと

* iCloudを使って同期・共有すること
* 招待されたメンバーだけが共有ボードを見られること
* 分析ではタスク名や買い物内容を送信しないこと
* プライバシーポリシーをアプリ内とApp Store Connectに掲載すること

## 28.3 アプリ内プライバシー文言

日本語：

あなたの家事、買い物、お願いの内容は、共有ボードに参加しているメンバーだけが確認できます。
分析では、タスク名や買い物内容などの具体的な内容は送信しません。

英語：

Your chores, groceries, and requests are visible only to members of your shared board.
We do not send task titles, grocery names, or request details in analytics.

---

# 29. リリース基準

## 29.1 機能合格基準

以下をすべて満たすまでリリースしない。

* ボードを作成できる
* iCloud状態を判定できる
* iCloud未ログイン時に適切な案内が出る
* メンバー招待ができる
* 招待されたユーザーが参加できる
* 家事を作成できる
* 家事を完了できる
* 繰り返しタスクが動く
* 交代制が動く
* 買い物を連続追加できる
* 買い物を完了できる
* お願いを作成できる
* お願いの状態を変えられる
* MentalLoadEventが記録される
* 週次ふりかえりが表示される
* ありがとうを送れる
* Small Widgetが表示される
* Medium Widgetが表示される
* 通知が届く
* 日本語と英語が自然に表示される
* 分析イベントが記録される

## 29.2 品質合格基準

* クラッシュフリー率99.8%以上
* 初回ボード作成まで60秒以内
* 初回タスク作成まで90秒以内
* 買い物アイテム追加3秒以内
* タスク完了1タップ
* 招待開始2タップ以内
* 主要画面で文字切れなし
* Dynamic Type対応
* Dark Mode対応
* VoiceOverで主要操作可能
* オフライン時に致命的エラーが出ない
* 同期失敗時にデータが消えない
* Widget表示が崩れない

---

# 30. KPI

## 30.1 V1リリース後に見る指標

| KPI                   |      目標 |
| --------------------- | ------: |
| 初回ボード作成完了率            |   75%以上 |
| 初回タスク作成率              |   65%以上 |
| 初回招待開始率               |   25%以上 |
| D1継続率                 |   40%以上 |
| D7継続率                 |   25%以上 |
| D30継続率                |   12%以上 |
| Widget導線表示後のWidget追加率 |   15%以上 |
| 1週間のタスク完了数            |    5件以上 |
| App Store評価           |   4.6以上 |
| クラッシュフリー率             | 99.8%以上 |

## 30.2 最重要KPI

最重要KPIは以下の3つ。

1. 初回タスク作成率
2. 招待開始率
3. D7継続率

この3つが弱い場合、機能追加ではなく、オンボーディング、ホーム画面、クイック追加、招待導線を改善する。

---

# 31. 開発フェーズ

## Phase 1：基盤

* SwiftUIプロジェクト作成
* Core Dataモデル作成
* CloudKit Capability設定
* NSPersistentCloudKitContainer設定
* App Group設定
* Widget Extension作成
* String Catalog作成
* デザインコンポーネント作成

## Phase 2：オンボーディング

* 価値訴求画面
* 利用タイプ選択
* iCloud状態確認
* ボード作成
* テンプレート投入

## Phase 3：コア機能

* ホームボード
* 家事
* 買い物
* お願い
* クイック追加

## Phase 4：共有

* CloudKit Sharing実装
* メンバー招待
* 共有受信フロー
* iCloud未接続時の案内
* メンバー管理

## Phase 5：メンタルロード

* MentalLoadEvent記録
* 週次集計
* ふりかえりカード
* ありがとうリアクション

## Phase 6：Widget・通知

* WidgetCache
* Small Widget
* Medium Widget
* ローカル通知
* Widgetタップ導線

## Phase 7：品質・ASO

* 分析イベント
* クラッシュ監視
* アクセシビリティ確認
* 日本語App Store文言
* 英語App Store文言
* スクリーンショット
* プライバシーポリシー
* 審査提出

---

# 32. V1.1以降の候補

## V1.1

* Lock Screen Widget
* Large Widget
* Widget上での完了操作
* ゴミ出し特化テンプレート
* よく買うものの自動提案

## V1.2

* 支払い期限
* サブスク期限
* カレンダー連携の軽量版
* テンプレート拡充

## V1.5

* AI自然文入力
* 「明日の朝8時にゴミ出しを追加」対応
* 英語・日本語のAI補助

## V2.0

* Android / Web展開検討
* Supabase/Firebase等への移行検討
* 割り勘
* OCR / レシート
* 家族・子育て機能

---

# 33. 最終プロダクト定義

## 日本語版

アプリ名：

おうちボード：家事分担・買い物リスト共有

説明：

おうちボードは、夫婦・同棲カップル・家族・ルームシェアのための暮らしの共有アプリです。
家事、買い物、頼みごとを1画面で管理できます。
LINEで流れてしまう生活タスクを、みんなで見える化。
誰がやったかだけでなく、誰が気づいたかもやさしく確認できます。

## 英語版

App Name:

HomeMate: Shared Chores

Description:

HomeMate helps roommates, housemates, and couples manage home life together.
Share chores, groceries, requests, and reminders in one simple board.
Keep home tasks out of messy chats and make shared living easier.

---

# 34. 最終判断

Version 1.0は、CloudKit採用で問題ない。

理由は、今回の目的が「全世界の全スマホユーザー」ではなく、「日本語圏・英語圏のiOSユーザー」を対象に、まず10万ダウンロード以上を狙うことだからである。

CloudKitにより、独自バックエンドを持たずに、iOSらしい同期・共有・プライバシー感を実現できる。
その分、Android/Web展開や独自招待コードの自由度は下がるが、V1では許容する。

このアプリのV1で最も重要なのは、技術の大きさではない。

最初の1分で、ユーザーにこう思わせること。

「これは相手と使いたい」
「家事と買い物が楽になりそう」
「LINEで流れていた頼みごとを整理できそう」
「Widgetで毎日見られるのが便利そう」

この体験を実現できれば、おうちボード / HomeMateは、iOS専用でも10万ダウンロードを狙う土台になる。

V1の成功条件は、機能数ではなく、以下の5つである。

1. ホーム画面の分かりやすさ
2. 追加操作の速さ
3. 共有招待の自然さ
4. Widgetの便利さ
5. 責めないメンタルロード可視化

以上をVersion 1.0の最終設計とする。
