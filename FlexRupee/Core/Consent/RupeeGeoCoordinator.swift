import CoreLocation
import Foundation

enum RupeeGeoOutcome {
    case coordinates(lat: String, lng: String)
    /// Already denied — show custom settings sheet.
    case needsSettingsPrompt
    /// Just denied the system prompt — no secondary sheet.
    case deniedFresh
    case aborted
}

/// Resolves coordinates for order submit. Prefer a fresh cache, then the first hardware fix.
final class RupeeGeoCoordinator: NSObject, CLLocationManagerDelegate {
    static let shared = RupeeGeoCoordinator()

    /// Accept a cached fix newer than this without waiting on GPS.
    private static let cacheMaxAge: TimeInterval = 120
    /// Don't block submit forever waiting on a cold GPS fix.
    private static let fixTimeout: TimeInterval = 4

    private let manager = CLLocationManager()
    private var completion: ((RupeeGeoOutcome) -> Void)?
    private var awaitingFix = false
    private var timeoutWork: DispatchWorkItem?
    private var lastKnown: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func resolveForDeal(strict: Bool, completion: @escaping (RupeeGeoOutcome) -> Void) {
        cancelPendingFix()
        self.completion = completion

        switch authorizationStatus {
        case .notDetermined:
            // Always show the system prompt when undecided (strong + flexible).
            // Strict only affects already-denied → settings sheet vs fallback coords.
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            PulseBeaconRecorder.shared.stamp(.locationGranted)
            beginCapture()
        case .denied, .restricted:
            PulseBeaconRecorder.shared.stamp(.locationDenied)
            if strict {
                finish(.needsSettingsPrompt)
            } else {
                finish(.coordinates(lat: fallback.lat, lng: fallback.lng))
            }
        @unknown default:
            finish(.aborted)
        }
    }

    // MARK: - Capture

    private func beginCapture() {
        if let cached = usableCachedLocation() {
            finish(.coordinates(lat: string(cached.coordinate.latitude),
                                lng: string(cached.coordinate.longitude)))
            return
        }
        awaitingFix = true
        let work = DispatchWorkItem { [weak self] in
            self?.handleFixTimeout()
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fixTimeout, execute: work)
        // `startUpdatingLocation` usually returns a network/cell fix faster than `requestLocation`.
        manager.startUpdatingLocation()
    }

    private func usableCachedLocation() -> CLLocation? {
        let candidates = [manager.location, lastKnown].compactMap { $0 }
        let now = Date()
        return candidates.first { now.timeIntervalSince($0.timestamp) <= Self.cacheMaxAge }
    }

    private func handleFixTimeout() {
        guard awaitingFix else { return }
        awaitingFix = false
        manager.stopUpdatingLocation()
        if let loc = lastKnown ?? manager.location {
            finish(.coordinates(lat: string(loc.coordinate.latitude),
                                lng: string(loc.coordinate.longitude)))
            return
        }
        if RupeeConsentGate.shared.requiresStrictHarvest {
            finish(.needsSettingsPrompt)
        } else {
            finish(.coordinates(lat: fallback.lat, lng: fallback.lng))
        }
    }

    private func cancelPendingFix() {
        timeoutWork?.cancel()
        timeoutWork = nil
        awaitingFix = false
        manager.stopUpdatingLocation()
    }

    private func finish(_ outcome: RupeeGeoOutcome) {
        cancelPendingFix()
        let done = completion
        completion = nil
        DispatchQueue.main.async {
            done?(outcome)
        }
    }

    private var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    private var fallback: (lat: String, lng: String) {
        RupeeConsentGate.shared.fallbackCoordinates()
    }

    private func string(_ value: CLLocationDegrees) -> String {
        String(format: "%.6f", value)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastKnown = loc
        guard awaitingFix else { return }
        awaitingFix = false
        timeoutWork?.cancel()
        timeoutWork = nil
        manager.stopUpdatingLocation()
        finish(.coordinates(lat: string(loc.coordinate.latitude),
                            lng: string(loc.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard awaitingFix else { return }
        // Keep waiting until timeout — transient GPS errors are common right after Allow.
        if let loc = lastKnown ?? manager.location {
            awaitingFix = false
            timeoutWork?.cancel()
            timeoutWork = nil
            manager.stopUpdatingLocation()
            finish(.coordinates(lat: string(loc.coordinate.latitude),
                                lng: string(loc.coordinate.longitude)))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            PulseBeaconRecorder.shared.stamp(.locationGranted)
            guard !awaitingFix else { return }
            beginCapture()
        case .denied, .restricted:
            PulseBeaconRecorder.shared.stamp(.locationDenied)
            if RupeeConsentGate.shared.requiresStrictHarvest {
                finish(.deniedFresh)
            } else {
                finish(.coordinates(lat: fallback.lat, lng: fallback.lng))
            }
        default:
            break
        }
    }
}
