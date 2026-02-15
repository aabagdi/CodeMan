//
//  InsettableShape+Extensions.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import Foundation
import SwiftUI

extension InsettableShape {
  @MainActor
  func intelligenceStroke(
    lineWidths: [CGFloat] = [2, 4, 6, 8],
    blurs: [CGFloat] = [2, 8, 16, 20],
    updateInterval: TimeInterval = 0.4,
    animationDurations: [TimeInterval] = [1.2, 1.5, 2.0, 2.3],
    gradientGenerator: @MainActor @Sendable @escaping () -> [Gradient.Stop] = { .intelligenceStyle }
  ) -> some View {
    IntelligenceStrokeView(
      shape: self,
      lineWidths: lineWidths,
      blurs: blurs,
      updateInterval: updateInterval,
      animationDurations: animationDurations,
      gradientGenerator: gradientGenerator
    )
    .allowsHitTesting(false)
  }
}
