//
//  TrackingManager.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//

import Foundation
import CoreLocation
import YandexMapsMobile

protocol TrackingManagerObserver: AnyObject {
    func trackingManager(_ manager: TrackingManager, didUpdateCurrentLocation location: CLLocation)
    func trackingManager(_ manager: TrackingManager, didUpdateTrackSegments segments: [TrackSegment])
    func trackingManager(_ manager: TrackingManager, didUpdateSignalQuality quality: TrackQuality)
    func trackingManagerDidDenyAccess(_ manager: TrackingManager)
}

final class TrackingManager: NSObject {
    
    static let shared = TrackingManager()
    
    private let locationService = LocationService()
    private let motionService = MotionService()
    private let trackRecorder = TrackRecorder()
    private let locationSmoother = AdaptiveLocationSmoother()
    
    private var observers = NSHashTable<AnyObject>.weakObjects()
    
    private var mapService: MapService?
    private var lastSentLocation: CLLocation?
    private var lastSentAt: Date?
    
    private var pendingTrackPoints: [TrackPointPayload] = []
    private var lastTrackUploadAt: Date?
    private let isoFormatter = ISO8601DateFormatter()
    
    private(set) var currentLocation: CLLocation?
    private(set) var currentDisplayLocation: CLLocation?
    private(set) var trackSamples: [TrackSample] = []
    private(set) var currentSignalQuality: TrackQuality = .poor
    private(set) var currentConfidenceScore: Int = 0
    private(set) var currentMovementKind: MapMovementKind = .unknown
    private(set) var currentBreakReason: TrackBreakReason?
    private(set) var currentMotion: MotionSnapshot?
    private var isSharingLocation = true
    
    private override init() {
        super.init()
        locationService.delegate = self
        motionService.delegate = self
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        pendingTrackPoints = TrackPointDiskStore.shared.load()
    }
    
    func configure(mapService: MapService) {
        self.mapService = mapService
    }
    
    func start() {
        locationService.requestAccess()
        motionService.start()
    }
    
    func stop() {
        locationService.stopUpdatingLocation()
        motionService.stop()
    }
    
    func addObserver(_ observer: TrackingManagerObserver) {
        observers.add(observer)
        
        if let currentLocation {
            observer.trackingManager(self, didUpdateCurrentLocation: currentLocation)
        }
        
        observer.trackingManager(self, didUpdateSignalQuality: currentSignalQuality)
        
        if !trackSamples.isEmpty {
            observer.trackingManager(
                self,
                didUpdateTrackSegments: TrackSegmentation.buildTrackSegments(from: trackSamples)
            )
        }
    }
    
    func removeObserver(_ observer: TrackingManagerObserver) {
        observers.remove(observer)
    }
    
    func requestAlwaysAccessIfNeeded() {
        locationService.requestAlwaysAccessIfNeeded()
    }
    
    func enableBackgroundUpdatesIfPossible() {
        locationService.enableBackgroundUpdatesIfPossible()
    }
    
    func replaceTrack(with segments: [TrackSegment]) {
        trackSamples = segments.flatMap { segment in
            segment.points.enumerated().map { index, point in
                let timestamp: Date
                if segment.points.count <= 1 {
                    timestamp = segment.startedAt
                } else {
                    let progress = Double(index) / Double(segment.points.count - 1)
                    let interval = segment.endedAt.timeIntervalSince(segment.startedAt) * progress
                    timestamp = segment.startedAt.addingTimeInterval(interval)
                }

                return TrackSample(
                    point: point,
                    recordedAt: timestamp,
                    quality: segment.quality,
                    movementState: .unknown,
                    horizontalAccuracy: nil,
                    rawPoint: segment.rawPoints.indices.contains(index) ? segment.rawPoints[index] : point,
                    confidenceScore: segment.confidenceScore,
                    movementKind: segment.movementKind,
                    breakReason: segment.breakReason
                )
            }
        }

        trackRecorder.replace(with: trackSamples)
        notifyTrack()
    }
    
    func flushPendingTrackPoints() {
        uploadTrackPointsIfNeeded(force: true)
    }
    
    private func notifyLocation(_ location: CLLocation) {
        for case let observer as TrackingManagerObserver in observers.allObjects {
            observer.trackingManager(self, didUpdateCurrentLocation: location)
        }
    }
    
    private func notifyTrack() {
        let segments = TrackSegmentation.buildTrackSegments(from: trackSamples)
        for case let observer as TrackingManagerObserver in observers.allObjects {
            observer.trackingManager(self, didUpdateTrackSegments: segments)
        }
    }
    
    private func notifySignalQuality() {
        for case let observer as TrackingManagerObserver in observers.allObjects {
            observer.trackingManager(self, didUpdateSignalQuality: currentSignalQuality)
        }
    }
    
    private func notifyDeniedAccess() {
        for case let observer as TrackingManagerObserver in observers.allObjects {
            observer.trackingManagerDidDenyAccess(self)
        }
    }
    
