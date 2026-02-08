//
//  DeleteButtonView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct DeleteButtonView: View {
  @Binding var isPresented: Bool
  
  let onTap: () throws -> Void
  
  var body: some View {
    Button {
      do {
        try onTap()
      } catch {
        print("Deletion error: \(error)")
      }
    } label: {
      Image(systemName: "minus.circle.fill")
    }
    .scaleEffect(1.2)
    .foregroundStyle(Color.red)
    .opacity(isPresented ? 1 : 0)
    .animation(.easeInOut, value: isPresented)
  }
}

#Preview {
  DeleteButtonView(isPresented: .constant(true)) {
    
  }
}
