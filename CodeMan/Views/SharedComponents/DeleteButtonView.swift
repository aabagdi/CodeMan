//
//  DeleteButtonView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct DeleteButtonView: View {
  var isPresented: Bool
  
  let onTap: () throws -> Void
  
  var body: some View {
    Button {
      try? onTap()
    } label: {
      Image(systemName: "minus.circle.fill")
        .accessibilityLabel("Delete")
    }
    .scaleEffect(1.2)
    .foregroundStyle(.red)
    .opacity(isPresented ? 1 : 0)
    .animation(.easeInOut, value: isPresented)
  }
}

#Preview {
  DeleteButtonView(isPresented: true) {
    
  }
}
