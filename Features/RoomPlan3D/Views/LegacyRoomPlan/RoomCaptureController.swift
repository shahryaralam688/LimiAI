//
//  RoomCaptureController.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import Foundation
import RoomPlan
import Observation

/// Thin RoomPlan session bridge (Phase K). State/upload lives in `RoomCaptureViewModel`.
@Observable
class RoomCaptureController: RoomCaptureViewDelegate, RoomCaptureSessionDelegate, ObservableObject {
    let viewModel = RoomCaptureViewModel()

    required init?(coder: NSCoder) {
        fatalError("Not needed.")
    }

    func encode(with coder: NSCoder) {
        fatalError("Not needed.")
    }

    private var _roomCaptureView: RoomCaptureView?

    var roomCaptureView: RoomCaptureView {
        if let existing = _roomCaptureView {
            return existing
        }
        let view = RoomCaptureView(frame: .zero)
        view.captureSession.delegate = self
        view.delegate = self
        _roomCaptureView = view
        return view
    }

    var sessionConfig: RoomCaptureSession.Configuration
    var finalResult: CapturedRoom?

    init() {
        sessionConfig = RoomCaptureSession.Configuration()
        viewModel.captureController = self
    }

    func startSession() {
        // Apple’s RoomPlan API — never run capture on non‑LiDAR / non‑Pro hardware.
        guard RoomPlanCapability.isCaptureSupported else {
            return
        }
        roomCaptureView.captureSession.run(configuration: sessionConfig)
    }

    func stopSession() {
        roomCaptureView.captureSession.stop()
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResult = processedResult
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.markScanComplete()
        }
    }
}
