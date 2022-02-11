

import AVFoundation
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
//        setupAudioSession()
//        enableBuiltInMic()
    }

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            fatalError("Failed to configure and activate session.")
        }
    }

    private func enableBuiltInMic() {
        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()

        // Find the built-in microphone input.
        guard let availableInputs = session.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic })
        else {
            print("The device must have a built-in microphone.")
            return
        }

        // Make the built-in microphone input the preferred input.
        do {
            try session.setPreferredInput(builtInMicInput)
        } catch {
            print("Unable to set the built-in mic as the preferred input.")
        }
    }

    func checkMicAuthorization(andThen f: (() -> Void)?) {
        print("checking mic authorization")
        // different names from all other authorizations, sheesh
        let sess = AVAudioSession.sharedInstance()
        let status = sess.recordPermission
        switch status {
        case .undetermined:
            sess.requestRecordPermission { ok in
                if ok {
                    DispatchQueue.main.async {
                        f?()
                    }
                }
            }
        case .granted:
            f?()
        default:
            print("no microphone")
        }
    }

    @IBAction func doStart(_: Any) {
        checkMicAuthorization(andThen: reallyDoStart)
    }

    var recorder: AVAudioRecorder?
    let recurl: URL = {
        let temp = FileManager.default.temporaryDirectory
        print(temp)
        return temp.appendingPathComponent("rec.m4a")
    }()

    func reallyDoStart() {
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let format = AVAudioFormat(settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 192000,
            AVNumberOfChannelsKey: 2,
        ])
        guard format != nil else { return }
        do {
            print("making recorder")
            let rec = try AVAudioRecorder(url: recurl, format: format!)
            recorder = rec
            rec.delegate = self
            print("recording")
            // let's find out where we are recording thru
            print(AVAudioSession.sharedInstance().currentRoute.inputs)
            rec.record()
        } catch {
            print("oops")
            finishRecorder()
        }
    }

    var player: AVAudioPlayer?

    func finishRecorder() {
        recorder?.stop()
        recorder = nil
    }

    @IBAction func doStop(_: Any) {
        print("stopping")
        finishRecorder()
        print("playing")
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? player = AVAudioPlayer(contentsOf: recurl)
        player?.prepareToPlay()
        player?.play()
        print(player?.format.formatDescription as Any)
    }

    lazy var captureSession = AVCaptureSession()
    let queue = DispatchQueue(label: "AudioSessionQueue", attributes: [])
    let captureDevice = AVCaptureDevice.default(for: AVMediaType.audio)
    var audioInput: AVCaptureDeviceInput?
    var audioOutput: AVCaptureAudioDataOutput?
    let captureUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outputwav.wav")
    }()

    let pcmUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("output.pcm")
    }()

    let mp3Url: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outmp3.mp3")
    }()

    let aacUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outaac.m4a")
    }()

    var captureHandle: FileHandle?
    var pcmHandle: FileHandle?

    var audioData = Data()
    var audioCaptureChannelsMinCount: Int = 0
    var audioCaptureMinSampleRate: Double = AVAudioSession.sharedInstance().sampleRate

    func setupAVCaptureOK() -> Bool {
        // Find the default audio device.
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return false }
        do {
            // Wrap the audio device in a capture device input.
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            self.audioInput = audioInput
            // If the input can be added, add it to the session.
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            } else {
                return false
            }
        } catch {
            // Configuration failed. Handle error.
            return false
        }
        audioOutput = AVCaptureAudioDataOutput()
        if let audioOutput = audioOutput, captureSession.canAddOutput(audioOutput) {
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            captureSession.addOutput(audioOutput)
        } else {
            return false
        }
        try? FileManager.default.removeItem(at: pcmUrl)
        FileManager.default.createFile(atPath: pcmUrl.path, contents: nil, attributes: nil)
        pcmHandle = FileHandle(forWritingAtPath: pcmUrl.path)
        return true
    }

    @IBAction func doStartAVCapture(_: Any) {
        guard setupAVCaptureOK() else {
            // Error, capture session is not yet ready
            return
        }

        try? AVAudioSession.sharedInstance().setPreferredSampleRate(44100)

        audioData.removeAll()
        captureSession.startRunning()
    }

    @IBAction func stopAVCapture(_: Any) {
        if captureSession.isRunning {
            captureSession.stopRunning()
            if let audioInput_ = audioInput {
                captureSession.removeInput(audioInput_)
                audioInput = nil
            }
            if let audioOutput_ = audioOutput {
                captureSession.removeOutput(audioOutput_)
                audioOutput = nil
            }
        }

//        fetchWavFileAndPlay()

//        fetchMp3FileAndPlay()

        fetchAACFileAndPlay()
    }

    private func fetchWavFileAndPlay(needPlay: Bool = false) {
        try? FileManager.default.removeItem(at: captureUrl)
        FileManager.default.createFile(atPath: captureUrl.path, contents: nil, attributes: nil)
        captureHandle = try? FileHandle(forWritingTo: captureUrl)
        if let headerData = WaveEncoder.writeWavFileHeader(totalAudioLength: Int64(audioData.count), totalDataLength: Int64(audioData.count + 36), sampleRate: Int64(audioCaptureMinSampleRate), channels: UInt8(audioCaptureChannelsMinCount), byteRate: Int64(audioCaptureMinSampleRate * Double(audioCaptureChannelsMinCount) * 16 / 8.0)) {
            captureHandle?.write(headerData)
            captureHandle?.write(audioData)
        }
        if needPlay {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            try? player = AVAudioPlayer(contentsOf: captureUrl)
            player?.prepareToPlay()
            player?.play()
        }
    }

    private func fetchMp3FileAndPlay() {
        try? FileManager.default.removeItem(at: mp3Url)
        FileManager.default.createFile(atPath: mp3Url.path, contents: nil, attributes: nil)
        let mp3Encoder = Mp3Encoder(pcmFilePath: pcmUrl.path, mp3FilePath: mp3Url.path, sampleRate: Int32(audioCaptureMinSampleRate), channels: Int32(audioCaptureChannelsMinCount), bitRate: Int32(Int(audioCaptureMinSampleRate) * audioCaptureChannelsMinCount * 16))
        mp3Encoder?.encode()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? player = AVAudioPlayer(contentsOf: mp3Url)
        player?.prepareToPlay()
        player?.play()
    }

    private func fetchAACFileAndPlay() {
        try? FileManager.default.removeItem(at: aacUrl)
        FileManager.default.createFile(atPath: aacUrl.path, contents: nil, attributes: nil)
        if let aacEncoder = FDKAACEncoder(pcmFilePath: pcmUrl.path, aacFilePath: aacUrl.path, sampleRate: Int32(audioCaptureMinSampleRate), channels: AACEncChannel(rawValue: UInt(audioCaptureChannelsMinCount)), bitRate: 64000) {
            aacEncoder.encode()
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            try? player = AVAudioPlayer(contentsOf: aacUrl)
            player?.prepareToPlay()
            player?.play()
        }
    }

    var engine = AVAudioEngine()
    var file: AVAudioFile?
    var playerNode = AVAudioPlayerNode() // Optional
    let engineUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("engineOutput.wav")
    }()

    func prepareAudioOutputFile(for outputURL: URL) -> Bool {
        try? FileManager.default.removeItem(at: outputURL)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        do {
            file = try AVAudioFile(forWriting: outputURL, settings: engine.inputNode.inputFormat(forBus: 0).settings)
        } catch {
            return false
        }

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: engine.mainMixerNode.outputFormat(forBus: 0)) // configure graph
        do {
            try engine.start()
        } catch {
            return false
        }

        // engine.startAndReturnError(nil)
        return true
    }

    @IBAction func startAVEnineRecording(_: Any) {
        guard prepareAudioOutputFile(for: engineUrl) else {
            return
        }
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: engine.mainMixerNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
        }
    }

    @IBAction func stopAVEnineRecording(_: Any) {
        let sampleRate = engine.inputNode.inputFormat(forBus: 0).sampleRate
        let channelCount = engine.inputNode.inputFormat(forBus: 0).channelCount
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let handle = try? FileHandle(forUpdating: engineUrl) {
            handle.seek(toFileOffset: 0)
            let audioData = handle.readDataToEndOfFile()
            if let headerData = WaveEncoder.writeWavFileHeader(totalAudioLength: Int64(audioData.count), totalDataLength: Int64(audioData.count + 36), sampleRate: Int64(sampleRate), channels: UInt8(channelCount), byteRate: Int64(sampleRate * Double(channelCount) * 16 / 8.0)) {
                handle.truncateFile(atOffset: 0)
                handle.write(headerData)
                handle.write(audioData)

                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                try? player = AVAudioPlayer(contentsOf: engineUrl)
                player?.prepareToPlay()
                player?.play()
            }
        }
    }
}

extension ViewController: AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func audioRecorderDidFinishRecording(_: AVAudioRecorder, successfully _: Bool) {
        //
    }

    /* if an error occurs while encoding it will be reported to the delegate. */
    func audioRecorderEncodeErrorDidOccur(_: AVAudioRecorder, error _: Error?) {
        //
    }

    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection.audioChannels.count < audioCaptureChannelsMinCount || audioCaptureChannelsMinCount == 0 {
            audioCaptureChannelsMinCount = connection.audioChannels.count
        }
        print(sampleBuffer)
        let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
        print("######", AVAudioSession.sharedInstance().sampleRate, AVAudioSession.sharedInstance().inputNumberOfChannels, AVAudioSession.sharedInstance().outputNumberOfChannels, desc?.audioChannelLayout?.numberOfChannels ?? 0)

        if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let blockBufferLength = CMBlockBufferGetDataLength(blockBuffer)
            var blockBufferData = [UInt8](repeating: 0, count: blockBufferLength)
            let status = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: blockBufferLength, destination: &blockBufferData)
            if status == noErr {
                let data = Data(bytes: blockBufferData, count: blockBufferLength)
                audioData.append(data)
                pcmHandle?.write(data)
            }
        }
    }
}
