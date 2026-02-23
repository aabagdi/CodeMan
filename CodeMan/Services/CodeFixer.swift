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
  
  private static let importMap: [String: String] = [
    // collections
    "defaultdict": "from collections import defaultdict",
    "Counter": "from collections import Counter",
    "deque": "from collections import deque",
    "OrderedDict": "from collections import OrderedDict",
    "namedtuple": "from collections import namedtuple",
    "ChainMap": "from collections import ChainMap",
    // functools
    "reduce": "from functools import reduce",
    "lru_cache": "from functools import lru_cache",
    "partial": "from functools import partial",
    "cache": "from functools import cache",
    // itertools
    "permutations": "from itertools import permutations",
    "combinations": "from itertools import combinations",
    "product": "from itertools import product",
    "chain": "from itertools import chain",
    "accumulate": "from itertools import accumulate",
    "groupby": "from itertools import groupby",
    "count": "from itertools import count",
    "cycle": "from itertools import cycle",
    "repeat": "from itertools import repeat",
    "islice": "from itertools import islice",
    "starmap": "from itertools import starmap",
    "zip_longest": "from itertools import zip_longest",
    "combinations_with_replacement": "from itertools import combinations_with_replacement",
    // decimal
    "Decimal": "from decimal import Decimal",
    // fractions
    "Fraction": "from fractions import Fraction",
    // dataclasses
    "dataclass": "from dataclasses import dataclass",
    "field": "from dataclasses import field",
    // copy
    "deepcopy": "from copy import deepcopy",
    // heapq
    "heappush": "from heapq import heappush",
    "heappop": "from heapq import heappop",
    "heapify": "from heapq import heapify",
    "heapreplace": "from heapq import heapreplace",
    "nlargest": "from heapq import nlargest",
    "nsmallest": "from heapq import nsmallest",
    "heapify_max": "from heapq import heapify_max",
    "heappush_max": "from heapq import heappush_max",
    "heappop_max": "from heapq import heappop_max",
    "heappushpop_max": "from heapq import heappushpop_max",
    "heapreplace_max": "from heapq import heapreplace_max",
    // bisect
    "bisect_left": "from bisect import bisect_left",
    "bisect_right": "from bisect import bisect_right",
    "insort": "from bisect import insort",
    "insort_left": "from bisect import insort_left",
    "insort_right": "from bisect import insort_right",
    // pprint
    "pprint": "from pprint import pprint",
    // enum
    "Enum": "from enum import Enum",
    "IntEnum": "from enum import IntEnum",
    // datetime
    "timedelta": "from datetime import timedelta",
  ]
  
  private static let allowedModules: Set<String> = [
    "math", "cmath", "decimal", "fractions", "random", "statistics",
    "collections", "heapq", "bisect", "array", "itertools", "functools",
    "string", "re", "textwrap",
    "typing", "types",
    "datetime", "calendar",
    "json", "csv",
    "copy", "pprint", "enum", "dataclasses",
  ]
  
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
           3. Prefer the SMALLEST possible fix
           4. CODE MUST BE SELF-CONTAINED AND RUNNABLE: Every variable must be defined before use
           5. MANDATORY OUTPUT: The code MUST produce visible output using print()
           6. Keep the complexity comment if one exists
           7. ONLY import modules that are actually used in the code
           8. Use Python 3.9+ built-in generic types (list[int], dict[str, int]) instead of importing from typing
           9. ALWAYS make print() output clean and human-readable
           10. Do NOT remove or modify any existing import statements
           
           In your response, only give the fixed code, and no other text.
           Do not include markdown code fences.
           """
  }
  
  var isAvailable: Bool {
    SystemLanguageModel.default.isAvailable && SystemLanguageModel.default.supportsLocale()
  }
  
  private func tryFixMissingImport(code: String, error: String) -> String? {
    let nameErrorPattern = /NameError: name '(\w+)' is not defined/
    let moduleErrorPattern = /ModuleNotFoundError: No module named '(\w+)'/
    let importErrorPattern = /ImportError: cannot import name '(\w+)'/
    
    var missingName: String?
    
    if let match = error.firstMatch(of: nameErrorPattern) {
      missingName = String(match.1)
    } else if let match = error.firstMatch(of: moduleErrorPattern) {
      missingName = String(match.1)
    } else if let match = error.firstMatch(of: importErrorPattern) {
      missingName = String(match.1)
    }
    
    guard let name = missingName else { return nil }
    
    var importStatement: String?
    
    if let mapped = Self.importMap[name] {
      importStatement = mapped
    } else if Self.allowedModules.contains(name) {
      importStatement = "import \(name)"
    }
    
    guard let statement = importStatement else { return nil }
    
    if code.contains(statement) { return nil }
    
    return insertImport(statement, into: code)
  }
  
  private func insertImport(_ importStatement: String, into code: String) -> String {
    let lines = code.components(separatedBy: "\n")
    
    var lastImportIndex = -1
    for (index, line) in lines.enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
        lastImportIndex = index
      } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") && lastImportIndex >= 0 {
        break
      }
    }
    
    var result = lines
    if lastImportIndex >= 0 {
      result.insert(importStatement, at: lastImportIndex + 1)
    } else {
      result.insert(importStatement, at: 0)
    }
    
    return result.joined(separator: "\n")
  }
  
  func fix(code: String, error: String) async throws -> String {
    if let fixed = tryFixMissingImport(code: code, error: error) {
      return fixed
    }
    
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
