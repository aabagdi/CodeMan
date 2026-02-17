//
//  JiggleModifier.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct JiggleModifier: ViewModifier {
  var isJiggling: Bool
  
  @State private var animating = false
  
  func body(content: Content) -> some View {
    content
      .rotationEffect(.degrees(isJiggling ? (animating ? 2 : -2) : 0))
      .animation(
        isJiggling ? .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default,
        value: animating
      )
      .animation(.default, value: isJiggling)
      .onChange(of: isJiggling) {
        animating = isJiggling
      }
      .onAppear {
        animating = isJiggling
      }
  }
}

extension View {
  func jiggle(_ isJiggling: Bool) -> some View {
    modifier(JiggleModifier(isJiggling: isJiggling))
  }
}
