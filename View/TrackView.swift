//
//  ContentView.swift
//  BLoop
//
//  Created by Sloven Graciet on 24/02/2020.
//  Copyright © 2020 Sloven Graciet. All rights reserved.
//

import SwiftUI
import AudioKit


struct TrackView: View {
    
    @EnvironmentObject var bloopManager: BLoopManager
    @EnvironmentObject var audioEngine: TrackAudioEngine
    
    
    var body: some View {
        
        let stopButton = PrimaryButton(action: {
            self.didTapStopButton()
        }) {
            Image(systemName: "stop.fill")
        }
        .frame(width: 50, height: 50)
        
        let editButton = PrimaryButton(action: {}) {
            Image(systemName: "gear")
        }
        .frame(width: 50, height: 50)
        
        return VStack {
           
         //   effectsView(reverb: $audioEngine.reverb, delay: $audioEngine.delay, pitch: $audioEngine.pitch)
         //   effectsView(reverb: $audioEngine.outputReverb, delay: $audioEngine.outputDelay, pitch: $audioEngine.outputPitch)
            HStack {
                VStack {
                    editButton
                    stopButton
                }
                Slider(value: $audioEngine.outputMixer.volume, in: 0...1, step: 0.05)
                    .rotationEffect(.degrees(-90))
            }
           
            TrackButton().onTapGesture {
                           self.didTap()
                       }.padding(5)
        }
    }
    
    func didTapStopButton() {
        audioEngine.stopPlayer()
    }
    
    func didTap() {
        let state = self.audioEngine.recorderState
        
        switch state {
        case .readyToRecord:
            audioEngine.recordIfAllowed()
        case .recording:
            audioEngine.stopRecord()
        case .overdub:
            audioEngine.stopOverdub()
        case .readyToPlay:
            audioEngine.play()
        case .playing:
            audioEngine.overdubIfAllowed()
        default:
            return
        }
    }
}

