//
//  BLoopManager.swift
//  BLoop
//
//  Created by Sloven Graciet on 10/03/2020.
//  Copyright © 2020 Sloven Graciet. All rights reserved.
//

import Foundation
import AudioKit
import Combine

enum LoopLengthMode {
    case Auto
}

protocol TrackAudioEngineDelegate: AnyObject {
    func setRecordDuration(_ seconds: Double)
    func getCurrentTimeMasterPlayer() -> Double?
 //   func getRemainingTimeTempoMaster() -> Double
    func getTempo() -> Double
    func getMetric() -> Int
    func didStartRecord() -> Void
}

class BLoopManager: ObservableObject {
    
    private enum Constants {
        static let nbTracks = 5
    }
    
    var mic = Microphone()
    var inputMixer = Mixer()
    var mainMixer = AKMixer()
    var monoToStereo: AKStereoFieldLimiter?
    
    var metronome = AKMetronome()
    var metronomeMixer = AKMixer()
    var tracksAudioEngine = [TrackAudioEngine]()
    
    
    private var masterTempo = 60.00
    private var metricTempo = 4
    private var loopLengthMode: LoopLengthMode = .Auto
    var loopLengthInSecond: Double?
    
    
    //tickbeat: 0 first beat , 1 others beats
    @Published var tickBeat: Int = 0
    @Published var isTicking: Bool = false

    // use when track settings Sync player will be done
    private var TracksSyncPlayers: [Int : Bool] = Dictionary(uniqueKeysWithValues: Array(0...Constants.nbTracks).map{ ($0, true)})

    init() {
        setupAudio()
        setupInputMixer()
        setupMetronome()
        setupTracksAudioEngine()
        
        do {
            try AKManager.start()
        } catch  {
            AKLog(error.localizedDescription)
        }
        
        metronome.start()

    }
    	
    private func setupAudio() {
        FileManager.emtpyDocumentsDirectory()
        
        do {
            AKSettings.audioInputEnabled = true
            AKSettings.defaultToSpeaker = true
            AKSettings.sampleRate = AKManager.engine.inputNode.inputFormat(forBus: 0).sampleRate
            
            try AKSettings.setSession(category: .playAndRecord)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        self.monoToStereo = AKStereoFieldLimiter(mic,amount: 2)
        AKManager.output = mainMixer
    }
    
    private func setupInputMixer() {
        guard let monoToStereo = monoToStereo else {
            AKLog("cant get monoToStereo fieldLimiter")
            return
        }
        
        // connect mic monoToStereo to InputMixer which will get all InputEffect
        monoToStereo.connect(to: self.inputMixer.inputNode)
        
        // connect inputMixer to Output
        self.inputMixer.outputNode.connect(to: self.mainMixer.inputNode)
    }
    
    private func setupTracksAudioEngine() {
        
        for i in 0..<Constants.nbTracks {
            let trackAudioEngine = TrackAudioEngine(inputNode: inputMixer, mainMixer: self.mainMixer, name: "track\(i)")
            trackAudioEngine.trackDelegate = self
            tracksAudioEngine.append(trackAudioEngine)
        }
    }
    
    private func setupMetronome() {
        
        let sampleMetronomeMixer = AKMixer()
        sampleMetronomeMixer.volume = 0.5
        sampleMetronomeMixer >>> mainMixer
        
        metronome.tempo = self.masterTempo
        
        metronome.subdivision = self.metricTempo
        
        metronome.connect(to: self.metronomeMixer.inputNode)
        metronomeMixer.connect(to: self.mainMixer.inputNode)
        
        //mute metronome
        metronomeMixer.volume = 0.5
                
        self.metronome.callback = {
            let currentBeat = self.metronome.currentBeat
            
            print(currentBeat)

            print(self.metronome.currentBeat)
//            print("metronome :sub:\(self.metronome.subdivision) tempo:\(self.metronome.tempo)")
//            print("samplemetronome :sub:\(self.sampleMetronome.beatCount) tempo:\(self.sampleMetronome.tempo): time: \(self.sampleMetronome.beatTime)")

            DispatchQueue.main.async {
                self.isTicking = true
                self.tickBeat = currentBeat == 1 ? 0 : 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isTicking = false
            }
        }
    }
    
    public func stopAll() {
        tracksAudioEngine.forEach{
            $0.player.stop()
        }
    }
    
    public func startAll() {
        tracksAudioEngine.forEach{
            if let _ = $0.player.audioFile {
                $0.player.prepare()
            }
        }
        let playbackStartTime = getNextPlaybackStartTime()
        
        tracksAudioEngine.forEach{
            if let _  = $0.player.audioFile {
                $0.player.play(at: playbackStartTime)
            }
        }
    }
    
    private func getNextPlaybackStartTime() -> AVAudioTime {
        
        //cf LoopbackRecording of audioKit
        guard let lastRenderHostTime = mainMixer.avAudioNode.lastRenderTime?.hostTime else {
            fatalError("Engine not running")
        }
        
        let audioSession = AKSettings.session
        let bufferDurationTicks = UInt64(audioSession.ioBufferDuration * secondsToTicks)
        let outputLatencyTicks = UInt64(audioSession.outputLatency * secondsToTicks)
        
        let nextRenderHostTime = lastRenderHostTime + bufferDurationTicks
        let renderAfterNextHostTime = nextRenderHostTime + bufferDurationTicks
        
        let startTimeHost = renderAfterNextHostTime + outputLatencyTicks
        let playbackStartTime = AVAudioTime(hostTime: startTimeHost - outputLatencyTicks)
        
        return playbackStartTime
    }
}

extension BLoopManager: TrackAudioEngineDelegate {
    func getMetric() -> Int {
        return self.metricTempo
    }
    
    
    func getTempo() -> Double {
        return self.masterTempo
    }
    
//    func getRemainingTimeTempoMaster() -> Double {
//
//        // 1 measure = 60 / bpm * time signature
//        let duration = 60 / metronome.tempo * metronome.subdivision
//        print("duration = \(duration)")
//
//        let currentTime = sampleMetronome.beatTime
//        print("remaining = \(duration - currentTime)")
//        return duration - currentTime
//    }
    
    
    public func getCurrentTimeMasterPlayer() -> Double? {
        var currentTime: Double?
        
        for audioEngine in tracksAudioEngine {
            if audioEngine.player.isPlaying {
                currentTime = audioEngine.player.currentTime
           //     print("player current Time :\(currentTime)")
                break
            }
        }
        return currentTime
    }
    
    func setRecordDuration(_ seconds: Double) {
        self.loopLengthInSecond = seconds
        
        tracksAudioEngine.forEach{ audioEngine in
            DispatchQueue.main.async {
                audioEngine.recordDuration = self.loopLengthInSecond
            }
        }
    }
    
    func didStartRecord() {
        if self.loopLengthInSecond == nil {
            metronome.restart()
        }
    }
}


// Utility to convert between hostTime (ticks) and seconds.
public let secondsToTicks: Double = {
    var tinfo = mach_timebase_info()
    let err = mach_timebase_info(&tinfo)
    let timecon = Double(tinfo.denom) / Double(tinfo.numer)
    return timecon * 1_000_000_000
}()
