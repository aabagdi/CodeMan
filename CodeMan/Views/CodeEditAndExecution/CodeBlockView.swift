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
  let codeString: String
  let backgroundColor: Color
  
  init(title: String, code: String, backgroundColor: Color) {
    self.title = title
    self.code = Text(code)
    self.codeString = code
    self.backgroundColor = backgroundColor
  }
  
  init(title: String, code: AttributedString, backgroundColor: Color) {
    self.title = title
    self.code = Text(code)
    self.codeString = String(code.characters)
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
      }
      .background(backgroundColor.opacity(0.1))
      .clipShape(.rect(cornerRadius: 8))
      .padding(.horizontal)
      .contextMenu {
        Button {
          UIPasteboard.general.string = codeString
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
      }
    }
  }
}
