//
//  CodeFixer.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/22/26.
//

import Foundation
import FoundationModels

struct CodeFixer {
  private let instructions: String
  
  init() {
    instructions = """
           You are a Python code debugger. Given Python code and the error it produced 
           when executed, fix the code so it runs without errors.
           
           CRITICAL LIBRARY RESTRICTION:
           This app only includes a SUBSET of Python's standard library. You may ONLY 
           use the following modules:
           
           Math & Science: math, cmath, decimal, fractions, random, statistics
           Data Structures: collections, heapq, bisect, array, itertools, functools
           String & Text: string, re, textwrap
           Type Hints: typing, types
           Date & Time: datetime, calendar
           Data Formats: json, csv
           Other: copy, pprint, enum, dataclasses
           
           Do NOT use any third-party packages or any standard library modules not 
           listed above (os, sys, subprocess, socket, threading, multiprocessing, 
           pathlib, glob, shutil, pickle, sqlite3, etc.).
           
           Note that:
           - File I/O is NOT available
           - Networking is NOT available
           - stdin is NOT available
           
           RULES:
           1. Fix the error while preserving the code's original intent and logic
           2. Do NOT add features or change the algorithm — only fix what's broken
           3. CODE MUST BE SELF-CONTAINED AND RUNNABLE: Every variable must be defined before use
           4. MANDATORY OUTPUT: The code MUST produce visible output using print()
           5. Keep the complexity comment if one exists
           6. ONLY import modules that are actually used in the code
           7. Use Python 3.9+ built-in generic types (list[int], dict[str, int]) instead of importing from typing
           8. ALWAYS make print() output clean and human-readable
           
           In your response, only give the fixed code, and no other text.
           Do not include markdown code fences.
           """
  }
  
  var isAvailable: Bool {
    SystemLanguageModel.default.isAvailable && SystemLanguageModel.default.supportsLocale()
  }
  
  func fix(code: String, error: String) async throws -> String {
    guard SystemLanguageModel.default.supportsLocale() else {
      throw TranslationError.unsupportedLocale
    }
    
    guard SystemLanguageModel.default.isAvailable else {
      throw TranslationError.modelUnavailable
    }
    
    let session = LanguageModelSession(instructions: instructions)
    
    let prompt = """
      The following Python code produced an error when executed:
      
      <error>
      \(error.escapingDelimiterTags())
      </error>
      
      <code>
      \(code.escapingDelimiterTags())
      </code>
      
      Fix the code so it runs without errors. Return only the corrected code.
      """
    
    let result = try await session.respond(to: prompt)
    let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return content
      .strippingMarkdownCodeBlocks()
      .strippingOutputComments()
      .validatingModelOutput()
  }
}
