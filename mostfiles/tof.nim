# Starting with 2 files to compare for overlapping texts.


import std/[strutils, sequtils, algorithm, times, parseopt]
import std/private/[osdirs,osfiles]

#import unicode
#import ../../joshares/jolibs/generic/[g_templates]

var versionfl: float = 0.66

# sporadically updated:
var last_time_stamp: string = "2025-05-05_15.50"

var wispbo: bool = false


type
  Match = object
    substring: string
    startA: int
    startB: int
    length: int

  ConCatStyle = enum
    ccaNone
    ccaLineEnding

  CleanStyle = enum
    cleanAllButStripes    # remove all white-repetition + replace with stripes
    cleanSingleWhiteSpace   # remove all white-repetition


  WhichFilesToProcess = enum
    whFileOne
    whFileTwo
    whBothFiles


proc isWordChar(c: char): bool =
  #return c.isAlpha()
  return c.isAlphaAscii()

proc trimToFullWords(s: string): string =
  # ai-inspired
  # working is dubious
  # the idea is to clip partial words and spaces of the front and the rear


  var start = 0
  var stop = s.len

  # determine the number of frontal chars to be trimmed (by incrementing)
  while start < s.len and isWordChar(s[start]):
    if start == 0 or not isWordChar(s[start - 1]):
      break
    inc start

  # determine the number of rearal chars to be trimmed (by decrementing)
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

  var wispbo: bool = false
  echo "starting findCommonSubstrings ..."

  let n = a.len
  let m = b.len
  echo "file 1 has " & $n & " and file 2 has " & $m & " characters..."
  echo "creating comparison-matrix ..."

  # var dp is 2D-sequence of int that contains the incremental length of the 
  # substring under investigation.
  var dp = newSeqWith(n + 1, newSeq[int](m + 1))
  var rawMatches: seq[Match] = @[]

  echo "Starting main comparison - phase 1/3..."
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



  echo "post-processing phase 2/3 ..."

  # Filter: hou alleen langste unieke, niet-overlappende substrings over
  rawMatches = rawMatches.sortedByIt(-it.length)  # largest ones get above
  var filtered: seq[Match] = @[]

  for m in rawMatches:
    # Only add a match if filtered doesnt have allready a larger / equal one in it that 
    # starts at or before the other one [= full overlap / substring]
    if not filtered.anyIt(it.startA <= m.startA and it.startA + it.length >= m.startA + m.length):
      filtered.add m
      #wisp(m.substring)

  echo "final processing phase 3/3 ..."

  # resort on occurence-order
  filtered = filtered.sortedByIt(it.startA)

  var updated: seq[Match] = @[]

  # previous match
  var prevob: Match
  var firstpassbo: bool = true


  # trim boundaries and remove (partially) overlapping matches
  for m in filtered:
      # trim non-letter characters from the substrings
      var clean = m
      clean.substring = trimToFullWords(m.substring)
      clean.length = clean.substring.len
      if clean.length >= minLen:
        if firstpassbo:
          updated.add clean
          firstpassbo = false
        else:
          # no (partially) overlapping matches
          if clean.startA > (prevob.startA + prevob.length):
            updated.add clean
        prevob = clean

  echo "comparison complete!"

  result = updated




proc singularizeSequences(mainst, subst: string): string =
  # in mainst, replace repeating occs of subst with single occs of the subst

  var tempst, outputst: string
  tempst = mainst

  # Vervang een reeks van substrings door één substring
  outputst = tempst.multiReplace([(subst & subst, subst)])  
  while (subst & subst) in outputst:
    outputst = outputst.multiReplace([(subst & subst, subst)])  # Herhaal als nodig

  result = outputst




proc cleanFile(mainst: string; cleanStyleu: CleanStyle = cleanAllButStripes): string =

  #[
    remove unwanted characters from the file and optionally replace them.
    Select a CleanStyle for what you want.
      cleanAllButStripes =  Houd alleen letters, cijfers, - en _, en vervang spatiereeksen en regeleindes door één '-'
  ]#

  var replaced, tempst: string
  tempst = mainst
  replaced = tempst.singularizeSequences(" ")
  tempst = ""
  replaced = replaced.replace(" \p", "\p")
  replaced = replaced.singularizeSequences("\p\p")
  replaced = replaced.replace(" \p", "\p")
  replaced = replaced.singularizeSequences("\p\p")

  var tmp: string = ""

  if cleanStyleu == cleanAllButStripes:
    replaced = replaced.replace("\p", "-")
    replaced = replaced.replace(" ", "-")

    for c in replaced:
      if c.isAlphaNumeric or c in {'-', '_', ' '}:
        tmp.add(c)


  if cleanStyleu == cleanSingleWhiteSpace:
    result = replaced
  else:
    result = tmp




