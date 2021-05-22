//
//  PrimaryButton.swift
//  BLoop
//
//  Created by Sloven Graciet on 23/05/2020.
//  Copyright © 2020 Sloven Graciet. All rights reserved.
//

import SwiftUI

let primaryGray = Color(red: 0.1, green: 0.1, blue: 0.1)
let secondaryGray = Color(red: 0.4, green: 0.4, blue: 0.4)
let tertiaryGray = Color(red: 0.2, green: 0.2, blue: 0.2)


struct PrimaryButton<Label>: View where Label: View {
    
    private let action: () -> Void
    private let label: Label
    
    private var isSelectable: Bool
    @State private var isSelected = false
    
    init(isSelectable: Bool = false,action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.isSelectable = isSelectable
        self.action = action
        self.label = label()
    }
    
    var body : some View {
        
        let buttonStyle = PrimarySelectableButtonStyle(isSelected: $isSelected, isSelectable: isSelectable)
        
        return Button(action: {
            if self.isSelectable {
                self.isSelected.toggle()
            }
            self.action()
        }) {
            label
        }.buttonStyle(buttonStyle)
    }
}


struct PrimarySelectableButtonStyle: ButtonStyle {
    
    let unPressedColor = Color(red: 0.4, green: 0.4, blue: 0.4)
    let pressedColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    let gradientRadialInverted = RadialGradient(gradient:Gradient(colors:  [primaryGray, secondaryGray]), center: .bottom, startRadius: 0, endRadius: 70)
    
    let gradientradial = RadialGradient(gradient:Gradient(colors: [secondaryGray, primaryGray]), center: .bottom, startRadius: 0, endRadius: 70)
    
    let pressedRadialGradiant = RadialGradient(gradient:Gradient(colors:  [.black]), center: .bottom, startRadius: 0, endRadius: 70)
    
    @Binding var isSelected: Bool
    var isSelectable: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isPressedOrSelected = isSelectable ? isSelected : configuration.isPressed

        return configuration.label
        .padding(5)
            .multilineTextAlignment(.center)
            .foregroundColor(isPressedOrSelected ? .white : Color(red: 0.8, green: 0.8, blue: 0.8))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .overlay(
                GeometryReader { geometry in
                    ZStack{
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(self.gradientradial, lineWidth:8)
                            .shadow(color: isPressedOrSelected ? .black : .clear, radius: self.isSelected ? 2 : 0, x: 0, y: 2)
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isPressedOrSelected ? self.pressedRadialGradiant : self.gradientRadialInverted, lineWidth:2)
                            .shadow(color: isPressedOrSelected ? .black : .clear, radius:  isPressedOrSelected ? 2 : 0, x: 0, y: 2)
                            .frame(width: geometry.size.width - 8, height: geometry.size.height - 8)
                    }
                }
        )
        .background(isPressedOrSelected ? pressedColor : unPressedColor)
        .cornerRadius(6)
    }
}

struct PrimaryButton_Provider: PreviewProvider {
    
    static var previews: some View {
        NavigationView {
            VStack(spacing: 30) {
                PrimaryButton(action: {}) {
                    Text("start all")
                }
                .frame(width:60, height: 60)
                PrimaryButton(isSelectable: true, action: {}) {
                        Text("test")
                }
                .frame(width:60, height: 60)
            }
            
            
        }.colorScheme(.dark)
        
    }
}
