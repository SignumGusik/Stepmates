//
//  TrackPointDiskStore.swift
//  Stepmates Auth
//
//  Created by Диана on 10/05/2026.
//

import Foundation

final class TrackPointDiskStore {

    static let shared = TrackPointDiskStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "stepmates.track-point-disk-store")

    private init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("pending_track_points.json")
    }

    func load() -> [TrackPointPayload] {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return []
            }

            do {
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode([TrackPointPayload].self, from: data)
            } catch {
                print("Pending track points load error:", error.localizedDescription)
                return []
            }
        }
    }

    func save(_ points: [TrackPointPayload]) {
        queue.async {
            do {
                let limited = Array(points.suffix(1000))
                let data = try JSONEncoder().encode(limited)
                try data.write(to: self.fileURL, options: [.atomic])
            } catch {
                print("Pending track points save error:", error.localizedDescription)
            }
        }
    }

    func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }
}
