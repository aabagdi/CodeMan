//
//  IntelligenceStrokeView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import SwiftUI

struct IntelligenceStrokeView<S: InsettableShape>: View {
  let shape: S
  let lineWidths: [CGFloat]
  let blurs: [CGFloat]
  let updateInterval: TimeInterval
  let animationDurations: [TimeInterval]
  let gradientGenerator: @MainActor @Sendable () -> [Gradient.Stop]
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stops: [Gradient.Stop] = .intelligenceStyle
  
  var body: some View {
    let layerCount = min(lineWidths.count, blurs.count, animationDurations.count)
    let gradient = AngularGradient(
      gradient: Gradient(stops: stops),
      center: .center
    )
    
    ZStack {
      ForEach(0..<layerCount, id: \.self) { i in
        shape
          .strokeBorder(gradient, lineWidth: lineWidths[i])
          .blur(radius: blurs[i])
          .animation(
            reduceMotion ? .linear(duration: 0) : .easeInOut(duration: animationDurations[i]),
            value: stops
          )
      }
    }
    .task(id: updateInterval) {
      while !Task.isCancelled {
        stops = gradientGenerator()
        try? await Task.sleep(for: .seconds(updateInterval))
      }
    }
  }
}
