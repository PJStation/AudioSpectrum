//
// AudioSpectrum02
// A demo project for blog: https://juejin.im/post/5c1bbec66fb9a049cb18b64c
// Created by: potato04 on 2019/1/30
//

import Foundation
import AVFoundation
import Accelerate

class RealtimeAnalyzer {
    private var fftSize: Int
    private lazy var fftSetup = vDSP_create_fftsetup(vDSP_Length(Int(round(log2(Double(fftSize))))), FFTRadix(kFFTRadix2))
    
    public var frequencyBands: Int = 60 //频带数量
    public var startFrequency: Float = 20 //起始频率
    public var endFrequency: Float = 22000 //截止频率
    
    private lazy var bands: [(lowerFrequency: Float, upperFrequency: Float)] = {
        var bands = [(lowerFrequency: Float, upperFrequency: Float)]()
        //1：根据起止频谱、频带数量确定增长的倍数：2^n
        let n = log2(endFrequency/startFrequency) / Float(frequencyBands)
        var nextBand: (lowerFrequency: Float, upperFrequency: Float) = (startFrequency, 0)
        for i in 1...frequencyBands {
            //2：频带的上频点是下频点的2^n倍
            let highFrequency = nextBand.lowerFrequency * powf(2, n)
            //下一个频带的下频点是上一个的高频点，依次递增
            nextBand.upperFrequency = i == frequencyBands ? endFrequency : highFrequency
            bands.append(nextBand)
            nextBand.lowerFrequency = highFrequency
        }
        return bands
    }()
    
    private var spectrumBuffer = [[Float]]()
    public var spectrumSmooth: Float = 0.5 {
        didSet {
            spectrumSmooth = max(0.0, spectrumSmooth)
            spectrumSmooth = min(1.0, spectrumSmooth)
        }
    }

