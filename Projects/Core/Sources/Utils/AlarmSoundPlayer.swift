import AVFoundation

// 풀스크린 알람(ZFXjS)용 루핑 사운드.
// 에셋 파일 없이 880Hz 비프패턴(삐-삐-) WAV를 코드로 합성해 AVAudioPlayer로 무한 재생한다.
// AVAudioSession.playback으로 설정해 무음 모드(사일런트 스위치)에서도 울린다.
public final class AlarmSoundPlayer {

    public static let shared = AlarmSoundPlayer()

    private var player: AVAudioPlayer?
    private let url: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("care_alarm.wav")
    }()

    public func start() {
        // 이미 재생 중이면 무시 — evaluate가 반복 호출해도 루프가 끊기지 않도록.
        if let player, player.isPlaying { return }
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        guard let fileURL = try? AlarmTone.write(to: url) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: fileURL)
            p.numberOfLoops = -1
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
        }
    }

    public func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - 1초 비프톤 WAV 합성

public enum AlarmTone {

    /// 1초 길이의 "삐- 삐-" 패턴(880Hz)을 WAV로 만들어 `url`에 쓰고 반환한다.
    public static func write(to url: URL) throws -> URL {
        let sampleRate: Double = 44100
        let total = Int(sampleRate * 1.0)
        var samples = [Int16](repeating: 0, count: total)

        var i = 0
        var on = true
        while i < total {
            let seg = on ? Int(sampleRate * 0.18) : Int(sampleRate * 0.12)
            if on {
                for j in 0..<seg where i + j < total {
                    let t = Double(j) / sampleRate
                    // 부드러운 시작/끝을 위해 코사인 엔벨로프 적용
                    let env = (1 - cos(2 * .pi * Double(j) / Double(seg))) / 2
                    let v = sin(2 * .pi * 880 * t) * 0.6 * env
                    samples[i + j] = Int16(v * Double(Int16.max))
                }
            }
            i += seg
            on.toggle()
        }

        var data = Data()
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(total * Int(bitsPerSample / 8))
        data.append("RIFF".ascii); data.append(uint32(36 + dataSize)); data.append("WAVE".ascii)
        data.append("fmt ".ascii); data.append(uint32(16)); data.append(uint16(1)) // PCM
        data.append(uint16(numChannels)); data.append(uint32(UInt32(sampleRate)))
        data.append(uint32(UInt32(sampleRate) * UInt32(numChannels * bitsPerSample / 8)))
        data.append(uint16(numChannels * bitsPerSample / 8)); data.append(uint16(bitsPerSample))
        data.append("data".ascii); data.append(uint32(dataSize))
        for s in samples { data.append(uint16(UInt16(bitPattern: s))) }

        try data.write(to: url)
        return url
    }

    private static func uint32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)])
    }
    private static func uint16(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff)])
    }
}

private extension String {
    /// ASCII 바이트 Data — WAV 헤더 청크 ID용
    var ascii: Data { data(using: .ascii) ?? Data() }
}