proc safeSlice(mainst: string; slicesizeit: int): string =

  # one that is independent of size of mainst
  if slicesizeit > 0:
    if mainst.len >= slicesizeit:
      result = mainst[0..slicesizeit-1]
    else:
      result = mainst
  else:
    result = ""




proc getStringStats(tekst, namest: string): string =
  # return string-stats of tekst number of lines, words and characters

  var outst: string
  #outst = namest & " (" & tekst[0..40] & "...) has " & $tekst.splitLines.len  & " lines, " & $tekst.splitWhitespace.len & " words,and " & $tekst.len & " characters."
  outst = namest & " (" & safeSlice(cleanFile(tekst), 40) & "...) has " & $tekst.splitLines.len  & " lines, " & $tekst.splitWhitespace.len & " words,and " & $tekst.len & " characters."  
  outst &= "\p-------------------------------------"

  result = outst


proc markOverlapsInFile(first, secondst: string; minlenghthit: int; matchobsq: seq[Match]): string =
  #[
    Insert into the first string (from file1) overlap-indicators from the overlaps (matchobsq) with the second string and return the new marked-up first string (file-text).
  ]#

  # put the new file in 01.txt

  var wispbo: bool = false


  var markedst: string = first

  # set cur-pos = 0
  var cyclit: int = 0
  var curposit: int = 0
  var previousposit: int = 0
  var overlapstartst: string = "\p======================overlap-start===========================\p"
  var overlapsendst: string =  "\p----------------------overlap-end-----------------------------\p"
  var shortoverlapboundaryst: string = " **** "
  var shortoverlapstartst: string = " ~**** "
  var shortoverlapendst: string = " ****~ "


  var debugbo: bool = false

  if debugbo: echo "matchobsq.len = " & $matchobsq.len & "\p"

  var startA_previous: int = -1

  var notfoundcountit: int = 0
  var boundary_lengthit: int = 40

  echo "\p\pCreating comparison-file (inserting overlap-indicators)....\p\p"


  for matchob in matchobsq:

    cyclit += 1

    if debugbo: echo "cyclit = " & $cyclit

    # find the subst / index from cur-pos

    if matchob.startA != startA_previous:   # sometimes multiples because of the other file B
    #if matchob.startA != startA_previous and matchob.substring notin allsubstringsq:  # why is substring uniqueness needed?

      curposit = markedst.find(matchob.substring, curposit)

      if debugbo: echo "matchob.substring = " & matchob.substring
      if debugbo: echo "curposit = " & $curposit

      if curposit > -1:
        # insert mark overlap-start
        if matchob.length < boundary_lengthit:
          markedst.insert(shortoverlapstartst, curposit)

          # add up overlap-mark and match.len to index-pos and reset the index-pos
          curposit = curposit + shortoverlapstartst.len + matchob.substring.len
          # insert: -----------overlap-end-------------------
          markedst.insert(shortoverlapendst, curposit)

          # update cur-pos
          curposit = curposit + shortoverlapendst.len

        else:
          markedst.insert(overlapstartst, curposit)
          # add up overlap-mark and match.len to index-pos and reset the index-pos
          curposit = curposit + overlapstartst.len + matchob.substring.len
          # insert: -----------overlap-end-------------------
          markedst.insert(overlapsendst, curposit)

          # update cur-pos
          curposit = curposit + overlapsendst.len
        previousposit = curposit


      else:   # should never happen?
        echo "markOverlapsInFile could not find match for following data:"
        echo "cyclit = " & $cyclit
        echo "matchob.substring = " & matchob.substring
        echo "matchob.startA = " & $matchob.startA
        echo "matchob.startB " & $matchob.startB
        echo "curposit = " & $curposit
        echo "previousposit = " & $previousposit
        echo "\p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\p"
        notfoundcountit += 1
        curposit = previousposit

    startA_previous = matchob.startA

  if notfoundcountit > 0: 
    echo "\p^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
    echo "Matches not found in marking-file: " & $notfoundcountit

  if debugbo: echo "\p\p\p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\p"

  result = markedst

  # later:
  # write the updated filestring to disk with some suffix
  # write the original file to some updated name-suffix


proc ccat(mainst, addst: string = ""; styleu: ConCatStyle = ccaLineEnding): string = 

  if styleu == ccaNone:
    result = mainst & addst
  elif styleu == ccaLineEnding:
    result = mainst & addst & "\p"




