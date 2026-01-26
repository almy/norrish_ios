import UIKit
import AVFoundation
import AudioToolbox

class BarcodeScannerViewController: UIViewController {
    weak var delegate: BarcodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // New: debounce/throttle to avoid multiple emissions
    private var didEmitCode = false
    private var lastEmittedCode: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupCloseButton()
    }
    
    private func setupCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        closeButton.layer.cornerRadius = 20
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    func startScanning() {
        didEmitCode = false
        lastEmittedCode = nil
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    func stopScanning() {
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .upce, .code128]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        // Add scanning guide frame overlay
        setupScanningGuide()
    }
    
    private func setupScanningGuide() {
        // Create the scanning guide frame
        let frameWidth: CGFloat = 280
        let frameHeight: CGFloat = 120
        
        // Position the frame in the center of the screen
        let frameX = (view.bounds.width - frameWidth) / 2
        let frameY = (view.bounds.height - frameHeight) / 2
        
        // Create the frame view
        let scanningFrame = UIView()
        scanningFrame.frame = CGRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight)
        scanningFrame.backgroundColor = UIColor.clear
        scanningFrame.layer.borderWidth = 3.0
        scanningFrame.layer.borderColor = UIColor.systemGreen.cgColor
        scanningFrame.layer.cornerRadius = 12
        
        // Add corner indicators for better visual guidance
        addCornerIndicators(to: scanningFrame)
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position barcode within the green frame"
        instructionLabel.textColor = UIColor.white
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.layer.masksToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scanningFrame)
        view.addSubview(instructionLabel)
        
        // Set up constraints for the instruction label
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: scanningFrame.bottomAnchor, constant: 30),
            instructionLabel.widthAnchor.constraint(equalToConstant: 300),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Set the metadata output's rect of interest to focus on the scanning area
        let rectOfInterest = previewLayer?.metadataOutputRectConverted(fromLayerRect: scanningFrame.frame) ?? CGRect.zero
        if let metadataOutput = captureSession?.outputs.first(where: { $0 is AVCaptureMetadataOutput }) as? AVCaptureMetadataOutput {
            metadataOutput.rectOfInterest = rectOfInterest
        }
    }
    
    private func addCornerIndicators(to frameView: UIView) {
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 4
        let corners = [
            // Top-left
            (CGPoint(x: 0, y: 0), [
                CGRect(x: 0, y: 0, width: cornerLength, height: cornerWidth),
                CGRect(x: 0, y: 0, width: cornerWidth, height: cornerLength)
            ]),
            // Top-right
            (CGPoint(x: frameView.bounds.width, y: 0), [
                CGRect(x: -cornerLength, y: 0, width: cornerLength, height: cornerWidth),
                CGRect(x: -cornerWidth, y: 0, width: cornerWidth, height: cornerLength)
            ]),
            // Bottom-left
            (CGPoint(x: 0, y: frameView.bounds.height), [
                CGRect(x: 0, y: -cornerWidth, width: cornerLength, height: cornerWidth),
                CGRect(x: 0, y: -cornerLength, width: cornerWidth, height: cornerLength)
            ]),
            // Bottom-right
            (CGPoint(x: frameView.bounds.width, y: frameView.bounds.height), [
                CGRect(x: -cornerLength, y: -cornerWidth, width: cornerLength, height: cornerWidth),
                CGRect(x: -cornerWidth, y: -cornerLength, width: cornerWidth, height: cornerLength)
            ])
        ]
        
        for (_, rects) in corners {
            for rect in rects {
                let cornerIndicator = UIView(frame: rect)
                cornerIndicator.backgroundColor = UIColor.systemGreen
                cornerIndicator.layer.cornerRadius = 2
                frameView.addSubview(cornerIndicator)
            }
        }
    }
}

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession?.stopRunning()
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            // Throttle duplicate emissions
            if didEmitCode, lastEmittedCode == stringValue {
                return
            }
            didEmitCode = true
            lastEmittedCode = stringValue
            // Subtle haptic
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            // Notify delegate once
            delegate?.didScanBarcode(stringValue)
        }
    }
}
