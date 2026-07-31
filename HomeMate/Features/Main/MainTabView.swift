//
//  MainTabView.swift
//  HomeMate
//
//  メイン画面のタブ構成（Board / Lists）。設定は各画面右上から開く。
//  Phase 3 で各タブの中身を実装する。
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState

    enum Tab: Hashable { case board, calendar, lists }
    @State private var selectedTab: Tab = .board
    @State private var showJoinBadge = false
    @State private var listsSegment: ListsView.Segment = .chores
    @State private var listsShowCompleted = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Home.createdAt, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var homes: FetchedResults<Home>

    /// 表示中のボード。選択がなければ先頭にフォールバックする。
    private var selectedHome: Home? {
        if let id = appState.selectedHomeId,
           let match = homes.first(where: { $0.id == id }) {
            return match
        }
        return homes.first
    }

    /// 共有で参加したばかりで、自分の名札がまだ無い場合に true。
    private var needsJoinBadge: Bool {
        selectedHome?.needsCurrentMemberBadge ?? false
    }

    /// 参加直後で名札が必要なボードがあれば、それを選択して名札シートを促す。
    /// 共有受け入れ直後（バックグラウンド起動含む）や、同期でボードが遅れて現れた
    /// 場合でも、確実に名前入力へ誘導するために使う。
    private func selectPendingJoinHomeIfNeeded() {
        guard let pending = homes.first(where: { $0.needsCurrentMemberBadge }) else { return }
        if appState.selectedHomeId != pending.id {
            appState.selectedHomeId = pending.id
        }
        showJoinBadge = true
    }

    var body: some View {
        Group {
            if let home = selectedHome {
                TabView(selection: $selectedTab) {
                    BoardView(home: home, onOpenList: { segment in
                        listsSegment = segment
                        listsShowCompleted = false
                        selectedTab = .lists
                    })
                        .tabItem { Label("tab.board", systemImage: "house.fill") }
                        .tag(Tab.board)
                    CalendarView(home: home)
                        .tabItem { Label("tab.calendar", systemImage: "calendar") }
                        .tag(Tab.calendar)
                    ListsView(home: home,
                              segment: $listsSegment,
                              showCompleted: $listsShowCompleted)
                        .tabItem { Label("tab.lists", systemImage: "list.bullet") }
                        .tag(Tab.lists)
                }
                .id(home.objectID)
                .tint(HMColor.accent)
            } else {
                // ボードが見つからない異常系。
                HMEmptyState(systemImage: "house",
                             title: "home.none.title",
                             message: "home.none.message")
            }
        }
        .overlayPreferenceValue(CoachmarkAnchorKey.self) { anchors in
            if selectedHome != nil && !appState.hasCompletedTour {
                // タブバー等のスポットライト計算に実セーフエリアが必要なため、
                // セーフエリアを無視しない GeometryReader で実寸を取得して渡す。
                GeometryReader { proxy in
                    CoachmarkOverlay(steps: CoachmarkStep.mainTour,
                                     anchors: anchors,
                                     hostSafeArea: proxy.safeAreaInsets) {
                        appState.hasCompletedTour = true
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.hasCompletedTour)
        .sheet(isPresented: $showJoinBadge) {
            if let home = selectedHome {
                JoinNameBadgeView(home: home)
            }
        }
        .onAppear {
            selectPendingJoinHomeIfNeeded()
        }
        .onChange(of: needsJoinBadge) { _, newValue in
            if newValue { showJoinBadge = true }
        }
        .onChange(of: homes.count) { _, _ in
            // 同期で共有ボードが遅れて現れた場合に名札入力へ誘導する。
            selectPendingJoinHomeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { _ in
            selectPendingJoinHomeIfNeeded()
        }
        .onOpenURL { url in
            switch url.host {
            case "lists":
                selectedTab = .lists
            case "calendar":
                selectedTab = .calendar
            case "board", "add":
                selectedTab = .board
            case "join":
                if let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value,
                   !code.isEmpty {
                    appState.pendingJoinCode = code
                }
            default:
                break
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.pendingJoinCode != nil },
            set: { if !$0 { appState.pendingJoinCode = nil } }
        )) {
            JoinByCodeView(initialCode: appState.pendingJoinCode)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppState())
}
