//
//  PadView.swift
//  BLoop
//
//  Created by Sloven Graciet on 10/03/2020.
//  Copyright © 2020 Sloven Graciet. All rights reserved.
//

import SwiftUI

struct PadView: View {
    
    @EnvironmentObject var bloopManager: BLoopManager
    
    @State private var showMetronome = false
    
    var metronomeViewModel: MetronomeViewModel
    
    init(metronomeViewModel: MetronomeViewModel) {
        self.metronomeViewModel = metronomeViewModel
    } 
    
    var body: some View {
        
        let metronomeView = MetronomeView(viewModel: metronomeViewModel )
        
        let metronomeTickView = MetronomeTickView(action: {
            withAnimation {
                self.showMetronome.toggle()
            }
        }) {
            Text("Tick")
        }.environmentObject(bloopManager)
        
        return GeometryReader { geometry in
            
            VStack(){
                HStack {
                    PrimaryButton(action: {
                        self.bloopManager.startAll()
                    }) {
                        Text("start all ")
                    }
                    .frame(width: 60, height: 60)
                    PrimaryButton(action: {
                        self.bloopManager.stopAll()
                    }) {
                        Text("stop all")
                    }
                    .frame(width: 60, height: 60)
                    
                    metronomeTickView
                        .frame(width: 60, height: 60)
                    
                }.padding()
                 .frame(height: geometry.size.height * (2/5))
                Divider()
                    .background(Color.white)
                HStack(spacing: 20) {
                    TrackView().environmentObject(self.bloopManager.tracksAudioEngine[0])
                    TrackView().environmentObject(self.bloopManager.tracksAudioEngine[1])
                    TrackView().environmentObject(self.bloopManager.tracksAudioEngine[2])
                    TrackView().environmentObject(self.bloopManager.tracksAudioEngine[3])
                    TrackView().environmentObject(self.bloopManager.tracksAudioEngine[4])
                }
                .padding(5)
                .frame(height: geometry.size.height * (3/5), alignment: .bottom)
                
            }.frame(height: geometry.size.height)
            
            if self.showMetronome {
                metronomeView
                    .frame(width: geometry.size.width / 3)
                    .offset(x: self.showMetronome ? geometry.size.width / 3 * 2 : 0)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

        .background(Color(red: 0.2, green: 0.2, blue: 0.2).edgesIgnoringSafeArea(.all))
    }
}
