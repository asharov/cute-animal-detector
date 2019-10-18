//
//  ViewController.swift
//  IsCute
//
//  Created by Jaakko Kangasharju on 15.10.19.
//  Copyright © 2019 Jaakko Kangasharju. All rights reserved.
//

import UIKit
import AVKit
import Vision
import SnapKit

// This simple view provides the video preview from the camera
private class PreviewView: UIView {

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

// The app functions as a simple state machine. It passes through the following states:
// Ready: The app shows live camera preview and waits for the user to press the Evaluate button
// Capturing: The Evaluate button has been pressed, the app is waiting for the photo to be captured
// Classifying: The photo has been captured and frozen on screen, the app is evaluating the photo
// Showing: The app has finished evaluating the photo and shows the results
enum State {
    case ready
    case capturing
    case classifying
    case showing
}

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    private let model: VNCoreMLModel
    private var previewView: PreviewView?
    private var captureView: CaptureView?
    private var cameraOutput: AVCapturePhotoOutput?
    private var startTimestamp: TimeInterval = 0.0
    private var evaluateButton: UIButton?
    private var resetButton: UIButton?
    private var cutenessPercentageLabel: UILabel?
    private var cutenessEvaluationLabel: UILabel?

    required init?(coder: NSCoder) {
        // Initialize the model in the init() method, since it won't change, and the
        // initialization takes quite a bit of time. This model cannot run on the
        // neural engine, so it's limited to CPU and GPU only.
        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .cpuAndGPU
        do {
            let isCuteModel = try iscute(configuration: modelConfiguration)
            model = try VNCoreMLModel(for: isCuteModel.model)
        } catch {
            return nil
        }

        super.init(coder: coder)
    }

