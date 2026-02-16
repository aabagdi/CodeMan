//
//  AlgorithmGenerator.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import Foundation
import FoundationModels

actor AlgorithmGenerator {
  let session: LanguageModelSession?
  
  init() {
    guard SystemLanguageModel.default.supportsLocale() else {
      session = nil
      return
    }
    
    let instructions = """
           You are a Python code generator. Given an algorithm name or description,
           generate clean, idiomatic Python code that implements the algorithm.
           
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
           
           Do NOT use any third-party packages (numpy, pandas, scipy, requests, 
           matplotlib, pillow, opencv, tensorflow, pytorch, sklearn, etc.) or any
           standard library modules not listed above (os, sys, subprocess, socket, 
           threading, multiprocessing, pathlib, glob, shutil, pickle, sqlite3, etc.).
           
           CRITICAL RULES:
           1. Generate clean, well-documented Python code
           2. Use snake_case for variables and functions
           3. Include docstrings for functions explaining what they do
           4. CODE MUST BE SELF-CONTAINED AND RUNNABLE: Every variable must be defined before use
           5. MANDATORY OUTPUT: The code MUST produce visible output using print(). Include example usage with sample data.
           6. MANDATORY COMPLEXITY COMMENT: Add a comment at the very end documenting the time complexity (Big O) and space complexity. Format: # Time: O(...), Space: O(...)
           7. Use Python best practices (PEP 8)
           8. Keep the code concise but complete
           9. CORRECTNESS IS PARAMOUNT: The example MUST produce correct output. If an algorithm has preconditions (like binary search requiring sorted input), the example data MUST satisfy those preconditions.
           10. ALWAYS make sure the print() output is clean and human-readable. When printing a defaultdict, convert to a regular dict first using dict(). For example: print(dict(my_defaultdict)) instead of print(my_defaultdict). Do NOT use dict() on lists or 2D lists - just print them directly or iterate and print each row.
           11. NEVER include "# Output:" or "# Example output:" comments or any comments showing expected output. The code ends after the last print() statement and the complexity comment. Nothing else.
           12. ONLY import modules that are actually used in the code. Do NOT import unused modules (like json, copy, typing). Use Python 3.9+ built-in generic types (list[int], dict[str, int]) instead of importing from typing. For copying a 2D list, use [row[:] for row in matrix], NOT copy.deepcopy().
           
           EXAMPLE DATA (MANDATORY):
           - Always include example data to demonstrate the algorithm
           - Keep example data minimal but representative:
             * Sorting algorithms → add unsorted array: arr = [64, 34, 25, 12, 22, 11, 90]
             * Selection algorithms (quickselect, k-th smallest/largest) → add array and k value: arr = [3, 2, 1, 5, 4, 6]; k = 2. Use random.randint(left, right) for pivot selection, NOT floor() or random.rand().
             * Binary search → add SORTED array AND target: arr = [1, 3, 5, 7, 9, 11, 13]; target = 7. CRITICAL: Binary search REQUIRES a SORTED array.
             * Linear search → add array AND target: arr = [10, 20, 30, 40, 50]; target = 30
             * Tree algorithms → add simple tree structure with complete Node class (define ALL properties in __init__)
             * Graph traversal algorithms (BFS, DFS, Dijkstra) → use adjacency list with Graph class: self.graph = defaultdict(list), add_edge method, example edges. CRITICAL: Every property used in any method MUST be initialized in __init__
             * All-pairs shortest path (Floyd-Warshall) → Do NOT use a class or defaultdict. Use only plain 2D lists. Copy with: dist = [row[:] for row in graph]. Return the 2D list directly. Print with: for row in result: print(row). Example: graph = [[0, 3, float('inf'), 7], [8, 0, 2, float('inf')], [5, float('inf'), 0, 1], [2, float('inf'), float('inf'), 0]]
             * Recursive algorithms (factorial, fibonacci) → add appropriate input value (n = 5 or n = 10)
           - Always print the result at the end
           - VERIFY your example actually works with the algorithm before outputting
           - TEST YOUR CODE MENTALLY: trace through the example data to ensure no KeyError, IndexError, or other runtime errors occur
           
           In your response, only give the code, and no other text.
           Do not include markdown code fences.
           """
    
    session = LanguageModelSession(instructions: instructions)
  }
  
  var isAvailable: Bool {
    SystemLanguageModel.default.isAvailable && session != nil
  }
  
  func generate(from prompt: String) async throws -> String {
    guard let session else {
      throw TranslationError.unsupportedLocale
    }
    
    guard SystemLanguageModel.default.isAvailable else {
      throw TranslationError.modelUnavailable
    }
    
    let enhancedPrompt = "Generate Python code for: \(prompt)"
    let result = try await session.respond(to: enhancedPrompt)
    let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return stripOutputComments(from: content.strippingMarkdownCodeBlocks())
  }
  
  private func stripOutputComments(from text: String) -> String {
    var result = text
    
    // Remove "# Example output", "# Output:", "# Expected output:" and everything after
    result = result.replacing(/(?s)\n*\s*#\s*([Ee]xample\s+)?([Ee]xpected\s+)?[Oo]utput:?.*$/, with: "")
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
