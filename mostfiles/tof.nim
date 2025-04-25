# Starting with 2 files to compare for overlapping texts.


import strutils, sequtils, algorithm
#import unicode

var versionfl: float = 0.5
var last_time_stamp: string = "2025-04-24_22.01"

type
  Match = object
    substring: string
    startA: int
    startB: int
    length: int

proc isWordChar(c: char): bool =
  #return c.isAlpha()
  return c.isAlphaAscii()

proc trimToFullWords(s: string): string =
  var start = 0
  var stop = s.len

  # Trim vooraan als het niet op een woord begint
  while start < s.len and isWordChar(s[start]):
    if start == 0 or not isWordChar(s[start - 1]):
      break
    inc start

  # Trim achteraan als het midden in een woord eindigt
  while stop > 0 and isWordChar(s[stop - 1]):
    if stop == s.len or not isWordChar(s[stop]):
      break
    dec stop

  if start < stop:
    return s[start ..< stop].strip()
  else:
    return ""




proc findCommonSubstrings(a, b: string; minLen: int): seq[Match] =
  #[ 
    - a en b are strings to compare on overlapping substrings.
    - the overlaps will be returned in seq of object Match
    - minLen is the minimal length for string to be added to the matches
    (>15 or 30 recommended; "the" or "have" are not very interesting overlaps)
    - for now a is the new file you want to review
    (because currently the matches are sorted on the a-file order)
  ]#


  let n = a.len
  let m = b.len

  # var dp is 2D-sequence of int that contains the incremental length of the 
  # substring under investigation.
  var dp = newSeqWith(n + 1, newSeq[int](m + 1))
  var rawMatches: seq[Match] = @[]

  # string-comparison is done incrementally per letter;
  # if all letters are the same and lenghth > minlen the subst is added to matches 
  for i in 1..n:
    for j in 1..m:
      if a[i - 1] == b[j - 1]:
        dp[i][j] = dp[i - 1][j - 1] + 1
        if dp[i][j] >= minLen:
          let length = dp[i][j]
          let startA = i - length
          let startB = j - length
          let substr = a[startA ..< i]
          rawMatches.add Match(substring: substr, startA: startA, startB: startB, length: length)
      else:
        dp[i][j] = 0

  # Filter: hou alleen langste unieke, niet-overlappende substrings over
  rawMatches = rawMatches.sortedByIt(-it.length)  # langste eerst
  var filtered: seq[Match] = @[]

  for m in rawMatches:
    if not filtered.anyIt(it.startA <= m.startA and it.startA + it.length >= m.startA + m.length):
      var clean = m
      clean.substring = trimToFullWords(m.substring)
      clean.length = clean.substring.len
      if clean.length >= minLen:
        filtered.add clean

  var unique: seq[Match] = @[]
  unique = deduplicate(filtered)
  #filtered = filtered.sortedByIt(it.startA)
  unique = unique.sortedByIt(it.startA)

  return unique


proc getStringStats(tekst, namest: string): string =
  # return string-stats of tekst number of lines, words and characters

  var outst: string
  outst = namest & " (" & tekst[0..40] & "...) has " & $tekst.splitLines.len  & " lines, " & $tekst.splitWhitespace.len & " words,and " & $tekst.len & " characters."

  result = outst


proc markOverlapsInFile(first, secondst: string; minlenghthit: int): string =
  #[
    Insert into the first string overlap-indicators from the overlaps with the second string 
    and return the new marked-up first string.
  ]#

  # put the new file in 01.txt

  # call findCommonSubstrings to find the matches
  let matchsq = findCommonSubstrings(first, secondst, minlenghthit)

  var markedst: string = first

  # set cur-pos = 0
  var cyclit: int = 0
  var curposit: int = 0
  var previousposit: int = 0
  var overlapstartst: string = "\p======================overlap-start===========================\p"
  var overlapsendst: string =  "\p----------------------overlap-end-----------------------------\p"

  var debugbo: bool = false

  if debugbo: echo "matchsq.len = " & $matchsq.len & "\p"

  var startA_previous: int = 0
  var allsubstringsq: seq[string]

  for matchob in matchsq:

    cyclit += 1

    if debugbo: echo "cyclit = " & $cyclit

    # find the subst / index from cur-pos

    #if matchob.startA != startA_previous:   # sometimes multiples because of the other file B
    if matchob.startA != startA_previous and matchob.substring notin allsubstringsq:
      curposit = markedst.find(matchob.substring, curposit)

      if debugbo: echo "matchob.substring = " & matchob.substring
      if debugbo: echo "curposit = " & $curposit

      if curposit > -1:
        # insert mark overlap-start
        markedst.insert(overlapstartst, curposit)
        # add up overlap-mark and match.len to index-pos and reset the index-pos
        curposit = curposit + overlapstartst.len + matchob.substring.len
        # insert: -----------overlap-end-------------------
        markedst.insert(overlapsendst, curposit)
        # update cur-pos
        curposit = curposit + overlapsendst.len
        allsubstringsq.addunique(matchob.substring)
        previousposit = curposit

      else:   # should never happen
        echo "Could not find match for following data:"
        echo "cyclit = " & $cyclit
        echo "matchob.substring = " & matchob.substring
        echo "curposit = " & $curposit
        echo "\p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\p"
        curposit = previousposit

        result = markedst

    startA_previous = matchob.startA

  if debugbo: echo "\p\p\p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\p"

  result = markedst

  # later:
  # write the updated filestring to disk with some suffix
  # write the original file to some updated name-suffix


# =========================================================================

var minLen: int = 20
echo "Enter Minimal overlap-length (press Enter for " & $minLen & "): "
let inputst = readLine(stdin)
if inputst.len != 0: 
  minLen = parseInt(inputst)


# put the new file in 01.txt
var 
  filename1st: string = "01.txt"
  filename2st: string = "02.txt"
  file1st, file2st: string

# open file 1 and 2
file1st = readFile(filename1st)
file2st = readFile(filename2st)

let matches = findCommonSubstrings(file1st, file2st, minLen)

# firstly write the overlaps to a file
var outputst: string = ""

for match in matches:
  outputst &= match.substring & "\n\n"

writeFile("overlaps.txt", outputst)

# secondly echo to screen from here
echo "\n\n"
echo getStringStats(file1st, "File 01.txt")
echo getStringStats(file2st, "File 02.txt")
echo "\n"
echo "Minimal overlap-length: " & $minLen


for match in matches:
  echo "\n================ Overlap ============================"
  echo "A-", match.startA, "  L-", match.length, "  B-", match.startB
  echo "------------------------------------------------------"
  echo "\"", match.substring, "\""

echo "\p\p*********************************************************************************************************************************"
echo "*********************************************************************************************************************************\p\p"

echo markOverlapsInFile(file1st, file2st, minLen)

