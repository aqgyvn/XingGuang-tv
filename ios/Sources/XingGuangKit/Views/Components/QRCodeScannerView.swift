import AVFoundation
import SwiftUI

public struct QRCodeScannerSheet: View {
    public let onResult: (String) -> Void
    public let onCancel: () -> Void
    @State private var errorMessage = ""

    public init(onResult: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            QRCodeCameraView(onResult: onResult, onError: { errorMessage = $0 })
                .ignoresSafeArea()
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 320)
                    .padding(.top, 72)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
            }
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .accessibilityLabel("关闭扫码")
            .padding(18)
        }
        .background(Color.black)
    }
}

private struct QRCodeCameraView: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeCameraViewController {
        QRCodeCameraViewController(onResult: onResult, onError: onError)
    }

    func updateUIViewController(_ uiViewController: QRCodeCameraViewController, context: Context) {}
}

private final class QRCodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.xingguang.video.ios.qr-scanner")
    private let onResult: (String) -> Void
    private let onError: (String) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var completed = false

    init(onResult: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onResult = onResult
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureCamera() }
                    else { self?.onError("未获得相机权限") }
                }
            }
        default:
            onError("请在系统设置中允许星光访问相机")
        }
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onError("当前设备没有可用相机")
            return
        }
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError("当前设备无法扫描二维码")
            return
        }
        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        sessionQueue.async { [session] in session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else { return }
        completed = true
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        onResult(value)
    }
}