    func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .roundedRect)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.setTitleColor(UIColor.black, for: .normal)
        self.view.addSubview(button)
        return button
    }

    func makeLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 44.0)
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 6.0 / 255.0, alpha: 1.0)
        label.textColor = UIColor(white: 240.0 / 255.0, alpha: 1.0)
        self.view.addSubview(label)
        return label
    }

    // The state-setting method makes sure that the visibility of all views is as expected
    // and that the image being classified is shown only in the appropriate states.
    func setState(_ state: State, image: UIImage? = nil) {
        switch state {
        case .ready:
            evaluateButton?.isHidden = false
            resetButton?.isHidden = true
            cutenessPercentageLabel?.isHidden = true
            cutenessEvaluationLabel?.isHidden = true
            self.captureView?.releaseImage()
        case .capturing:
            evaluateButton?.isHidden = true
            resetButton?.isHidden = true
            cutenessPercentageLabel?.isHidden = true
            cutenessEvaluationLabel?.isHidden = true
            self.captureView?.releaseImage()
        case .classifying:
            evaluateButton?.isHidden = true
            resetButton?.isHidden = true
            cutenessPercentageLabel?.isHidden = true
            cutenessEvaluationLabel?.isHidden = true
            self.captureView?.freezeImage(image!)
        case .showing:
            evaluateButton?.isHidden = true
            resetButton?.isHidden = false
            cutenessPercentageLabel?.isHidden = false
            cutenessEvaluationLabel?.isHidden = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        previewView = PreviewView()
        self.view.addSubview(previewView!)
        previewView!.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        captureView = CaptureView()
        captureView?.isOpaque = false
        self.view.addSubview(captureView!)
        captureView!.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(319)
            make.height.equalTo(319)
        }

        let evaluateButton = makeButton(title: NSLocalizedString("EvaluateButton", comment: ""))
        evaluateButton.backgroundColor = .green
        evaluateButton.addTarget(self, action: #selector(evaluate), for: .touchUpInside)
        evaluateButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
        }
        self.evaluateButton = evaluateButton

        let resetButton = makeButton(title: NSLocalizedString("ResetButton", comment: ""))
        resetButton.backgroundColor = .red
        resetButton.addTarget(self, action: #selector(reset), for: .touchUpInside)
        resetButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(100)
        }
        self.resetButton = resetButton

        let cutenessEvaluationLabel = makeLabel()
        cutenessEvaluationLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-100)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(cutenessEvaluationLabel.font.lineHeight + 10)
        }
        self.cutenessEvaluationLabel = cutenessEvaluationLabel

        let cutenessPercentageLabel = makeLabel()
        cutenessPercentageLabel.snp.makeConstraints { make in
            make.bottom.equalTo(self.cutenessEvaluationLabel!.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(cutenessPercentageLabel.font.lineHeight + 10)
        }
        self.cutenessPercentageLabel = cutenessPercentageLabel

        setState(.ready)

        // Need to ask for permission from the user to use the camera if the user has
        // not yet made a decision on it. For a practice app like this, there is no
        // need to handle the case when the user has not granted permission.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCaptureSession()
                }
            }
        default:
            break
        }
    }

    func setupCaptureSession() {
        // Only the preview layer setting needs to happen on the main thread, but it's simpler
        // to run everything there, and it doesn't take so much time that it would block the app
        DispatchQueue.main.async {
            let captureSession = AVCaptureSession()
            captureSession.beginConfiguration()
            // Find the backwards-facing camera, set it up for video capture, and make sure it
            // can be added to the session
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            guard let backCameraInput = try? AVCaptureDeviceInput(device: backCamera!),
                captureSession.canAddInput(backCameraInput) else {
                    return
            }
            captureSession.addInput(backCameraInput)

            // Create a photo output for the session
            self.cameraOutput = AVCapturePhotoOutput()
            guard captureSession.canAddOutput(self.cameraOutput!) else {
                return
            }
            captureSession.addOutput(self.cameraOutput!)

            // Set the session for the preview layer so that the camera preview is visible on screen
            self.previewView!.previewLayer.session = captureSession
            self.previewView!.previewLayer.connection?.videoOrientation = .portrait

            captureSession.commitConfiguration()

            // Start the session so that pictures can be captured
            captureSession.startRunning()
        }
    }

    @objc func evaluate() {
        // Capture a photo: Create picture settings, and tell the camera output to start the capture
        let pictureSettings = AVCapturePhotoSettings()
        self.cameraOutput?.connection(with: .video)?.videoOrientation = .portrait
        setState(.capturing)
        self.startTimestamp = Date().timeIntervalSince1970
        self.cameraOutput!.capturePhoto(with: pictureSettings, delegate: self)
    }

    @objc func reset() {
        setState(.ready)
    }

    // The captured photo that is received from the framework has its orientation encoded
    // as the enum CGImagePropertyOrientation. But for display on screen, UIImage needs to
    // have it as UIImage.Orientation. And even though these two enums have exactly the same
    // values, the raw values are different, so a switch statement is necessary for conversion
    // even though it does not seem to do anything
    func imageOrientation(from orientation: CGImagePropertyOrientation) -> UIImage.Orientation {
        switch orientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        }
    }

    // UIImage handles orientation by itself, but for the operations needed, we need to work
    // with CGImages that don't. This method does a "rotation" of a CGSize value if needed
    // so that the dimensions between the screen coordinates and image coordinates match.
    func size(from size: CGSize, in orientation: CGImagePropertyOrientation) -> CGSize {
        switch orientation {
        case .up, .upMirrored, .down, .downMirrored:
            return size
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: size.height, height: size.width)
        }
    }

    func cropImage(photo: AVCapturePhoto, photoOrientation: CGImagePropertyOrientation) -> UIImage {
        // Crop the image so that the image fed to the model matches the bounded area that the user sees.
        // First, get the photo as a CGImage and get its size as a CGSize
        let fullCgImage = photo.cgImageRepresentation()?.takeUnretainedValue()
        let fullCgImageSize = CGSize(width: fullCgImage!.width, height: fullCgImage!.height)

        // The dimensions of the photo are different from the screen dimensions, and also the orientation
        // of the photo might be different. Take the screen bounds, orient them along the same lines as
        // the photo, and compute the scaling factor needed to convert between screen coordinates and
        // photo coordinates.
        let bounds = self.view.bounds
        let orientedBounds = size(from: bounds.size, in: photoOrientation)
        let scale = fullCgImageSize.height / orientedBounds.height

        // The area to leave is a 299x299 point are in the middle of the screen. So 299 gets scaled with
        // the above computed scaling factor, and a rectangle of that size computed centered on the center
        // of the image. That rectangle can then be used to crop the image.
        let frameSize = CGSize(width: 299.0 * scale, height: 299.0 * scale)
        let center = CGPoint(x: fullCgImage!.width / 2, y: fullCgImage!.height / 2)
        let frame = CGRect(x: center.x - frameSize.width / 2, y: center.y - frameSize.height / 2, width: frameSize.width, height: frameSize.height)
        let croppedCgImage = fullCgImage!.cropping(to: frame)

        // Create a UIImage from the cropped CGImage with the correct scaling and orientation
        let imageOrienation = imageOrientation(from: photoOrientation)
        let croppedImage = UIImage(cgImage: croppedCgImage!, scale: UIScreen.main.scale, orientation: imageOrienation)
        return croppedImage
    }

    // Called when the photo has been captured
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        do {
            print("Capture time \(Int(1000 * (Date().timeIntervalSince1970 - self.startTimestamp))) ms")
            self.startTimestamp = Date().timeIntervalSince1970
            // Crop the image, and pass the cropped image to the classifier
            let photoOrientation = CGImagePropertyOrientation(rawValue: photo.metadata[String(kCGImagePropertyOrientation)] as! UInt32)!
            let image = cropImage(photo: photo, photoOrientation: photoOrientation)
            let request = VNCoreMLRequest(model: model, completionHandler: pictureClassified)
            let handler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: photoOrientation, options: [:])
            print("Preparation time \(Int(1000 * (Date().timeIntervalSince1970 - self.startTimestamp))) ms")
            self.setState(.classifying, image: image)
            self.startTimestamp = Date().timeIntervalSince1970
            try handler.perform([request])
        } catch {
            print("Fail inference \(error)")
        }
    }

    // Called after the classifier has been finished
    func pictureClassified(request: VNRequest, error: Error?) {
        print("Inference time \(Int(1000 * (Date().timeIntervalSince1970 - self.startTimestamp))) ms")
        // The model has been created as an image classifier model, so the results should be an
        // array of classifications
        guard let results = request.results as? [VNClassificationObservation] else {
            print("Fail \(String(describing: error))")
            return
        }
        for classification in results {
            // We're interested in the cuteness percentage, so we take the confidence of the
            // observation that has the label "cute", and set up the texts and final evaluation
            if classification.identifier == "cute" {
                let percentage = Int(classification.confidence * 100)
                cutenessPercentageLabel?.text = String(format: NSLocalizedString("CutenessPercentageTextFormat", comment: ""), percentage)
                if classification.confidence < 1.0 / 3.0 {
                    cutenessEvaluationLabel?.text = NSLocalizedString("NotCuteText", comment: "")
                    cutenessEvaluationLabel?.textColor = UIColor.red
                } else if classification.confidence > 2.0 / 3.0 {
                    cutenessEvaluationLabel?.text = NSLocalizedString("CuteText", comment: "")
                    cutenessEvaluationLabel?.textColor = UIColor.green
                } else {
                    cutenessEvaluationLabel?.text = NSLocalizedString("UnsureText", comment: "")
                    cutenessEvaluationLabel?.textColor = UIColor.gray
                }
            }
        }
        setState(.showing)
    }
}
