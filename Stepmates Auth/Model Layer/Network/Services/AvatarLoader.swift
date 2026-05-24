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

    private init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 300
    }

    @discardableResult
    func load(urlString: String,
              completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {

        if let cached = cache.object(forKey: urlString as NSString) {
            completion(cached)
            return nil
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return nil
        }

        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }

            var img: UIImage?
            if let data {
                img = UIImage(data: data)
            }

            if let img {
                self.cache.setObject(img, forKey: urlString as NSString)
            }

            DispatchQueue.main.async {
                completion(img)
            }
        }

        task.resume()
        return task
    }
}
