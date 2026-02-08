//
//  CodeBlockView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct CodeBlockView: View {
  let title: String
  let code: Text
  let backgroundColor: Color
  
  init(title: String, code: String, backgroundColor: Color) {
    self.title = title
    self.code = Text(code)
    self.backgroundColor = backgroundColor
  }
  
  init(title: String, code: AttributedString, backgroundColor: Color) {
    self.title = title
    self.code = Text(code)
    self.backgroundColor = backgroundColor
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .padding(.horizontal)
      
      ScrollView(.horizontal, showsIndicators: true) {
        code
          .font(.system(.body, design: .monospaced))
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .background(backgroundColor.opacity(0.1))
      .cornerRadius(8)
      .padding(.horizontal)
    }
  }
}
