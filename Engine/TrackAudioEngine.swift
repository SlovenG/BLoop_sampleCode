//
//  AudioEngine.swift
//  BLoop
//
//  Created by Sloven Graciet on 25/02/2020.
//  Copyright © 2020 Sloven Graciet. All rights reserved.
//

import Foundation
import AudioKit
import Combine


enum RecorderState: String {
    case readyToRecord
    case recording
    case readyToPlay
    case playing
    case overdub
    case waitingMasterLoop	
}

class TrackAudioEngine: ObservableObject {
    
    private enum Constants {
        static let maxRecordDuration: Double = 30
    }
    
    private enum CurrentTape {
        case first
        case second
    }
    
    @Published var recorderState: RecorderState = .readyToRecord
    @Published var recordDuration: Double?
    
    weak var trackDelegate: TrackAudioEngineDelegate?
    
    var name: String
    var currentRecord = 0
    var overdubIsLooping = true
    
    var player = AKPlayer()
    var nonLoopPlayer = AKPlayer()
    
    var recorderMixer: AKMixer!
    var playerMixer: AKMixer!
    var outputMixer: AKMixer!
    var clipRecorder: AKClipRecorder!
    
    var inputNode: AKNode!
    var inputMixer: AKMixer!
    var mainMixer: AKMixer!
    var isMute: Bool
    var isLooping: Bool = true
    
    var micMixer = AKMixer()
    
    private var currentTape: CurrentTape = .first
    private var tapeChanged = false
    private var isStoppingOverdub = false
    
    @Published var outputReverb = AKReverb()
    @Published var outputDelay = AKDelay()
    @Published var outputPitch = AKPitchShifter()
    
    var isTempoSync: Bool = true
    var tempo: Double {
        get {
            trackDelegate?.getTempo() ?? 60
        }
    }
    
    var metric: Int {
        get {
            trackDelegate?.getMetric() ?? 4
        }
    }
    
    private var realMeasureTime: Double?
 
    init(inputNode: AKNode, mainMixer: AKMixer, name: String, isMute: Bool = true) {
        self.inputNode = inputNode
        self.mainMixer = mainMixer
        self.name = name
        self.isMute = isMute
        setupAudio()
    }
    
    private func setupAudio() {
        
        inputMixer = AKMixer(inputNode)
                
        playerMixer = AKMixer()
        recorderMixer = AKMixer([inputMixer,playerMixer])
        outputMixer = AKMixer(playerMixer)
        
        //avoid crash on iphone
        let muteMixer = AKMixer(recorderMixer)
                
        // avoid weird play of player
        player.buffering = .always
        player.isLooping = true
        
        player.connect(to: playerMixer.inputNode)
        nonLoopPlayer.connect(to: playerMixer.inputNode)
        
        // setupOutputEffect()
        outputMixer.connect(to: mainMixer.inputNode)
        clipRecorder = AKClipRecorder(node: recorderMixer)
        
        nonLoopPlayer.completionHandler =  {
            self.player.play()
        }
    }
    
    func setupOutputEffect() {
        
        recorderMixer.connect(to: outputPitch.inputNode)
        outputPitch.connect(to: outputDelay.inputNode)
        outputDelay.connect(to: outputReverb.inputNode)
        outputReverb.connect(to: outputMixer.inputNode)
        
        outputPitch.shift = 0
        outputDelay.dryWetMix = 0
        outputReverb.dryWetMix = 0
        
     }
    
    func record() {
        
        print("recorder state = \(recorderState)")
        trackDelegate?.didStartRecord()
        
        DispatchQueue.main.async {
            if self.recorderState != .overdub {
                self.recorderState = .recording
            }
        }
        
        clipRecorder.currentTime = 0
        let durationRecord = self.recordDuration == nil ? Constants.maxRecordDuration : self.recordDuration!
        
        try? clipRecorder.recordClip(time: 0, duration: durationRecord, tap: nil, completion: { (result) in
            switch result {
            case .error(let error):
                AKLog(error.localizedDescription)
                return
            case .clip(let clip):
                do {
                    let urlInDocs = FileManager.docs.appendingPathComponent("loopback\(self.name):\(self.currentTape == .first ? 1 : 2)").appendingPathExtension(clip.url.pathExtension)
                    
//                   check is stop overdubbing
//                    if self.isStoppingOverdub {
//                        self.isStoppingOverdub = false
//                        return
//                    } else {
//                        self.switchCurrentTape()
//                    }
                    
                    try FileManager.default.moveItem(at: clip.url, to: urlInDocs)
                    AKLog("loopback saved at " + urlInDocs.path)
                    
                    print("clipDuration:\(clip.duration) currentTimeRecorder = \(self.clipRecorder.currentTime)")
                    let audioFile = try AKAudioFile(forReading: urlInDocs)
                    
                    if self.recordDuration == nil {
                        if let realMeasureTime = self.realMeasureTime {
                            self.trackDelegate?.setRecordDuration(realMeasureTime)
                        } else {
                            self.trackDelegate?.setRecordDuration(clip.duration)
                        }
                        
                    }
               
                    try? self.player.load(audioFile: audioFile)
                    try? self.nonLoopPlayer.load(audioFile: audioFile)
                
                    if self.tapeChanged {
                        self.tapeChanged = false
                    }
                    
                    if self.recorderState == .recording || self.recorderState == .overdub && !self.isStoppingOverdub {
                        self.overdub()
                    } else {
                        if self.isStoppingOverdub {
                            self.isStoppingOverdub = false
                        }
                        self.play()
                    }
                } catch  {
                    AKLog(error)
                }
            }
        })
        clipRecorder.start()
    }
    