    init(fftSize: Int) {
        self.fftSize = fftSize
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func analyse(with buffer: AVAudioPCMBuffer) -> [[Float]] {
        let channelsAmplitudes = fft(buffer)
        let aWeights = createFrequencyWeights()
        if spectrumBuffer.count == 0 {
            for _ in 0..<channelsAmplitudes.count {
                spectrumBuffer.append(Array<Float>(repeating: 0, count: bands.count))
            }
        }
        for (index, amplitudes) in channelsAmplitudes.enumerated() {
            let weightedAmplitudes = amplitudes.enumerated().map {(index, element) in
                return element * aWeights[index]
            }

            var spectrum:[Float] = bands.map {
//                var maxAmplitude = findMaxAmplitude(for: $0, in: amplitudes, with: Float(buffer.format.sampleRate)  / Float(self.fftSize))
                var maxAmplitude = findMaxAmplitude(for: $0, in: weightedAmplitudes, with: Float(buffer.format.sampleRate)  / Float(self.fftSize))
                maxAmplitude = maxAmplitude * 3
                return maxAmplitude
//                findMaxAmplitude(for: $0, in: weightedAmplitudes, with: Float(buffer.format.sampleRate)  / Float(self.fftSize))*5
            }
            
//            var one: Float32 = 1
//            var c = [Float](repeating: 0, count: spectrum.count)
//            vDSP_vdbcon(spectrum, 1, &one, &spectrum, 1, vDSP_Length(spectrum.count), 1)
//            var addvalue:Float = 74
//            vDSP_vsadd(spectrum, 1, &addvalue, &spectrum, 1, vDSP_Length(spectrum.count))
//            var scale:Float = 1.0/128; //256.f / frameCount;
//            vDSP_vsmul(spectrum, 1, &scale, &spectrum, 1, vDSP_Length(spectrum.count));
//            for (i,item) in spectrum.enumerated() {
//                print("item:\(item)")
//            }
            
            spectrum = highlightWaveform(spectrum: spectrum)
            spectrumBuffer[index] = spectrum

            let zipped = zip(spectrumBuffer[index], spectrum)
            spectrumBuffer[index] = zipped.map { $0.0 * spectrumSmooth + $0.1 * (1 - spectrumSmooth) }

  
            
//            let weightedAmplitudes = amplitudes.enumerated().map {(index, element) in
//                return element
//            }
////            var spectrum2 = bands.map {
////                findMaxAmplitude(for: $0, in: weightedAmplitudes, with: Float(buffer.format.sampleRate)  / Float(self.fftSize))
////            }
//            var spectrum2 = weightedAmplitudes
//
//            var one: Float32 = 1
//            var c = [Float](repeating: 0, count: 80)
//
//
////            var addvalue:Float = 1.5849e-13;
////            vDSP_vsadd(spectrum2, 1, &addvalue, &c, 1, 80);
//
//            vDSP_vdbcon(spectrum2, 1, &one, &c, 1, 80, 1)
////            var min:Float = 0.0
////            var minIndex:vDSP_Length = 0
////            vDSP_minvi(c, 1, &min, &minIndex, 80);
////            print("min:\(min)")
//
//
//            var addvalue:Float = 85;
//            vDSP_vsadd(c, 1, &addvalue, &c, 1, 80);
//
//            var scale:Float = 1/128
//            vDSP_vsmul(c, 1, &scale, &c, 1, 80)
//
//
//            c = highlightWaveform(spectrum: c)
//
//            spectrumBuffer[index] = c
//            let zipped = zip(spectrumBuffer[index], c)
//            spectrumBuffer[index] = zipped.map { $0.0 * spectrumSmooth + $0.1 * (1 - spectrumSmooth) }

        }
        return spectrumBuffer
    }
    
    private func fft(_ buffer: AVAudioPCMBuffer) -> [[Float]] {
        var amplitudes = [[Float]]()
        guard let floatChannelData = buffer.floatChannelData else { return amplitudes }
        
        //1：抽取buffer中的样本数据
        var channels: UnsafePointer<UnsafeMutablePointer<Float>> = floatChannelData
        let channelCount = Int(buffer.format.channelCount)
        let isInterleaved = buffer.format.isInterleaved
        
        if isInterleaved {
            // deinterleave
            let interleavedData = UnsafeBufferPointer(start: floatChannelData[0], count: self.fftSize * channelCount)
            var channelsTemp : [UnsafeMutablePointer<Float>] = []
            for i in 0..<channelCount {
                var channelData = stride(from: i, to: interleavedData.count, by: channelCount).map{ interleavedData[$0] }
                channelsTemp.append(UnsafeMutablePointer(&channelData))
            }
            channels = UnsafePointer(channelsTemp)
        }
        
        for i in 0..<channelCount {
            
            let channel = channels[i]
            //2: 加汉宁窗
            var window = [Float](repeating: 0, count: Int(fftSize))
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(channel, 1, window, 1, channel, 1, vDSP_Length(fftSize))
            
            //3: 将实数包装成FFT要求的复数fftInOut，既是输入也是输出
            var realp = [Float](repeating: 0.0, count: Int(fftSize / 2))
            var imagp = [Float](repeating: 0.0, count: Int(fftSize / 2))
            var fftInOut = DSPSplitComplex(realp: &realp, imagp: &imagp)
            channel.withMemoryRebound(to: DSPComplex.self, capacity: fftSize) { (typeConvertedTransferBuffer) -> Void in
                vDSP_ctoz(typeConvertedTransferBuffer, 2, &fftInOut, 1, vDSP_Length(fftSize / 2))
            }
            
            //4：执行FFT
            vDSP_fft_zrip(fftSetup!, &fftInOut, 1, vDSP_Length(round(log2(Double(fftSize)))), FFTDirection(FFT_FORWARD));
            
            //5：调整FFT结果，计算振幅
            fftInOut.imagp[0] = 0
            let fftNormFactor = Float(1.0 / (Float(fftSize)))
            vDSP_vsmul(fftInOut.realp, 1, [fftNormFactor], fftInOut.realp, 1, vDSP_Length(fftSize / 2));
            vDSP_vsmul(fftInOut.imagp, 1, [fftNormFactor], fftInOut.imagp, 1, vDSP_Length(fftSize / 2));
            var channelAmplitudes = [Float](repeating: 0.0, count: Int(fftSize / 2))
            vDSP_zvabs(&fftInOut, 1, &channelAmplitudes, 1, vDSP_Length(fftSize / 2));
//            vDSP_zvmags(&fftInOut, 1, &channelAmplitudes, 1, vDSP_Length(fftSize / 2));

            channelAmplitudes[0] = channelAmplitudes[0] / 2 //直流分量的振幅需要再除以2
            amplitudes.append(channelAmplitudes)
        }
        return amplitudes
    }
    
    private func findMaxAmplitude(for band:(lowerFrequency: Float, upperFrequency: Float), in amplitudes: [Float], with bandWidth: Float) -> Float {
//        let a = 44100/1024
//        let b = a/
        let startIndex = Int(round(band.lowerFrequency / bandWidth))
        let endIndex = min(Int(round(band.upperFrequency / bandWidth)), amplitudes.count - 1)
//        print("startIndex:\(startIndex) endIndex:\(endIndex)")
        return amplitudes[startIndex...endIndex].max()!
    }
    
    private func createFrequencyWeights() -> [Float] {
        let Δf = 44100.0 / Float(fftSize)
        let bins = fftSize / 2
        var f = (0..<bins).map { Float($0) * Δf}
        f = f.map { $0 * $0 }
        
        let c1 = powf(12194.217, 2.0)
        let c2 = powf(20.598997, 2.0)
        let c3 = powf(107.65265, 2.0)
        let c4 = powf(737.86223, 2.0)
        
        let num = f.map { c1 * $0 * $0 }
        let den = f.map { ($0 + c2) * sqrtf(($0 + c3) * ($0 + c4)) * ($0 + c1) }
        let weights = num.enumerated().map { (index, ele) in
            return 1.2589 * ele / den[index]
        }
        return weights
    }
    
    private func highlightWaveform(spectrum: [Float]) -> [Float] {
        //1: 定义权重数组，数组中间的5表示自己的权重
        //   可以随意修改，个数需要奇数
//        let weights: [Float] = [1, 2, 3, 5, 3, 2, 1]
//        let totalWeights = Float(weights.reduce(0, +))
//        let startIndex = weights.count / 2
//        //2: 开头几个不参与计算
//        var averagedSpectrum = Array(spectrum[0..<startIndex])
//        for i in startIndex..<spectrum.count - startIndex {
//            //3: zip作用: zip([a,b,c], [x,y,z]) -> [(a,x), (b,y), (c,z)]
//            let zipped = zip(Array(spectrum[i - startIndex...i + startIndex]), weights)
//            let averaged = zipped.map { $0.0 * $0.1 }.reduce(0, +) / totalWeights
//            averagedSpectrum.append(averaged)
//        }
//        //4：末尾几个不参与计算
//        averagedSpectrum.append(contentsOf: Array(spectrum.suffix(startIndex)))
//        return averagedSpectrum

        //        let filter: [Float] = [0.1, 0.2, 0.3, 0.5, 0.3, 0.2, 0.1]
        //        let filter: [Float] = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,0.1,0.1,0.1]
        //        let filter: [Float] = [0.05, 0.2, 0.5, 0.2, 0.05]
        let filter: [Float] = [1, 2, 3, 5, 3, 2, 1]
        let outputCount = spectrum.count - filter.count + 1
        var correlationResult = [Float](repeating: 0.0, count: outputCount)


        var signal = spectrum
//        signal.removeSubrange(0..<3)
        vDSP_conv(signal, 1, filter, 1, &correlationResult, 1, vDSP_Length(outputCount), vDSP_Length(filter.count))
//        vDSP_desamp(
//            samples,
//            vDSP_Stride(strideLength),
//            filter,
//            &downSampledData,
//            vDSP_Length(sampleCount),
//            vDSP_Length(strideLength)
//        )
        var scale = 1/Float(filter.reduce(0, +))
        var c = [Float](repeating: 0, count: outputCount)
        vDSP_vsmul(correlationResult, 1, &scale, &c, 1, vDSP_Length(correlationResult.count))
        for _ in 0..<3{
            c.insert(0, at: 0)
            c.append(0)
        }
        return c
        
    }
    
}
