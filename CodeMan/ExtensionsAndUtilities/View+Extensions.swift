//
//  View+Extensions.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import Foundation
import SwiftUI

extension View {
  @MainActor
  func intelligenceBackground<S: InsettableShape>(
    in shape: S
  ) -> some View {
    background(
      shape.intelligenceStroke()
    )
  }
}

extension View {
  func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}
