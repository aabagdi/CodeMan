//
//  Tips.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/17/26.
//

import TipKit

struct CaptureTip: Tip {
  var title: Text { Text("Capture Code") }
  var message: Text? { Text("Tap to photograph pseudocode and translate to runnable Python!") }
  var image: Image? { Image(systemName: "camera") }
}

struct GenerateTip: Tip {
  var title: Text { Text("Generate Algorithms") }
  var message: Text? { Text("Describe an algorithm and AI will write Python code for you!") }
  var image: Image? { Image(systemName: "wand.and.stars") }
}

struct DeleteTip: Tip {
  var title: Text { Text("Delete Snippets") }
  var message: Text? { Text("Press and hold any item to enter delete mode!") }
  var image: Image? { Image(systemName: "trash") }
}
