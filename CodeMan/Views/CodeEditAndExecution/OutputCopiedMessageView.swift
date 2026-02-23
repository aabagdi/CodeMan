//
//  CodeCopiedMessageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/22/26.
//

import Foundation
import SwiftUI

struct OutputCopiedMessageView: View {
  var body: some View {
    VStack {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20, weight: .bold))
      Text("Output copied to clipboard!")
    }
    .padding()
    .foregroundStyle(.gray)
    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
  }
}

#Preview {
  OutputCopiedMessageView()
}
