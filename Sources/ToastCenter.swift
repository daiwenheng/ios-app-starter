import Foundation
import Observation

/// 轻提示:显示一句话,两秒后自动消失。
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?

    @ObservationIgnored private var generation = 0

    func show(_ text: String) {
        generation += 1
        let current = generation
        message = text
        Task { [self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if current == generation {
                message = nil
            }
        }
    }
}
