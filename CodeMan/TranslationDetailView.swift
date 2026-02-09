//
//  TranslationDetailView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import Foundation
import SQLiteData
import SwiftUI

struct TranslationDetailView: View {
  @State var viewModel: TranslationDetailViewModel
  
  init(translation: Translation) {
    _viewModel = State(initialValue: TranslationDetailViewModel(translation: translation))
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        if let uiImage = UIImage(data: viewModel.translation.image ?? Data()) {
          ImageHeaderView(image: Image(uiImage: uiImage))
        }
        
        CodeBlockView(
          title: "Original:",
          code: viewModel.translation.originalText,
          backgroundColor: .secondary
        )
        
        Divider()
          .padding()
        
        CodeBlockView(
          title: "Python:",
          code: viewModel.translation.prettifiedCode ?? AttributedString(),
          backgroundColor: .green
        )
        
        Divider()
          .padding()
        
        Button {
          Task {
            await viewModel.shareButtonTapped()
          }
        } label: {
          HStack {
            if viewModel.isSharing {
              ProgressView()
                .tint(.white)
            } else {
              Image(systemName: "square.and.arrow.up.fill")
            }
            Text("Share code with a friend!")
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.green)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(viewModel.isSharing)
      }
      .padding()
    }
    .navigationTitle(viewModel.translation.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(destination: CodeEditAndExecutionView(translation: $viewModel.translation)) {
          Text("Edit and run code")
        }
      }
    }
    .sheet(item: $viewModel.sharedRecord) { sharedRecord in
      CloudSharingView(sharedRecord: sharedRecord)
    }
  }
}