proc saveAndEchoResults(minlenghthit: int = 0; file_to_processeu: WhichFilesToProcess = whBothFiles; use_alternate_sourcesbo: bool = false; verbosebo: bool = true) = 

  #[
    run the program
  ]#

  var overlapst: string = ""

  echo "\pRunning Tof " & $versionfl & " ..."

  var minLen: int = 15

  echo "Enter Minimal overlap-length (press Enter for " & $minLen & "): "
  let inputst = readLine(stdin)
  if inputst.len != 0: 
    minLen = parseInt(inputst)


  # put the new file in 01.txt
  var 
    filename1st: string = "01.txt"
    filename2st: string = "02.txt"
    text1st, text2st, tmp1st, tmp2st: string

  # open file 1 and 2
  tmp1st = readFile(filename1st)
  tmp2st = readFile(filename2st)

  #pre-clean the files
  echo "start pre-cleaning files..."
  text1st = cleanFile(tmp1st, cleanSingleWhiteSpace)
  text2st = cleanFile(tmp2st, cleanSingleWhiteSpace)

  #text1st = tmp1st
  #text2st = tmp2st

  tmp1st = ""
  tmp2st = ""

  # FOR NOW DONT CHANGE THE ORIGINAL; A CLEANED COPY IS WRITTEN TO previous_comparisons
  #echo "writing cleaned files..."
  #writeFile(filename1st, text1st)
  #writeFile(filename2st, text2st)


  let matchobsq = findCommonSubstrings(text1st, text2st, minLen)

  echo ""
  overlapst = ccat("Results for Tof " & $versionfl & ":")
  overlapst = ccat(overlapst, getStringStats(text1st, "File 01.txt"))
  overlapst = ccat(overlapst, getStringStats(text2st, "File 02.txt"))
  overlapst = ccat(overlapst,"")
  overlapst = ccat(overlapst, "Minimal overlap-length: " & $minLen)
  overlapst = ccat(overlapst, "match-count = " & $matchobsq.len)


  for match in matchobsq:
    overlapst = ccat(overlapst & "\n================ Overlap ============================")
    overlapst = ccat(overlapst & "A-" & $match.startA & "  L-" & $match.length & "  B-" & $match.startB)
    overlapst = ccat(overlapst, "------------------------------------------------------")
    overlapst = ccat(overlapst, "\"" & match.substring & "\"")

  overlapst = ccat(overlapst, "\p\p*********************************************************************************************************************************")
  overlapst = ccat(overlapst, "*********************************************************************************************************************************\p\p")

  
  var 
    compared_01tekst, compared_02tekst: string
    messagest: string
    subdirst = "previous_comparisons"
    filepath_original_01tekst, filepath_original_02tekst: string
    filepath_overlapst, filepath_compared_01tekst, filepath_compared_02tekst: string
    timestampst: string
    firstchars01st, firstchars02st: string

  echo overlapst

  compared_01tekst = markOverlapsInFile(text1st, text2st, minLen, matchobsq)
  
  createDir(subdirst)

  timestampst = format(now(), "yyyyMMdd'_'HHmm")

  firstchars01st = safeSlice(cleanFile(text1st), 25)
  firstchars02st = safeSlice(cleanFile(text2st), 25)

  filepath_original_01tekst = subdirst & "/" & timestampst & "_orig_01_" & firstchars01st & ".txt" 
  filepath_original_02tekst = subdirst & "/" & timestampst & "_orig_02_" & firstchars02st & ".txt" 
  filepath_overlapst = subdirst & "/" & timestampst & "_matches.txt"
  filepath_compared_01tekst = subdirst & "/" & timestampst & "_compared_01_" & firstchars01st & ".txt"
  filepath_compared_02tekst = subdirst & "/" & timestampst & "_compared_02_" & firstchars02st & ".txt"

  copyFile("01.txt", filepath_original_01tekst)
  copyFile("02.txt", filepath_original_02tekst)

  writeFile(filepath_overlapst, overlapst)
  writeFile(filepath_compared_01tekst, compared_01tekst)


  # for the reverse comparison (1 and 2 swapped) also the matching must be rerun
  let reverse_matchobsq = findCommonSubstrings(text2st, text1st, minLen)
  compared_02tekst = markOverlapsInFile(text2st, text1st, minLen, reverse_matchobsq)
  writeFile(filepath_compared_02tekst, compared_02tekst)


  echo compared_01tekst

  messagest = "Files were written to the following subdirectory: " & subdirst
  echo "##################################################################################"
  echo messagest


