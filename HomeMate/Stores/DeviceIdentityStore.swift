//
//  DeviceIdentityStore.swift
//  HomeMate
//
//  「この端末でのあなた（現在メンバー）」をボードごとに端末ローカルで保持する。
//
//  なぜ必要か（重要）:
//  `Member.isCurrentUser` は Core Data 属性であり NSPersistentCloudKitContainer により
//  CloudKit 同期されてしまう。つまりオーナー端末で立てた `isCurrentUser=true` が
//  参加者端末にもそのまま届き、参加者が「自分＝オーナー」と誤認する（完了者・メンタル
//  ロード・ありがとう帰属・プライベート可視性が別人に紐づく）。
//  そこで本ストアが UserDefaults に端末ローカルで [Home.id : Member.id] を保持し、
//  `Home.currentMember` の唯一の真実の源とする。`isCurrentUser` は権威ある情報として
//  読まない（書き込みは互換のため残すが参照しない）。
//

import CoreData
import Foundation

enum DeviceIdentityStore {
    private static let mapKey = "currentMemberByHome"
    private static let migrationKey = "currentMemberByHome.migratedV1"

    private static func loadMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mapKey) as? [String: String] ?? [:]
    }

    private static func saveMap(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: mapKey)
    }

    /// この端末で指定ボードの「自分」に対応するメンバー ID。
    static func currentMemberId(for homeId: UUID?) -> UUID? {
        guard let homeId, let raw = loadMap()[homeId.uuidString] else { return nil }
        return UUID(uuidString: raw)
    }

    /// この端末で指定ボードの「自分」を設定する。`nil` で解除。
    static func setCurrentMember(_ memberId: UUID?, for homeId: UUID?) {
        guard let homeId else { return }
        var map = loadMap()
        if let memberId {
            map[homeId.uuidString] = memberId.uuidString
        } else {
            map.removeValue(forKey: homeId.uuidString)
        }
        saveMap(map)
    }

    /// 指定ボードの端末ローカル ID を解除する（退出・アーカイブ時）。
    static func clear(for homeId: UUID?) {
        setCurrentMember(nil, for: homeId)
    }

    /// 端末ローカル台帳が無かった既存ボードを一度だけ移行する。
    /// 共有ボードは `isCurrentUser` が同期で汚染されている可能性があるため自動採用せず、
    /// 参加者に名札再確認（`needsCurrentMemberBadge`）を促す。非共有（この端末だけの）
    /// ボードに限り、`isCurrentUser=true` のメンバーを「自分」として採用する。
    @MainActor
    static func migrateIfNeeded(context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        let request = Home.fetchRequest()
        let homes = (try? context.fetch(request)) ?? []
        var map = loadMap()
        for home in homes {
            guard let homeId = home.id, map[homeId.uuidString] == nil else { continue }
            if home.isShared { continue }
            if let me = home.membersArray.first(where: { $0.isCurrentUser }), let meId = me.id {
                map[homeId.uuidString] = meId.uuidString
            }
        }
        saveMap(map)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
