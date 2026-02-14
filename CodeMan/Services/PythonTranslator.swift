//
//  TranslationSessionManager.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
import FoundationModels

enum TranslationError: LocalizedError {
  case unsupportedLocale
  case modelUnavailable
  
  var errorDescription: String? {
    switch self {
    case .unsupportedLocale:
      return "Your device language is not supported by Apple Intelligence. Please change your device language to English (US) in Settings → General → Language & Region. (Tip: If the photo is landscape, try rotating and cropping it.)"
    case .modelUnavailable:
      return "The AI model is not available on this device."
    }
  }
}

actor TranslationSessionManager {
  let session: LanguageModelSession?
  
  init() {
    guard SystemLanguageModel.default.supportsLocale() else {
      print("Warning: Current locale is not supported by Apple Intelligence")
      session = nil
      return
    }
    let instructions = """
           Your job is to translate pseudocode or handwritten code in ANY language
           to idiomatic, Pythonic code. The input text must be in English. 
           You MUST respond in English. Follow Python  best practices (PEP 8) 
           while maintaining readability. In your response, only give the code, 
           and no other text.
           
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
           
           If the original code uses an unavailable module, translate it using only
           the allowed modules listed above:
           - Instead of numpy arrays, use Python lists with list comprehensions
           - Instead of pandas DataFrames, use lists of dictionaries or csv module
           - For math operations, use the math module
           - For random numbers, use the random module
           - For JSON, use the json module
           - For file operations, note that file I/O is NOT available
           - For networking, note that networking is NOT available
           
           CRITICAL RULES:
           1. Translate the provided code to idiomatic Python - preserve the FUNCTIONALITY, not necessarily the structure
           2. Do NOT add features or logic that aren't present in the original
           3. Do NOT try to complete incomplete code or add missing functionality
           4. SIMPLIFY when appropriate - if C++ uses a main() function just to print, translate to a simple print statement
           5. Remove boilerplate that isn't needed in Python (like main() for simple scripts)
           6. Preserve the exact logical operations, but adapt the structure to Python conventions
           7. CODE MUST BE SELF-CONTAINED AND RUNNABLE: Every variable must be defined before use. Never reference undefined variables like 'visited' or 'discovered' without initializing them first.
           8. For graph/tree algorithms: Use ONE consistent approach - either all methods inside a class, OR all standalone functions. Never mix both with shared state.
           9. MANDATORY OUTPUT: The code MUST produce visible output using print(). If the algorithm computes a result, print it. If it modifies data, print the result. NEVER return a value without also printing it. Users cannot see return values - only print() output is visible.
           10. MANDATORY COMPLEXITY COMMENT: You MUST add a comment at the very end of the code documenting the time complexity (Big O) and space complexity. Format: # Time: O(...), Space: O(...). This is REQUIRED for ALL code, not optional. You MUST include both average and worst case time complexity if applicable.
           
           EXAMPLE DATA PROVISION (MANDATORY FOR KNOWN ALGORITHMS):
           - If the code implements a well-known algorithm (sorting, searching, tree traversal, etc.) 
             and lacks test data, you MUST add example data to make the code runnable
           - This is REQUIRED for: binary search, linear search, bubble sort, insertion sort, 
             selection sort, merge sort, quicksort, heap sort, BFS, DFS, factorial, fibonacci,
             and any other recognizable standard algorithm
           - Keep example data minimal but representative:
             * Sorting algorithms → add unsorted array: arr = [64, 34, 25, 12, 22, 11, 90]
             * Binary search → add sorted array AND target: arr = [1, 3, 5, 7, 9, 11, 13]; target = 7
             * Linear search → add array AND target: arr = [10, 20, 30, 40, 50]; target = 30
             * Tree algorithms → add simple tree structure with complete Node class (define ALL properties in __init__)
             * Graph algorithms → add Graph class with __init__ that defines self.graph = defaultdict(list), add_edge method, and example edges. CRITICAL: Every property used in any method MUST be initialized in __init__
             * Recursive algorithms → add appropriate input value
           - ALWAYS add a print() statement at the end to show the result (this is REQUIRED - users can only see printed output)
           - Do NOT add data only when:
             * The code already has input data defined
             * The purpose of the code is genuinely unclear/partial
             * It's a generic utility function (not a specific algorithm)
           
           PYTHON BEST PRACTICES - Apply these for Pythonic, readable output:
           
           Naming Conventions:
           - Use snake_case for variables and functions (not camelCase)
           - Use descriptive names: prefer 'total_count' over 'tc'
           - Use UPPER_CASE for constants
           - Use clear, meaningful names even for single letters when appropriate
           
           Idiomatic Python:
           - Use list comprehensions when clearer than loops: [x*2 for x in items]
           - Use 'in' for membership tests: if item in collection
           - Use enumerate() for indexed loops: for i, item in enumerate(items)
           - Use zip() for parallel iteration: for a, b in zip(list1, list2)
           - Prefer 'with' statements for file/resource handling
           - Use f-strings for string formatting: f"Value: {value}"
           - Use ** for exponentiation instead of math.pow() unless floats are specifically needed
           - Use .append() for adding single items, .extend() for multiple
           - Use 'is' for None checks: if value is None
           - Use tuple unpacking for swaps: a, b = b, a (NEVER define a swap function)
           
           Readability:
           - Use 4 spaces for indentation (PEP 8 standard)
           - Add blank lines between logical sections
           - Keep lines under 79 characters when practical
           - Preserve original comments and translate them to Python style
           - Use explicit comparisons for clarity when needed
           
           Data Structures:
           - Use lists for ordered collections: my_list = [1, 2, 3]
           - Use tuples for immutable sequences: coordinates = (x, y)
           - Use sets for unique items: unique_items = {1, 2, 3}
           - Use dicts for key-value pairs: data = {'key': 'value'}
           
           Control Flow:
           - Use 'elif' instead of 'else if'
           - Avoid unnecessary parentheses in conditions
           - Use 'and', 'or', 'not' (not &&, ||, !)
           - Prefer 'for' loops over 'while' when iterating
           
           You should translate:
           - All programming code (Swift, Java, C++, JavaScript, etc.)
           - All pseudocode (including statements like "add x to list", "for each element", etc.)
           - Algorithm descriptions written in code-like format
           - Variable assignments (including := notation)
           - Control flow statements (if/then/else, for/while loops)
           - Function/procedure definitions
           - Data structure operations (add, remove, insert, etc.)
           
           IMPORTANT: If the input is clearly not code or pseudocode (e.g., regular prose,
           titles, headers, page numbers, or conversational text that isn't describing an algorithm),
           respond with exactly "NOT_CODE" and nothing else.
           
           Examples of Pythonic translations:
           - "add x to left" → "left.append(x)"
           - "for i from 0 to n" → "for i in range(n):"
           - "var totalCount := 5" → "total_count = 5"
           - "if condition then do something" → "if condition:\n    do_something()"
           - "for each item in list" → "for item in list:"
           - "create empty array" → "arr = []"
           - "length of array" → "len(arr)"
           
           Examples of what NOT to translate (respond with "NOT_CODE"):
           - "Chapter 5: Sorting Algorithms"
           - "The example shows how merge sort works"
           - "Figure 3.2"
           - Regular paragraph text without code-like structure
           
           Remember: Translate EXACTLY what you're given using Pythonic idioms, nothing more, nothing less.
           """
    
    session = LanguageModelSession(instructions: instructions)
  }
  
  func translate(_ input: String) async throws -> String {
    guard let session else {
      throw TranslationError.unsupportedLocale
    }
    
    let maxInputLength = 12000
    
    if input.count > maxInputLength {
      return try await translateInChunks(input, maxLength: maxInputLength)
    }
    
    let prompt = buildPrompt(for: input)
    let result = try await session.respond(to: prompt)
    let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if content == "NOT_CODE" {
      return ""
    }
    
    return content
  }
  
  private func buildPrompt(for input: String) -> String {
    let lowercased = input.lowercased()
    
    let algorithmPatterns: [(keywords: [String], instruction: String)] = [
      (["binary", "search"], 
       "\n\n[IMPORTANT: Add example data - a sorted array like [1, 3, 5, 7, 9, 11, 13] and target = 7, then call the function and print the result]"),
      (["linear", "search"],
       "\n\n[IMPORTANT: Add example data - an array like [10, 20, 30, 40, 50] and target = 30, then call the function and print the result]"),
      (["bubble", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["insertion", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["selection", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["merge", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["quick", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["heap", "sort"],
       "\n\n[IMPORTANT: Add example data - an unsorted array like [64, 34, 25, 12, 22, 11, 90], then call the function and print the result]"),
      (["fibonacci"],
       "\n\n[IMPORTANT: Add example - call the function with n = 10 and print the result]"),
      (["factorial"],
       "\n\n[IMPORTANT: Add example - call the function with n = 5 and print the result]"),
      (["bfs"],
       "\n\n[IMPORTANT: Follow this EXACT pattern for a complete BFS:\nfrom collections import defaultdict, deque\nclass Graph:\n    def __init__(self):\n        self.graph = defaultdict(list)\n    def add_edge(self, u, v):\n        self.graph[u].append(v)\n    def bfs(self, start):\n        visited = set()\n        queue = deque([start])\n        visited.add(start)\n        result = []\n        while queue:\n            vertex = queue.popleft()\n            result.append(vertex)\n            for neighbor in self.graph[vertex]:\n                if neighbor not in visited:\n                    visited.add(neighbor)\n                    queue.append(neighbor)\n        return result\n\ng = Graph()\ng.add_edge(0, 1)\ng.add_edge(0, 2)\ng.add_edge(1, 2)\ng.add_edge(2, 3)\nprint(g.bfs(0))\n\nAdapt this pattern to match the input code's logic. ALL variables must be defined before use. Do NOT create standalone functions that reference undefined global variables.]"),
      (["breadth"],
       "\n\n[IMPORTANT: Follow this EXACT pattern for a complete BFS:\nfrom collections import defaultdict, deque\nclass Graph:\n    def __init__(self):\n        self.graph = defaultdict(list)\n    def add_edge(self, u, v):\n        self.graph[u].append(v)\n    def bfs(self, start):\n        visited = set()\n        queue = deque([start])\n        visited.add(start)\n        result = []\n        while queue:\n            vertex = queue.popleft()\n            result.append(vertex)\n            for neighbor in self.graph[vertex]:\n                if neighbor not in visited:\n                    visited.add(neighbor)\n                    queue.append(neighbor)\n        return result\n\ng = Graph()\ng.add_edge(0, 1)\ng.add_edge(0, 2)\ng.add_edge(1, 2)\ng.add_edge(2, 3)\nprint(g.bfs(0))\n\nAdapt this pattern to match the input code's logic. ALL variables must be defined before use. Do NOT create standalone functions that reference undefined global variables.]"),
      (["dfs"],
       "\n\n[IMPORTANT: Follow this EXACT pattern for a complete DFS:\nfrom collections import defaultdict\nclass Graph:\n    def __init__(self):\n        self.graph = defaultdict(list)\n    def add_edge(self, u, v):\n        self.graph[u].append(v)\n    def dfs(self, start):\n        visited = set()\n        result = []\n        self._dfs_helper(start, visited, result)\n        return result\n    def _dfs_helper(self, vertex, visited, result):\n        visited.add(vertex)\n        result.append(vertex)\n        for neighbor in self.graph[vertex]:\n            if neighbor not in visited:\n                self._dfs_helper(neighbor, visited, result)\n\ng = Graph()\ng.add_edge(0, 1)\ng.add_edge(0, 2)\ng.add_edge(1, 2)\ng.add_edge(2, 3)\nprint(g.dfs(0))\n\nAdapt this pattern to match the input code's logic. ALL variables must be defined before use. Do NOT create standalone functions that reference undefined global variables.]"),
      (["depth"],
       "\n\n[IMPORTANT: Follow this EXACT pattern for a complete DFS:\nfrom collections import defaultdict\nclass Graph:\n    def __init__(self):\n        self.graph = defaultdict(list)\n    def add_edge(self, u, v):\n        self.graph[u].append(v)\n    def dfs(self, start):\n        visited = set()\n        result = []\n        self._dfs_helper(start, visited, result)\n        return result\n    def _dfs_helper(self, vertex, visited, result):\n        visited.add(vertex)\n        result.append(vertex)\n        for neighbor in self.graph[vertex]:\n            if neighbor not in visited:\n                self._dfs_helper(neighbor, visited, result)\n\ng = Graph()\ng.add_edge(0, 1)\ng.add_edge(0, 2)\ng.add_edge(1, 2)\ng.add_edge(2, 3)\nprint(g.dfs(0))\n\nAdapt this pattern to match the input code's logic. ALL variables must be defined before use. Do NOT create standalone functions that reference undefined global variables.]"),
      (["graph", "traversal"],
       "\n\n[IMPORTANT: This is a graph algorithm. You MUST include a complete Graph class with __init__ that initializes self.graph = defaultdict(list), an add_edge method, and the traversal method. Add example edges and call the traversal. ALL variables must be defined before use.]"),
      (["adjacency"],
       "\n\n[IMPORTANT: This is a graph algorithm. You MUST include a complete Graph class with __init__ that initializes self.graph = defaultdict(list), an add_edge method, and any traversal methods. Add example edges and demonstrate usage. ALL variables must be defined before use.]"),
    ]
    
    for (keywords, instruction) in algorithmPatterns {
      let allMatch = keywords.allSatisfy { keyword in
        lowercased.contains(keyword)
      }
      if allMatch {
        return input + instruction
      }
    }
    
    return input
  }
  
  private func translateInChunks(_ input: String, maxLength: Int) async throws -> String {
    let lines = input.components(separatedBy: .newlines)
    var chunks: [String] = []
    var currentChunk = ""
    
    for line in lines {
      let testChunk = currentChunk.isEmpty ? line : currentChunk + "\n" + line
      
      if testChunk.count > maxLength && !currentChunk.isEmpty {
        chunks.append(currentChunk)
        currentChunk = line
      } else {
        currentChunk = testChunk
      }
    }
    
    if !currentChunk.isEmpty {
      chunks.append(currentChunk)
    }
    
    var finalChunks: [String] = []
    for chunk in chunks {
      if chunk.count > maxLength {
        var start = chunk.startIndex
        while start < chunk.endIndex {
          let end = chunk.index(start, offsetBy: maxLength, limitedBy: chunk.endIndex) ?? chunk.endIndex
          finalChunks.append(String(chunk[start..<end]))
          start = end
        }
      } else {
        finalChunks.append(chunk)
      }
    }
    
    var translations: [String] = []
    for (index, chunk) in finalChunks.enumerated() {
      print("Translating chunk \(index + 1)/\(finalChunks.count)...")
      let prompt = buildPrompt(for: chunk)
      let result = try await session!.respond(to: prompt)
      let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
      
      if content != "NOT_CODE" {
        translations.append(content)
      }
    }
    
    return translations
      .joined(separator: "\n")
  }
}
