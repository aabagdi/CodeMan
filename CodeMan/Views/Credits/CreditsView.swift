//
//  CreditsView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/9/26.
//

import SwiftUI

struct CreditsView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          Image(systemName: "heart.fill")
            .font(.system(size: 40))
            .foregroundStyle(.pink.gradient)
          
          Text("Credits & License")
            .font(.largeTitle)
            .fontWeight(.bold)
        }
        .padding(.top, 20)
        
        VStack(alignment: .leading, spacing: 16) {
          Label("Acknowledgements", systemImage: "star.fill")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.orange.gradient)
          
          Text("This project was made possible thanks to:")
            .foregroundStyle(.secondary)
          
          VStack(spacing: 12) {
            CreditRow(
              name: "Highlighter",
              author: "Tony Smith",
              icon: "paintbrush.fill",
              color: .purple
            )
            
            CreditRow(
              name: "Python Apple Support",
              author: "BeeWare",
              icon: "ladybug.fill",
              color: .yellow)
            
            CreditRow(
              name: "SQLiteData",
              author: "Point-Free",
              icon: "cylinder.fill",
              color: .blue
            )
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        
        VStack(alignment: .leading, spacing: 16) {
          Label("License", systemImage: "doc.text.fill")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.green.gradient)
          
          Text("CodeMan is provided under the MIT License")
            .foregroundStyle(.secondary)
          
          Text("""
                    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
                    
                    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
                    
                    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
                    """)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(12)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
  }
}

struct CreditRow: View {
  let name: String
  let author: String
  let icon: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(color.gradient)
        .frame(width: 32)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(name)
          .fontWeight(.medium)
        Text("by \(author)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
    }
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }
}

#Preview {
  CreditsView()
}
