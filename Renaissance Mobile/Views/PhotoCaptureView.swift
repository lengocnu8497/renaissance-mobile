//
//  PhotoCaptureView.swift
//  Renaissance Mobile
//
//  Camera wrapper with:
//  - Face oval alignment guide
//  - Ambient lighting quality indicator
//  - Front/rear camera toggle
//  - Photo library fallback
//

import SwiftUI
import AVFoundation
import PhotosUI

struct PhotoCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    @State private var cameraVM = CameraViewModel()
    @State private var showLibraryPicker = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var lightingOK = true

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()

            // Face oval guide
            GeometryReader { geo in
                let w = geo.size.width * 0.62
                let h = w * 1.35
                let cx = geo.size.width / 2
                let cy = geo.size.height * 0.42

                Ellipse()
                    .stroke(
                        lightingOK ? Color.white.opacity(0.85) : Color.orange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.5, dash: [8, 5])
                    )
                    .frame(width: w, height: h)
                    .position(x: cx, y: cy)

                Text(lightingOK ? "Align your face within the oval" : "Move to better lighting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .position(x: cx, y: cy + h / 2 + 20)
            }

            // Lighting indicator (top)
            VStack {
                HStack {
                    Spacer()
                    LightingBadge(isOK: lightingOK)
                        .padding(.trailing, 20)
                        .padding(.top, 56)
                }
                Spacer()
            }

            // Controls (bottom)
            VStack {
                Spacer()
                HStack(spacing: 48) {
                    // Library picker
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .onChange(of: libraryItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                capturedImage = img
                                dismiss()
                            }
                        }
                    }

                    // Shutter
                    Button {
                        Task {
                            if let img = await cameraVM.capturePhoto() {
                                capturedImage = img
                                dismiss()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(Theme.Brand.dustyRose, lineWidth: 3)
                                .frame(width: 82, height: 82)
                        }
                    }

                    // Flip camera
                    Button { cameraVM.flipCamera() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 48)
            }

            // Close
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 56)
                    Spacer()
                }
                Spacer()
            }
        }
        .task {
            await cameraVM.setup()
            // Poll lighting every 2 seconds
            for await _ in AsyncStream<Void>.polling(every: 2) {
                lightingOK = cameraVM.estimatedLuxOK
            }
        }
        .onDisappear { cameraVM.stop() }
    }
}

// MARK: - Lighting Badge

private struct LightingBadge: View {
    let isOK: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isOK ? "sun.max.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(isOK ? "Good lighting" : "Low lighting")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(isOK ? Color.white : Color.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        var session: AVCaptureSession? {
            didSet {
                guard let session else { return }
                previewLayer.session = session
            }
        }
        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
        }
    }
}

// MARK: - CameraViewModel

@Observable
class CameraViewModel: NSObject {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .front
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private(set) var estimatedLuxOK = true

    func setup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }

        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.addInput(for: .front)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
        }.value
    }

    func stop() {
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
        }
    }

    func flipCamera() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.currentPosition = self.currentPosition == .front ? .back : .front
            self.addInput(for: self.currentPosition)
            self.session.commitConfiguration()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        // Rough lighting check: try to read ISO as a proxy
        estimatedLuxOK = (device.iso < 1200)
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(returning: nil)
            photoContinuation = nil
            return
        }
        // Mirror front camera shot
        let final = currentPosition == .front
            ? UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
            : image
        photoContinuation?.resume(returning: final)
        photoContinuation = nil
    }
}

// MARK: - Polling helper

extension AsyncStream where Element == Void {
    static func polling(every seconds: Double) -> AsyncStream<Void> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    continuation.yield()
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }
}
