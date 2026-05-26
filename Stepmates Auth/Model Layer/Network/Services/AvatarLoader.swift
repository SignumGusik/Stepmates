//
//  AvatarLoader.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//
import UIKit

final class AvatarLoader {
    static let shared = AvatarLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let diskQueue = DispatchQueue(label: "stepmates.avatar.disk-cache", qos: .utility)
    private let diskCacheDirectory: URL?

    private init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 300

        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        diskCacheDirectory = cachesDirectory?.appendingPathComponent("AvatarCache", isDirectory: true)

        if let diskCacheDirectory {
            try? FileManager.default.createDirectory(
                at: diskCacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    @discardableResult
    func load(urlString: String,
              completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {

        if let cached = cache.object(forKey: urlString as NSString) {
            completion(cached)
            return nil
        }

        if let diskImage = imageFromDisk(urlString: urlString) {
            cache.setObject(diskImage, forKey: urlString as NSString)
            completion(diskImage)
            return nil
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return nil
        }

        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }

            guard let data else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let img = UIImage(data: data)

            if let img {
                self.cache.setObject(img, forKey: urlString as NSString)
                self.saveToDisk(data: data, urlString: urlString)
            }

            DispatchQueue.main.async {
                completion(img)
            }
        }

        task.resume()
        return task
    }

    func prefetch(urlStrings: [String]) {
        let uniqueUrls = Array(Set(urlStrings)).filter { !$0.isEmpty }

        for urlString in uniqueUrls {
            if cache.object(forKey: urlString as NSString) != nil {
                continue
            }

            _ = load(urlString: urlString) { _ in }
        }
    }

    private func imageFromDisk(urlString: String) -> UIImage? {
        guard let fileURL = fileURL(for: urlString),
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return UIImage(data: data)
    }

    private func saveToDisk(data: Data, urlString: String) {
        guard let fileURL = fileURL(for: urlString) else { return }

        diskQueue.async {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private func fileURL(for urlString: String) -> URL? {
        guard let diskCacheDirectory else { return nil }

        let key = Data(urlString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return diskCacheDirectory.appendingPathComponent("\(key).avatar")
    }
}