    private func sendLiveLocationIfNeeded(_ location: CLLocation, confidence: LocationConfidence) {
        guard let mapService else { return }
        
        if let lastSentAt, Date().timeIntervalSince(lastSentAt) < 12 {
            if let lastSentLocation, location.distance(from: lastSentLocation) < 15 {
                return
            }
        }
        
        lastSentAt = Date()
        lastSentLocation = location
        
        Task {
            do {
                try await mapService.updateLiveLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    speed: location.speed >= 0 ? location.speed : nil,
                    course: location.course >= 0 ? location.course : nil,
                    confidenceScore: confidence.score,
                    movementState: confidence.movementKind.rawValue,
                    isSharing: self.isSharingLocation
                )
            } catch {
                print("Live location send error:", error.localizedDescription)
            }
        }
    }
    
    private func enqueueTrackPoint(_ location: CLLocation, confidence: LocationConfidence) {
        let payload = TrackPointPayload(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil,
            movementState: currentMotion?.state.rawValue,
            stepsDelta: currentMotion?.stepsDelta,
            confidenceScore: confidence.score,
            movementKind: confidence.movementKind.rawValue,
            breakReason: confidence.breakReason?.rawValue,
            recordedAt: isoFormatter.string(from: location.timestamp)
        )

        let lastPending = pendingTrackPoints.last

        guard TrackSimplification.shouldAppendToUploadQueue(
            newPoint: payload,
            lastPoint: lastPending,
            minimumDistance: 5
        ) else {
            return
        }

        pendingTrackPoints.append(payload)
        TrackPointDiskStore.shared.save(pendingTrackPoints)
    }
    
    private func uploadTrackPointsIfNeeded(force: Bool = false) {
        guard let mapService else { return }
        guard !pendingTrackPoints.isEmpty else { return }
        
        let now = Date()
        let shouldUploadByCount = pendingTrackPoints.count >= 5
        let shouldUploadByTime: Bool
        
        if let lastTrackUploadAt {
            shouldUploadByTime = now.timeIntervalSince(lastTrackUploadAt) >= 20
        } else {
            shouldUploadByTime = true
        }
        
        guard force || shouldUploadByCount || shouldUploadByTime else { return }
        
        let batch = pendingTrackPoints
        pendingTrackPoints.removeAll()
        TrackPointDiskStore.shared.save(pendingTrackPoints)
        lastTrackUploadAt = now
        
        Task {
            do {
                try await mapService.uploadTrackPoints(batch)
            } catch {
                print("Track points upload error:", error.localizedDescription)
                
                await MainActor.run {
                    self.pendingTrackPoints.insert(contentsOf: batch, at: 0)
                    TrackPointDiskStore.shared.save(self.pendingTrackPoints)
                }
            }
        }
    }
}

extension TrackingManager: LocationServiceDelegate {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation) {
        let confidence = LocationConfidence.evaluate(
            location: location,
            previousLocation: currentLocation,
            motion: currentMotion
        )
        let displayLocation = locationSmoother.smoothedLocation(
            from: location,
            confidence: confidence,
            motion: currentMotion
        )
        
        currentLocation = location
        currentDisplayLocation = displayLocation
        currentSignalQuality = confidence.quality
        currentConfidenceScore = confidence.score
        currentMovementKind = confidence.movementKind
        currentBreakReason = confidence.breakReason
        
        notifyLocation(displayLocation)
        notifySignalQuality()
        
        if trackRecorder.appendIfNeeded(location, motion: currentMotion) {
            trackSamples = trackRecorder.samples
            notifyTrack()
            enqueueTrackPoint(location, confidence: confidence)
            uploadTrackPointsIfNeeded()
            sendLiveLocationIfNeeded(location, confidence: confidence)
        }
    }
    
    func locationServiceDidDenyAccess(_ service: LocationService) {
        notifyDeniedAccess()
    }
    func startMonitoringSignificantLocationChanges() {
        locationService.startMonitoringSignificantLocationChanges()
    }
    
    func locationService(_ service: LocationService, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse:
            requestAlwaysAccessIfNeeded()
        case .authorizedAlways:
            enableBackgroundUpdatesIfPossible()
            startMonitoringSignificantLocationChanges()
        default:
            break
        }
    }
    func setLocationSharingEnabled(_ enabled: Bool) {
        isSharingLocation = enabled
    }
}

extension TrackingManager: MotionServiceDelegate {
    func motionService(_ service: MotionService, didUpdate snapshot: MotionSnapshot) {
        currentMotion = snapshot
    }
    
}

private final class AdaptiveLocationSmoother {
    private var lastLocation: CLLocation?
    
    func smoothedLocation(
        from location: CLLocation,
        confidence: LocationConfidence,
        motion: MotionSnapshot?
    ) -> CLLocation {
        guard let lastLocation else {
            self.lastLocation = location
            return location
        }
        
        let distance = location.distance(from: lastLocation)
        
        if confidence.movementKind == .stationary &&
            distance < max(location.horizontalAccuracy * 0.35, 8) {
            return lastLocation
        }
        
        if confidence.breakReason != nil && confidence.quality == .poor {
            self.lastLocation = location
            return location
        }
        
        let factor = smoothingFactor(
            confidence: confidence,
            distance: distance,
            motion: motion
        )
        
        let coordinate = CLLocationCoordinate2D(
            latitude: lastLocation.coordinate.latitude +
                (location.coordinate.latitude - lastLocation.coordinate.latitude) * factor,
            longitude: lastLocation.coordinate.longitude +
                (location.coordinate.longitude - lastLocation.coordinate.longitude) * factor
        )
        
        let result = CLLocation(
            coordinate: coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            timestamp: location.timestamp
        )
        
        self.lastLocation = result
        return result
    }
    
    private func smoothingFactor(
        confidence: LocationConfidence,
        distance: CLLocationDistance,
        motion: MotionSnapshot?
    ) -> Double {
        if distance > 120 && confidence.quality != .poor {
            return 0.86
        }
        
        if confidence.movementKind == .transport {
            return 0.52
        }
        
        switch confidence.quality {
        case .good:
            return motion?.isMovingOnFoot == true ? 0.78 : 0.66
        case .weak:
            return 0.42
        case .poor:
            return 0.20
        }
    }
}
