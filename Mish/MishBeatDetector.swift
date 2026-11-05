
import Foundation

final class MishBeatDetector {
    private var previousBassEnergy: Float = 0
    private var energyHistory: [(time: TimeInterval, energy: Float)] = []
    private var beatTimes: [TimeInterval] = []

    private(set) var bpm: Double = 0
    private(set) var beatIntensity: Float = 0

    func process(
        spectrum: [Float],
        at time: TimeInterval
    ) {
        // The first 12 bands represent the low end approximately.
        let bassBands = spectrum.prefix(12)
        let bassEnergy = bassBands.reduce(0, +) /
            Float(max(bassBands.count, 1))

        energyHistory.append((time, bassEnergy))

        // Keep a short history for adaptive thresholding.
        energyHistory.removeAll { time - $0.time > 2.0 }

        let averageEnergy = energyHistory.reduce(Float(0)) {
            $0 + $1.energy
        } / Float(max(energyHistory.count, 1))

        let rise = bassEnergy - previousBassEnergy
        previousBassEnergy = bassEnergy

        // Detect a significant bass-energy increase.
        let threshold = max(0.025, averageEnergy * 0.35)

        if rise > threshold && time - (beatTimes.last ?? -10) > 0.25 {
            beatTimes.append(time)
            beatTimes.removeAll { time - $0 > 10 }
        }

        // Estimate tempo from recent beat intervals.
        if beatTimes.count >= 3 {
            let intervals = zip(
                beatTimes.dropFirst(),
                beatTimes
            ).map { $0.0 - $0.1 }

            let validIntervals = intervals.filter {
                $0 >= 0.33 && $0 <= 1.0
            }

            if !validIntervals.isEmpty {
                let averageInterval = validIntervals.reduce(0, +) /
                    Double(validIntervals.count)

                bpm = 60.0 / averageInterval
            }
        }

        beatIntensity = min(1, max(0, rise * 8))
    }

    func reset() {
        previousBassEnergy = 0
        energyHistory.removeAll()
        beatTimes.removeAll()
        bpm = 0
        beatIntensity = 0
    }
}