# ====================================================================================



proc processCommandLine() = 
#[
  firstly load the args from the commandline and set the needed vars 
  then run the chosen procedures.

  test: string
]#


  var 
    optob = initOptParser(shortNoVal = {'h'}, longNoVal = @["help"])
    #----------------------------------
    projectpathst, procst: string = ""
    directionst = "usage"
    depthit: int = 3
    #----------------------------------
    lengthit: int = 0
  

  try:

    # firstly load the args from the commandline and set the needed vars 
    for kind, key, val in optob.getopt():
      case kind:
      of cmdArgument:                       # without hyphen(s); used here for project-definition-file-path
        #projectpathst = key
        echo "No command-key required"
      of cmdShortOption, cmdLongOption:
        case key:
        #of "c", "command": 
        #  case val:
        #  of "a", "add_files":
        #    procst = "addSourceFilesToProject"
        #  of "d", "declarations":
        #    procst =  "createDeclarationList"
        #  of "c", "combine":                       # combine multiple projects / dec-lists (later more?)
        #    procst = "createMultiProjectFiles"
        #  of "v", "views":
        #    procst = "createAllViewFiles"
        #  of "g", "generate_all":                 # both dec-lists and view-files
        #    procst = "generate_all"
        #  of "t", "tree":
        #    procst = "showDeclarationBranch"
        #  of "s", "sourcecode":
        #    procst = "showSourceCode"
        of "l", "length-minimum":
          if val != "":
            lengthit = parseInt(val)
          else:
            echo "You entered the length-key(-l), but not the value (like: -l:20)."


        of "r", "direction":
          case val:
          of "u", "usage":
            directionst = "usage"
          of "b", "used-by":
            directionst = "used-by"          
        #of "d", "depth":
        #  if val != "":
        #    depthit = parseInt(val)
        #  else:
        #    echo "You entered the depth-key(-d), but not the value (like: -d:2)."
        of "h", "help":
          procst = "echoHelpInfo"
      of cmdEnd: 
        assert(false) # cannot happen



    echo "----------------------------------------------------"
    echo "Thanks for using CodeTwig " & $versionfl
    echo "Project-path = " & projectpathst
    echo "Chosen procedure = " & procst
    echo "For help type: ctwig -h or ctwig --help"
    echo "----------------------------------------------------"

    if procst != "":
      if projectpathst != "" or procst == "echoHelpInfo":
        discard

        #case procst
        #of "addSourceFilesToProject":
        #  echo addSourceFilesToProject(projectpathst)
        #of "createDeclarationList":
        #  createDeclarationList(projectpathst)
        #of "createMultiProjectFiles":
        #  createMultiProjectFiles(projectpathst)
        #of "createAllViewFiles":
        #  createAllViewFiles(projectpathst)
        #of "generate_all":
        #  generate_all(projectpathst)
        #of "showDeclarationBranch":
        #  showDeclarationBranch(projectpathst, directionst, depthit)
        #of "showSourceCode":
        #  showSourceCode(projectpathst)
        #of "echoHelpInfo":
        #  echoHelpInfo()

      else:
        echo "A project-file was not provided (like: projects/someproject.pro)"
    else:
      echo "A command-option was not provided (like -c=a or -c=t); exiting..."


  except IndexDefect:
    let errob = getCurrentException()
    echo "\p-----error start-----" 
    echo "Index-error caused by bug in program"
    echo "System-error-description:"
    echo errob.name
    echo errob.msg
    echo repr(errob) 
    echo "----End error-----\p"

    #unanticipated errors come here
  except:
    let errob = getCurrentException()
    echo "\p******* Unanticipated error *******" 
    echo errob.name
    echo errob.msg
    echo repr(errob)
    echo "\p****End exception****\p"




var testbo: bool = false

if not testbo:
  saveAndEchoResults()

else:
  #echo ccat("Running Tof " & $versionfl & " ...", "")
  #echo ccat("hoofdstreng", " met een staartje", ccaNone)
  #echo "testing"

  #----------------------
  #echo cleanFile("    aap\n    noot**** mies")
  #echo safeSlice("", 2)
  #-------------------------
  var st: string = "aap\p\p\p\pneushoorn\p\pnoot"
  var newst: string = "aap\n\n\n\nneushoorn\n\nnoot"
  var last: string = readFile("02.txt")

  echo cleanFile(last, cleanSingleWhiteSpace)
  #echo cleanFile(last, cleanAllButStripes)

