//
//  AssetsView.swift
//  ReusableAssets
//
//  Created by Main on 12/13/25.
//

import SwiftUI

struct LabelStyle: View {
    var text: String
    var icon: String
    
    var body: some View {
        HStack {
            if #available(iOS 26.0, *) {
                Image(systemName: icon)
                    .frame(width: 24, alignment: .center)
                Text(text)
            } else {
                Image(systemName: icon)
                    .frame(alignment: .center)
                Text(text)
            }
        }
    }
}

struct GlassyButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var useFullWidth: Bool = true
    var isDisabled: Bool = false
    var capsuleButton: Bool = false
    var cornerRadius: CGFloat = 18
    var isInteractive: Bool = true
    var isMaterialButton: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        let color: Color = isDisabled ? .gray : color
        
        if #available(iOS 26.0, *) {
            let shape: AnyShape = capsuleButton ? AnyShape(.capsule) : AnyShape(.rect(cornerRadius: cornerRadius))
            let isInteractive: Bool = isDisabled ? false : true
            
            configuration.label
                .buttonStyle(.plain)
                .frame(maxWidth: useFullWidth ? .infinity : nil)
                .foregroundStyle(color)
                .padding()
                .background(color.opacity(0.2))
                .clipShape(shape)
                .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
                .allowsHitTesting(!isDisabled)
        } else {
            let shape: AnyShape = capsuleButton ? AnyShape(.capsule) : AnyShape(.rect(cornerRadius: 12))
            
            configuration.label
                .buttonStyle(.plain)
                .frame(maxWidth: useFullWidth ? .infinity : nil)
                .foregroundStyle(color)
                .padding()
                .background(color.opacity(0.2))
                .background {
                    if isMaterialButton {
                        Color.clear.background(.ultraThinMaterial)
                    }
                }
                .clipShape(shape)
                .allowsHitTesting(!isDisabled)
        }
    }
}

struct GlassyTextFieldStyle: TextFieldStyle {
    var color: Color = Color(.tertiarySystemFill)
    var isDisabled: Bool = false
    var capsuleField: Bool = false
    var cornerRadius: CGFloat = 18
    var isInteractive: Bool = true
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        let color: Color = isDisabled ? .gray : color
        let fontColor: Color = isDisabled ? .gray : .primary
        
        if #available(iOS 26.0, *) {
            let shape: AnyShape = capsuleField ? AnyShape(.capsule) : AnyShape(.rect(cornerRadius: cornerRadius))
            let isInteractive: Bool = isDisabled ? false : true
            
            configuration
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .foregroundStyle(fontColor)
                .padding()
                .background(color.opacity(0.2))
                .clipShape(shape)
                .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
                .allowsHitTesting(!isDisabled)
        } else {
            let shape: AnyShape = capsuleField ? AnyShape(.capsule) : AnyShape(.rect(cornerRadius: 12))
            
            configuration
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .foregroundStyle(fontColor)
                .padding()
                .background(color.opacity(0.2))
                .clipShape(shape)
                .allowsHitTesting(!isDisabled)
        }
    }
}

struct GlassyBackground: ViewModifier {
    var color: Color = Color(.secondarySystemFill)
    var useFullWidth: Bool = true
    var cornerRadius: CGFloat = 18
    var isInteractive: Bool = true
    
    func body(content: Content) -> some View {
        let shape: AnyShape = AnyShape(.rect(cornerRadius: cornerRadius))
        
        if #available(iOS 26.0, *) {
            content
                .background(color.opacity(0.2))
                .clipShape(shape)
                .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
        } else {
            let shape: AnyShape = AnyShape(.rect(cornerRadius: 12))
            
            content
                .background(color.opacity(0.2))
                .clipShape(shape)
        }
    }
}

struct GlassyTerminal<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        ZStack(alignment: .top) {
            content
            VStack {
                VariableBlurView(maxBlurRadius: 1, direction: .blurredTopClearBottom)
                    .frame(maxHeight: 20)
                Spacer()
                VariableBlurView(maxBlurRadius: 1, direction: .blurredBottomClearTop)
                    .frame(maxHeight: 20)
            }
            .frame(alignment: .top)
        }
        .frame(height: 250)
        .padding(.horizontal)
        .modifier(GlassyBackground())
    }
}