    func stopRecord() {
        
        // cant stop record if recordDuration is already set
        if let _ = self.recordDuration {
            return
        }
        
        //Quantize : calculate the real time the recorder should stop
        // ex: currentTime = 3.6 / Bpm = 90 metr = 4/4  --> 60/Bpm * metrique = 60 / 90 * 4 = 2.666
        let realMeasureTime =  quantizeEndRecord()
        self.realMeasureTime = realMeasureTime
        
        print("rm: \(realMeasureTime) cr:\(clipRecorder.currentTime)")

        if clipRecorder.currentTime < realMeasureTime {
            clipRecorder.stopRecording(endTime: realMeasureTime, nil)
        } else {
            clipRecorder.stopRecording(endTime: nil, nil)
        }
    }
    
     func quantizeEndRecord() -> Double {
        let currentTime = clipRecorder.currentTime // 2.1
        
        let measureTime = 60 / self.tempo * self.metric// 0.66
        
        let roundedMeasure = (currentTime / measureTime).rounded() // 1
        
        let realMeasureTime = roundedMeasure * measureTime
        
        (print("realMeasureTime: \(realMeasureTime)"))
        return realMeasureTime
    }
    
    func muteInputMixer() {
        self.inputMixer.volume = 0
    }
    
    func unMuteInputMixer() {
        self.inputMixer.volume = 1
    }
   
    // check and wait for next master loop if one loop is playing
    func checkIfWaitingLoop() -> Double? {
    
        var remainingTime: Double?

        // if recordDuration is already set, it means a loop is already set
        if let recordDuration = self.recordDuration, let currentPlayerTime = trackDelegate?.getCurrentTimeMasterPlayer() {
            remainingTime = recordDuration - currentPlayerTime
        }
        return remainingTime
    }
    
    func recordIfAllowed() {
        
        let remainingTime = self.checkIfWaitingLoop()
        
        if let remainingTime = remainingTime {
            //change recorderState
            DispatchQueue.main.async {
                self.recorderState = .waitingMasterLoop
            }
            
            // wait until remaining time is passed
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                self.record()
            }
        } else {
            self.record()
        }
    }
    
    func overdubIfAllowed() {
        if isStoppingOverdub {
            self.overdub()
            return
        }
        
        let remainingTime = self.checkIfWaitingLoop()
        
        if let remainingTime = remainingTime {
            //change recorderState
            DispatchQueue.main.async {
                self.recorderState = .waitingMasterLoop
            }
            
            // wait until remaining time is passed
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                self.overdub()
            }
        } else {
            self.overdub()
        }
    }
    
    func overdub() {
        
        unMuteInputMixer()

        // play and record
        DispatchQueue.main.async {
            self.recorderState = .overdub
        }
        
        if isStoppingOverdub {
            return
        }
        
        self.play()
        // switch and remove old tape
        self.switchCurrentTape()
        // record
        self.record()
    }
    
    func stopOverdub() {
        self.isStoppingOverdub = true
        muteInputMixer()
        
//        clipRecorder.stopRecording(endTime: nil) {
//            self.recorderState = .playing
//        }
        DispatchQueue.main.async {
            self.recorderState = .playing
        }
    }
    
    func switchCurrentTape() {
        // remove the second tape
        removeOldTape()
        
        // setting currentTape
        currentTape = currentTape == .first ? .second : .first
        tapeChanged = true
    }
    
    func play() {
        // implement latency output input to synchronize players and recorder
        
        DispatchQueue.main.async {
            if self.recorderState != .overdub {
                self.recorderState = .playing
            }
        }
        
        // get time of current player playing
        let currentPlayerTime = trackDelegate?.getCurrentTimeMasterPlayer()
        print("current time player---->: \(currentPlayerTime)")
        
        //if realMeasure is different to audiofile.duration play to endtime = realMeasure
        if let realMeasure = self.realMeasureTime, let duration = player.audioFile?.duration, realMeasure < duration && self.recordDuration == nil{
            print("play to: \(realMeasure)")

            if let currentPlayerTime = currentPlayerTime , currentPlayerTime != 0.00{
                self.nonLoopPlayer.play(from: currentPlayerTime, to: realMeasure)
            } else {
                self.player.play(from: 0, to: realMeasure)
            }
        }
        
        if let currentPlayerTime = currentPlayerTime , currentPlayerTime != 0.00{
            self.nonLoopPlayer.play(from: currentPlayerTime)
        } else {
            self.player.play()
        }
        print("player isPlaying \(player.isPlaying)")
    }
    
    func stopPlayer() {
        print("player Stop")
        player.stop()
        
        DispatchQueue.main.async {
            self.recorderState = .readyToPlay
        }
    }
    
    internal func removeOldTape() {
        let removedNumber = self.currentTape == .first ? 2 : 1
        let removedFileName = "loopback\(self.name):\(removedNumber).caf"
        print("removed" + removedFileName)
        FileManager.removeFile(fileName: removedFileName)
       }
}
