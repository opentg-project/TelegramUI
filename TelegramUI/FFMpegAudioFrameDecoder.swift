import Foundation
import CoreMedia
import FFMpeg

final class FFMpegAudioFrameDecoder: MediaTrackFrameDecoder {
    private let codecContext: FFMpegAVCodecContext
    private let swrContext: FFMpegSWResample
    
    private let audioFrame: FFMpegAVFrame
    private var resetDecoderOnNextFrame = true
    
    init(codecContext: FFMpegAVCodecContext) {
        self.codecContext = codecContext
        self.audioFrame = FFMpegAVFrame()
        
        self.swrContext = FFMpegSWResample(sourceChannelCount: Int(codecContext.channels()), sourceSampleRate: Int(codecContext.sampleRate()), sourceSampleFormat: codecContext.sampleFormat(), destinationChannelCount: 2, destinationSampleRate: 44100, destinationSampleFormat: FFMPEG_AV_SAMPLE_FMT_S16)
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            if self.codecContext.receive(into: self.audioFrame) {
                return convertAudioFrame(self.audioFrame, pts: frame.pts, duration: frame.duration)
            }
        }
        
        return nil
    }
    
    func takeRemainingFrame() -> MediaTrackFrame? {
        return nil
    }
    
    private func convertAudioFrame(_ frame: FFMpegAVFrame, pts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        guard let data = self.swrContext.resample(frame) else {
            return nil
        }
        
        var blockBuffer: CMBlockBuffer?
        
        let bytes = malloc(data.count)!
        data.copyBytes(to: bytes.assumingMemoryBound(to: UInt8.self), count: data.count)
        let status = CMBlockBufferCreateWithMemoryBlock(nil, bytes, data.count, nil, nil, 0, data.count, 0, &blockBuffer)
        if status != noErr {
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: pts)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = data.count
        guard CMSampleBufferCreate(nil, blockBuffer, true, nil, nil, nil, 1, 1, &timingInfo, 1, &sampleSize, &sampleBuffer) == noErr else {
            return nil
        }
        
        let resetDecoder = self.resetDecoderOnNextFrame
        self.resetDecoderOnNextFrame = false
        
        return MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: true)
    }
    
    func reset() {
        self.codecContext.flushBuffers()
        self.resetDecoderOnNextFrame = true
    }
}
