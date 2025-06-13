# Starting with 2 files to compare for overlapping texts.
# Tof version 2 is an update for large files by usage of a line-based algorithm.



import std/[strutils, sequtils, algorithm, times, parseopt, math, tables, os]
import std/private/[osdirs,osfiles]

#import unicode
import jolibs/generic/[g_templates]

var versionfl: float = 2.13

# sporadically updated:
var last_time_stamp: string = "2025-06-13 22.43"

#wispbo: bool = true


type
  Match = object          # old-style object futurally to be replaced by StringMatch (below)
    substring: string
    substrB: string
    startA: int
    startB: int
    length: int


  StringMatch = object      # a common substring found in two compared strings (for file-based lineless designation)
    asubst: string      # matching subst in file A
    bsubst: string      # matching subst in file B (only relevant for fuzzy compare)
    astartit: int       # character-position where the subst starts in file a
    bstartit: int       # character-position where the subst starts in file b
    lengthit: int      # length of subst in a and b



  FileLineData = object   # file-data to convert / calculate linedata to stringdata
    lineindexit: int   # cumulative index-position at start of line
    linelenghtit: int    # length of line (including or excluding linebreaks?)


  LineMatch = object  # substring-match between to lines of file a and b
    asubst: string    # matching subst in file A
    alineit: int      # line-number
    acharit: int      # line-char-position where subst starts
    bsubst: string
    blineit: int
    bcharit: int
    lengthit: int    # length of subst a and b
    is_continuation_frombo: bool  # is continuation from previous line-match
    continues_to_lineit: int    # the match continues until this line



  ConCatStyle = enum
    ccaNone               # no extras
    ccaLineEnding         # with \p
    ccaLineEndingDouble   # with \p\p


  CleanStyle = enum
    cleanAllButStripes    # remove all white-repetition + replace with stripes
    cleanSingleWhiteSpace   # remove all white-repetition


  WhichFilesToProcess = enum
    whFileOne
    whFileTwo
    whBothFiles

  Skippings = enum
    skipNothing
    skipEchoFileInsertions

var 
  afiledata: Table[int, FileLineData]
  bfiledata: Table[int, FileLineData]




proc isWordChar(c: char): bool =

  #Checks whether or not character c is alphabetical.
  #This checks a-z, A-Z ASCII characters only. Use Unicode module for UTF-8 support.

  #return c.isAlpha()
  return c.isAlphaAscii()




proc trimToFullWords(mainst: string): string =
  # ai-inspired
  # working is dubious
  # the idea is to clip partial words and spaces of the front and the rear


  var startit = 0
  var stopit = mainst.len

  # determine the number of frontal chars to be trimmed (by incrementing)
  while startit < mainst.len and isWordChar(mainst[startit]):
    if startit == 0 or not isWordChar(mainst[startit - 1]):
      break
    inc startit

  # determine the number of rearal chars to be trimmed (by decrementing)
  while stopit > 0 and isWordChar(mainst[stopit - 1]):
    if stopit == mainst.len or not isWordChar(mainst[stopit]):
      break
    dec stopit

  if startit < stopit:
    result = mainst[startit ..< stopit].strip()
  else:
    result = ""





proc charMatchScore(first, secondst: string): float =
  let firstlen = first.len
  let seclen = secondst.len
  let lengthmaxit = max(firstlen, seclen)

  if lengthmaxit == 0:
    return 1.0  # both strings empty → 100% match

  var matchcountit = 0
  for indexit in 0 ..< min(firstlen, seclen):
    if first[indexit] == secondst[indexit]:
      inc matchcountit

  let scorefl = matchcountit.float / lengthmaxit.float
  return scorefl



proc fuzzyMatch(first, secondst: string; min_percentit: int): bool =

  #[
    - Two strings match when the percentage of char-matches > min_percentit
    - added a penalty if a string has many spaces thru spacemetricfl because short words are usually less relevant
  ]#

  let lengthmaxit = max(first.len, secondst.len)

  if lengthmaxit == 0:
    result = true  # both strings empty → 100% match

  var matchcountit = 0
  let lenminit = min(first.len, secondst.len)

  var spacecountit: int = 0

  for indexit in 0 ..< lenminit:
    if first[indexit] == secondst[indexit]:
      inc matchcountit
      if first[indexit] == ' ':
        inc spacecountit

  # the size of the coefficient determines the severeness of the penalty of many spaces / short words
  var spacemetricfl: float = 1 + 2*(spacecountit / lenminit)

  let percentfl = 100 * matchcountit.float / lengthmaxit.float
  if int(round(percentfl / spacemetricfl))  >= min_percentit:
    result = true
  else:
    result = false




proc findLinematches(afilepathst, bfilepathst: string; minlengthit: int; fuzzypercentit: int = 100): seq[LineMatch] = 

  #[
    From 2 text-files, find the matching substrings per line by comparing all the lines and store the matches in a sequence of objects of type LineMatch.
  ]#


  #LineMatch = object  # match between to lines of file a and b
  #  asubst: string    # matching subst in file A
  #  alineit: int      # line-number
  #  acharit: int      # line-char-position where subst starts
  #  bsubst: string
  #  blineit: int
  #  bcharit: int
  #  lengthit: int


  var 
    afileob, bfileob: File
    alinelenit, blinelenit: int
    lensq: seq[seq[int]]
    linematchsq: seq[LineMatch] = @[]
    lmob: LineMatch
    alinecountit: int = 0
    blinecountit: int = 0
    foundbo: bool = false

  #try:
  # open the file for reading
  echo "Searching line-matches.."
  echo "Searching - phase 1/2"

  if open(afileob, afilepathst, fmRead) and open(bfileob, bfilepathst, fmRead):
    for alinest in afileob.lines:
      alinecountit += 1
      #echo alinecountit, "-a- ", alinest
      blinecountit = 0    # reset
      alinelenit = alinest.len

      setFilePos(bfileob, 0)
      for blinest in bfileob.lines:
        blinecountit += 1
        #if alinecountit == 1:
        #  echo blinecountit, "-b- ",blinest

        # check for a substring-match between the lines
        # if a match exists add it to the line-matches

        blinelenit = blinest.len

        # var lensq is 2D-sequence of int that contains the incremental length of the 
        # substring under investigation.
        lensq = newSeqWith(alinelenit + 1, newSeq[int](blinelenit + 1))

        # string-comparison is done incrementally per letter;
        # if all letters are the same and lenghth > minlen the subst is added to matches
        for ait in 1..alinelenit:
          for bit in 1..blinelenit:

            if fuzzypercentit == 100:     # asubst == bsubst

              if alinest[ait - 1] == blinest[bit - 1]:      

                lensq[ait][bit] = lensq[ait - 1][bit - 1] + 1

                if lensq[ait][bit] >= minLengthit:
                  #foundbo = true
                  lmob = LineMatch()    # reset object
                  lmob.lengthit = lensq[ait][bit]
                  lmob.acharit = ait - lmob.lengthit   # starting-point
                  lmob.alineit = alinecountit
                  lmob.asubst = alinest[lmob.acharit ..< ait]
                  lmob.blineit = blinecountit
                  lmob.bcharit = bit - lmob.lengthit
                  linematchsq.add lmob

              else:
                lensq[ait][bit] = 0


            else:   # do fuzzy comparison
              lensq[ait][bit] = lensq[ait - 1][bit - 1] + 1

              if lensq[ait][bit] >= minLengthit:
                lmob = LineMatch()    # reset object
                lmob.lengthit = lensq[ait][bit]
                lmob.acharit = ait - lmob.lengthit   # starting-point
                lmob.alineit = alinecountit
                lmob.asubst = alinest[lmob.acharit ..< ait]
                lmob.bcharit = bit - lmob.lengthit

                lmob.bsubst = blinest[lmob.bcharit ..< bit]
                lmob.blineit = blinecountit
                if fuzzyMatch(lmob.asubst, lmob.bsubst, fuzzypercentit):
                  linematchsq.add lmob
                else:
                  lensq[ait][bit] = 0

  echo "Searching - phase 2/2"

  # Filter: only keep the longest unique, non-overlapping substrings 
  linematchsq = linematchsq.sortedByIt(-it.lengthit)  # largest ones get above
  var filtered: seq[LineMatch] = @[]

  for m in linematchsq:
    # Only add a match if filtered doesnt have allready a larger / equal one in it that 
    # starts at or before the other one [= full overlap / substring]
    if not filtered.anyIt(it.alineit == m.alineit and it.acharit <= m.acharit and it.acharit + it.lengthit >= m.acharit + m.lengthit):
      filtered.add m
      #wisp(m.substring)

  filtered = filtered.sortedByIt((it.alineit, it.acharit))

  var updated: seq[LineMatch] = @[]

  # previous match
  var prevob: LineMatch
  var firstpassbo: bool = true


  #remove (partially) overlapping matches
  for limob in filtered:
    # no (partially) overlapping matches on the same line
    if limob.alineit == prevob.alineit:
      if limob.acharit > (prevob.acharit + prevob.lengthit):
        updated.add limob
    else:
      updated.add limob
    prevob = limob



  ##remove (partially) overlapping matches
  #for m in filtered:
  #    # trim non-letter characters from the substrings
  #    var clean = m
  #    clean.asubst = trimToFullWords(m.asubst)
  #    clean.lengthit = clean.asubst.len
  #    if clean.lengthit >= minlengthit:
  #      if firstpassbo:
  #        updated.add clean
  #        firstpassbo = false
  #      else:
  #        # no (partially) overlapping matches
  #        if clean.alineit == prevob.alineit:
  #          if clean.acharit > (prevob.acharit + prevob.lengthit):
  #            updated.add clean
  #        else:
  #          updated.add clean
  #      prevob = clean




  echo "comparison complete!"

  #result = filtered
  result = updated






proc convertToStringMatches(linematchsq: var seq[LineMatch]; afilepathst, bfilepathst: string, fuzzypercentit = 100): seq[StringMatch] =

  #[ 
  Convert the linematches to string-matches. This means seeing and storing the line-matches as an entire file and using file-character-positions instead of line-nrs and line-char-positions.

  ADAP FUT:
  v-extend bsubst for overflows as well

  ]#
  

  var 
    sob: StringMatch
    sobsq: seq[StringMatch]
    afiledatatb: Table[int, FileLineData]
    bfiledatatb: Table[int, FileLineData]
    afileob, bfileob: File
    alinecountit, blinecountit: int = 0
    previousindexit: int = 0

    # temporary vars
    #asubst, bsubst: string
    #lengthit: int
    additionst: string
    afilest, bfilest: string
    alinelenghtit: int = -1
    prev_alineit, prev_blineit: int = -10
    secindexit: int


  echo "Converting matches..."
  echo "-------------------------------------"

  # open the files for reading and create tables with file-data
  if open(afileob, afilepathst, fmRead) and open(bfileob, bfilepathst, fmRead):
    for alinest in afileob.lines:
      alinecountit += 1
      afiledatatb[alinecountit] = FileLineData(lineindexit: previousindexit, linelenghtit: alinest.len)
      previousindexit += alinest.len + "\p".len

    previousindexit = 0   # reset
    for blinest in bfileob.lines:
      blinecountit += 1
      bfiledatatb[blinecountit] = FileLineData(lineindexit: previousindexit, linelenghtit: blinest.len)
      previousindexit += blinest.len + "\p".len

    afilest = readFile(afilepathst)
    bfilest = readFile(bfilepathst)



  # determine match-continuations to following lines,
  # by setting additional lmob-fields
  # field continues_to_lineit must be set -1 or something > 0
  # field is_continuation_frombo must be set to true if applicable
  for lmob in mitems(linematchsq):
    lmob.continues_to_lineit = 0    # preset; 
    alinelenghtit = afiledatatb[lmob.alineit].linelenghtit

    # handle per case
    # match stops before end-of-line (eol)
    if lmob.acharit + lmob.lengthit < alinelenghtit:
      lmob.continues_to_lineit = -1

      if lmob.acharit > 0:    # line-local match:
        #lmob.is_continuation_frombo = false
        discard

    # match goes on till eol (end-of-line)
    # match may overflow to next line
    elif lmob.acharit + lmob.lengthit == alinelenghtit:
      prev_alineit = -10
      prev_blineit = -10
      # get continuation-info
      secindexit = 0
      for seclmob in linematchsq:

        if seclmob.alineit > lmob.alineit:

          if seclmob.acharit == 0:
            if seclmob.alineit == prev_alineit + 1 and seclmob.blineit == prev_blineit + 1:
              lmob.continues_to_lineit = seclmob.alineit
              # set the following lmob in this hacky way
              linematchsq[secindexit].is_continuation_frombo = true
            else:
              if lmob.continues_to_lineit == 0:
                lmob.continues_to_lineit = -1
              break   # old values are kept

          elif seclmob.acharit > 0:
            if lmob.continues_to_lineit == 0:
              lmob.continues_to_lineit = -1
            break
          else:
            echo "negative char-starting-points should not happen..."

          if seclmob.acharit + seclmob.lengthit < alinelenghtit:
            break

        prev_alineit = seclmob.alineit
        prev_blineit = seclmob.blineit
        secindexit += 1




    else:   # match would extend beyond line-break
      echo "Match should not extend beyond line-break..."
      wisp("should not happen...")

  # last match will never continu to another line
  if linematchsq.len > 0:
    linematchsq[linematchsq.len - 1].continues_to_lineit = -1



  # actual conversion of matches
  for lmob in linematchsq:
    #echo lmob
    if lmob.is_continuation_frombo:
      discard
      # skip because it is added to another one

    else:     # if not lmob.is_continuation_frombo:


      if lmob.continues_to_lineit == -1:
        #wisp("-1:  ", lmob)

        sob = StringMatch()
        sob.asubst = lmob.asubst
        sob.bsubst = lmob.bsubst
        sob.astartit = afiledatatb[lmob.alineit].lineindexit + lmob.acharit
        sob.bstartit = bfiledatatb[lmob.blineit].lineindexit + lmob.bcharit
        sob.lengthit = lmob.lengthit
        sobsq.add(sob)

      elif lmob.continues_to_lineit == 0:
        echo "lmob.continues_to_lineit should not be zero..."

      else:   # lmob.continues_to_lineit > 0
        additionst = ""

        for seclmob in linematchsq:

          if seclmob.alineit >= lmob.alineit and seclmob.alineit < lmob.continues_to_lineit:
            additionst &= seclmob.asubst & "\p"
          elif seclmob.alineit == lmob.continues_to_lineit:
            additionst &= seclmob.asubst

        #wisp("> 0:  ", lmob)

        sob = StringMatch()
        sob.asubst = additionst
        sob.astartit = afiledatatb[lmob.alineit].lineindexit + lmob.acharit
        sob.bstartit = bfiledatatb[lmob.blineit].lineindexit + lmob.bcharit
        sob.lengthit = sob.asubst.len
        if sob.bstartit + sob.lengthit < bfilest.len and fuzzypercentit < 100:
          sob.bsubst = bfilest[sob.bstartit .. sob.bstartit + sob.lengthit]

        sobsq.add(sob)

  sobsq = sobsq.sortedByIt(it.astartit)

  result = sobsq



proc newToOldMatch(sobsq: seq[StringMatch]): seq[Match] = 

  # allthoe a new and improved StringMatch-object has been created, the old code still works with the old-style object, so the objects must be backported for now..

  var 
    mobsq: seq[Match]
    mob: Match
  
  echo "Backporting ..."

  for sob in sobsq:
    mob.substring = sob.asubst
    mob.substrB = sob.bsubst
    mob.startA = sob.astartit
    mob.startB = sob.bstartit
    mob.length = sob.lengthit

    mobsq.add(mob)

  result = mobsq




proc findCommonSubstrings(a, b: string; minLen: int; fuzzypercentit: int = 100): seq[Match] =
  #[ 
    DEPRECATED - no longer used
    This string- / file-based algorithm used too much memory
    Replaced by line-based algo. findLinematches

    - a en b are strings to compare on overlapping substrings.
    - the overlaps will be returned in seq of object Match
    - minLen is the minimal length for string to be added to the matches
    (>15 or 30 recommended; "the" or "have" are not very relevant overlaps)
    - for now a is the new file you want to review
    (because currently the matches are sorted on the a-file order)
  ]#

  wispbo = true
  #var debugbo: bool = true
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
    wisp("i = ", $i)

    for j in 1..m:
      wisp("j = ", $j)

      if fuzzypercentit == 100:
        if a[i - 1] == b[j - 1]:      
          wisp("a[i - 1] = ", $a[i - 1])
          wisp("b[j - 1] = ", $b[j - 1])

          dp[i][j] = dp[i - 1][j - 1] + 1
          wisp("dp[i][j] = ", $dp[i][j])

          if dp[i][j] >= minLen:
            let length = dp[i][j]
            let startA = i - length
            let startB = j - length
            let substr = a[startA ..< i]
            rawMatches.add Match(substring: substr, startA: startA, startB: startB, length: length)
        else:
          dp[i][j] = 0

      else:   # do fuzzy comparison
        dp[i][j] = dp[i - 1][j - 1] + 1
        if dp[i][j] >= minLen:     
          let length = dp[i][j]
          let startA = i - length
          let startB = j - length
          let substringA = a[startA ..< i]
          let substringB = b[startB ..< j]
          if fuzzyMatch(substringA, substringB, fuzzypercentit):
            rawMatches.add Match(substring: substringA, substrB: substringB, startA: startA, startB: startB, length: length)
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

  # this concerns a frontal slice
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
  outst = namest & " (" & safeSlice(cleanFile(tekst), 40) & "...) has " & $tekst.splitLines.len  & " lines, " & $tekst.splitWhitespace.len & " words,and " & $tekst.len & " characters."  
  outst &= "\p-------------------------------------"

  result = outst




proc markOverlapsInFile(first, secondst: string; minLengthit: int; matchobsq: seq[Match], boundary_lengthit: int = 40; messagest: string = ""): string =
  #[
    Insert into the first string (from file1) overlap-indicators from the overlaps (matchobsq) with the second string and return the new marked-up first string (file-text).
  ]#
  # the boundary defined between short and long overlap-indicators
  # put the new file in 01.txt

  wispbo = false
  var markedst: string = first

  # set cur-pos = 0
  var cyclit: int = 0
  var curposit: int = 0
  var previousposit: int = 0
  var overlapstartst: string = "\p<br>======================overlap-start===========================\p"
  var overlapsendst: string =  "\p----------------------overlap-end-----------------------------\p"
  var shortoverlapstartst: string = " ~**** "
  var shortoverlapendst: string = " ****~ "


  var debugbo: bool = false

  if debugbo: echo "matchobsq.len = " & $matchobsq.len & "\p"

  var startA_previous: int = -1

  var notfoundcountit: int = 0
  #var boundary_lengthit: int = 40    # the boundary defined between short and long overlap-indicators

  echo "\p\pCreating comparison-file (inserting overlap-indicators) for the " & messagest &  " file....\p\p"


  for matchob in matchobsq:

    cyclit += 1

    if debugbo: echo "cyclit = " & $cyclit

    # find the subst / index from cur-pos

    if matchob.startA != startA_previous:   # sometimes multiples because of the other file B
    #if matchob.startA != startA_previous and matchob.substring notin allsubstringsq:  # why is substring uniqueness needed?

      previousposit = curposit
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



proc ccat(mainst, addst: string = ""; styleu: ConCatStyle = ccaLineEnding): string = 

  if styleu == ccaNone:
    result = mainst & addst
  elif styleu == ccaLineEnding:
    result = mainst & addst & "\p"
  elif styleu == ccaLineEndingDouble:
    result = mainst & addst & "\p\p"



proc generateTestFile() =

  const FileName = "alfabet.txt"

  # Open bestand om te schrijven
  var f = open(FileName, fmWrite)

  # Loop van 'a' tot 'z'
  for ch in 'a'..'z':
    let line = repeat($ch, 30)  # Maak een string met 10x dezelfde letter
    f.writeLine(line)

  f.close()

  echo "Bestand geschreven naar: ", FileName




proc echoHelpInfo() = 

  let messagest = """

Just run ./tof or ./tof.exe to start the program.

- in the dir where you have placed the executable tof (linux) or tof.exe (windows), you must place the files:
  - 01.txt, and
  - 02.txt
- in these text-files you must paste the texts you want compare for overlaps / matches.
- open a terminal and enter ./tof or ./tof.exe
- upon running, you must enter the minimal length of strings you want to compare to become matches. (if you enter 3, then the word "the" would become a match, which would not be very usefull). Experiment with different lengths.
- from 2.1 onward you can use the file-list 'source_files.dat' to use alternate source (see option -u)

To adjust defaults, use one of the below options:

-a or --accuracy; example -a:80

Normally accuracy is 100 % meaning no match-deviations are allowed.
When smaller that 100 (%), lets say 80 %, only 80 % of the characters must be matching.
(there are also other factors considered.)
Thus a fuzzy comparison arises (for now only beta-quality). Defaults to 100.

-b or --boundary_insertion_type; example -b:20

The number indicates the boundary-length between short and long overlap-indicators / mark-ups. 
In the example, matches smaller than 20 are given small mark-ups, 
matches larger than 20 are given large mark-ups.

-l or --length-minimum; example -l:20

You can input the minimal lenghth of matching strings to be included in the list of matches. start with like 15 and experiment for the results. Defaults to 15.

-s or --skip-part; example -s:e

only one skippable item exists yet: e, or echo_file_insertions
usefull when you are only interested in the matches to be printed to the screen.

-u or --use-alternate-source; example -u

Instead of the text-files 01.txt and 02.txt, use marked files from the file-list 'source_files.dat'. 
Marking is done by prefixing an asterisk * before the two files you want to compare. The first two encountered marked ones will be used, others will be discarded. If not two files are pre-starred the program will report that and exit. No space between asterisk and filename is allowed.

  """

  echo messagest



proc reportOverlap(text1st, text2st: string; matchobsq: seq[Match]; minlengthit: int; reversebo: bool = false, fuzzypercentit: int): string = 

  var overlapst: string
  overlapst = ccat("Results for Tof " & $versionfl & ":")
  if not reversebo:
    overlapst = ccat(overlapst, getStringStats(text1st, "File 01.txt or alt.1"))
    overlapst = ccat(overlapst, getStringStats(text2st, "File 02.txt or alt.2"))
  else:
    overlapst = ccat(overlapst, getStringStats(text1st, "File 02.txt or alt.2"))
    overlapst = ccat(overlapst, getStringStats(text2st, "File 01.txt or alt.1"))

  overlapst = ccat(overlapst,"")
  overlapst = ccat(overlapst, "Minimal overlap-length: " & $minlengthit)
  overlapst = ccat(overlapst, "Accuracy-percentage: " & $fuzzypercentit)
  overlapst = ccat(overlapst, "match-count = " & $matchobsq.len)


  for match in matchobsq:
    overlapst = ccat(overlapst & "\n================ Overlap ============================")
    overlapst = ccat(overlapst & "A-" & $match.startA & "  L-" & $match.length & "  B-" & $match.startB)
    overlapst = ccat(overlapst, "------------------------------------------------------")

    #overlapst = ccat(overlapst, "\"" & match.substring & "\"")
    overlapst = ccat(overlapst, match.substring)

    if match.substrB != "":
      overlapst = ccat(overlapst, "------------------------------------------------------")
      overlapst = ccat(overlapst, "\"" & match.substrB & "\"")

  overlapst = ccat(overlapst, "\p\p*********************************************************************************************************************************")
  overlapst = ccat(overlapst, "*********************************************************************************************************************************\p\p")

  result = overlapst




proc reportPureMatches(matchobsq: seq[Match]; styleeu: ConCatStyle = ccaLineEnding): string = 

  # create a list of the matches without extras to use in the cumulative file
  var matcheslist: string = ""
  for match in matchobsq:
    #matcheslist = ccat(matcheslist, "\"" & match.substring & "\"")
    matcheslist = ccat(matcheslist, match.substring, styleeu)

  result = matcheslist




proc saveAndEchoResults(minlengthit: int = 0; file_to_processeu: WhichFilesToProcess = whBothFiles; use_alternate_sourcesbo: bool = false; verbosebo: bool = true; fuzzypercentit: int = 100; skippartseu: Skippings = skipNothing, boundary_lengthit: int = 40; projectst = "") = 
  #[
    run the program
  ]#


  var minLen: int = 15
  var validbo: bool = false
  if minLengthit == 0:
    echo "Enter Minimal overlap-length (press Enter for " & $minLen & "): "
    while not validbo:
      let inputst = readLine(stdin)
      if inputst.len != 0: 
        if inputst.all(isDigit):
          minLen = parseInt(inputst)
          if minlen < 4:
            minLen = 4
            echo "Minimal minimal length = 4; using 4 ..."
          validbo = true
      else:
        break
  else:
    minLen = minlengthit



  # put the new file in 01.txt
  var 
    filename_orig_1st: string = "01.txt"
    filename_orig_2st: string = "02.txt"

    filename1st: string = "first.txt.tmp"
    filename2st: string = "sec.txt.tmp"

    text1st, text2st, tmp1st, tmp2st: string

    alt_filename1st, alt_filename2st: string    # can also be a path

    alter_source_filest: string
    alt_lisq, starlisq: seq[string]
    alter_invalidbo: bool = false
    altnamepart1st, altnamepart2st: string

  const source_filenamest = "source_files.dat"


  if use_alternate_sourcesbo:
    alter_source_filest = readFile(source_filenamest)
    alt_lisq = alter_source_filest.splitLines()
    for sourcest in alt_lisq:
      if "*" in sourcest:
        starlisq.add(sourcest)

    if starlisq.len >= 2:
      # open file 1 and 2 using the toppal starred items
      alt_filename1st = starlisq[0].split("*")[1]
      alt_filename2st = starlisq[1].split("*")[1]
      altnamepart1st = extractFilename(alt_filename1st)
      altnamepart2st = extractFilename(alt_filename2st)
      tmp1st = readFile(alt_filename1st)
      tmp2st = readFile(alt_filename2st)
  
    else:
      alter_invalidbo = true
      echo "One needs minimally 2 pre-starred items in the " & source_filenamest & " to compare (like: *filename)"

  else:
    # open file 1 and 2
    tmp1st = readFile(filename_orig_1st)
    tmp2st = readFile(filename_orig_2st)



  if (not use_alternate_sourcesbo and not(tmp1st == "" or tmp2st == "") or 
    use_alternate_sourcesbo and not alter_invalidbo):


    #pre-clean the files
    echo "start pre-cleaning files..."
    text1st = cleanFile(tmp1st, cleanSingleWhiteSpace)
    text2st = cleanFile(tmp2st, cleanSingleWhiteSpace)

    #text1st = tmp1st
    #text2st = tmp2st

    tmp1st = ""
    tmp2st = ""

    echo "writing cleaned files..."
    writeFile(filename1st, text1st)
    writeFile(filename2st, text2st)

    # open file 1 and 2
    text1st = readFile(filename1st)
    text2st = readFile(filename2st)


    
    var 
      compared_01tekst, compared_02tekst: string
      messagest: string
      subdirst = "previous_comparisons"
      filepath_original_01tekst, filepath_original_02tekst: string
      filepath_overlap1st, filepath_overlap2st, filepath_compared_01tekst, filepath_compared_02tekst: string
      timestampst: string
      firstchars01st, firstchars02st: string
      overlap1st, overlap2st, pure_matchest: string = ""



    var lmobsq: seq[LineMatch]
    lmobsq = findLinematches(filename1st, filename2st, minLen, fuzzypercentit)
    let matchobsq = newToOldMatch(convertToStringMatches(lmobsq, filename1st, filename2st, fuzzypercentit))


    overlap1st = reportOverlap(text1st, text2st, matchobsq, minLen, false, fuzzypercentit)
    echo ""
    echo overlap1st

    compared_01tekst = markOverlapsInFile(text1st, text2st, minLen, matchobsq, boundary_lengthit, "FIRST")
    
    createDir(subdirst)

    timestampst = format(now(), "yyyyMMdd'_'HHmm")

    if not use_alternate_sourcesbo:

      firstchars01st = safeSlice(cleanFile(text1st), 50)
      firstchars02st = safeSlice(cleanFile(text2st), 50)

      filepath_original_01tekst = subdirst & "/" & timestampst & "_orig_01_" & firstchars01st & ".txt" 
      filepath_original_02tekst = subdirst & "/" & timestampst & "_orig_02_" & firstchars02st & ".txt" 

      filepath_compared_01tekst = subdirst & "/" & timestampst & "_compared_01_" & firstchars01st & ".txt"
      filepath_compared_02tekst = subdirst & "/" & timestampst & "_compared_02_" & firstchars02st & ".txt"

    else:     # use alternate source-list

      firstchars01st = safeSlice(cleanFile(text1st), 25)
      firstchars02st = safeSlice(cleanFile(text2st), 25)

      filepath_original_01tekst = subdirst & "/" & timestampst & "_orig_alt1_" & altnamepart1st & "_" & firstchars01st & ".txt" 
      filepath_original_02tekst = subdirst & "/" & timestampst & "_orig_alt2_" & altnamepart2st & "_" & firstchars02st & ".txt" 

      filepath_compared_01tekst = subdirst & "/" & timestampst & "_comp_alt1_" & altnamepart1st & "_" & firstchars01st & ".txt"
      filepath_compared_02tekst = subdirst & "/" & timestampst & "_comp_alt2_" & altnamepart2st & "_" & firstchars02st & ".txt"


    filepath_overlap1st = subdirst & "/" & timestampst & "_tof-" & $versionfl & "_matches01.txt"
    filepath_overlap2st = subdirst & "/" & timestampst & "_tof-" & $versionfl & "_matches02.txt"
    
    var filepath_purematchest: string
    filepath_purematchest = subdirst & "/" & timestampst & "_tof-" & $versionfl & "_pure-matches.txt"
    var filepath_cumulativest: string
    filepath_cumulativest = subdirst & "/project_" & projectst & "_accumulative-matches.txt"

    if not use_alternate_sourcesbo:
      copyFile("01.txt", filepath_original_01tekst)
      copyFile("02.txt", filepath_original_02tekst)
    else:
      copyFile(alt_filename1st, filepath_original_01tekst)
      copyFile(alt_filename2st, filepath_original_02tekst)


    writeFile(filepath_overlap1st, overlap1st)
    writeFile(filepath_compared_01tekst, compared_01tekst)

    if fuzzypercentit == 100:
      pure_matchest = reportPureMatches(matchobsq, ccaLineEndingDouble)
      writeFile(filepath_purematchest, pure_matchest)    
      if projectst != "":

        var cumul_tekst: string 
        if fileExists(filepath_cumulativest):
          cumul_tekst = readFile(filepath_cumulativest)
          cumul_tekst &= "\p" & pure_matchest
        else:
          cumul_tekst = pure_matchest
        writeFile(filepath_cumulativest, cumul_tekst)



    # for the reverse comparison (1 and 2 swapped) also the matching must be rerun
    # ? todo: instead reuse the existing one and resort
    
    #let reverse_matchobsq = findCommonSubstrings(text2st, text1st, minLen, fuzzypercentit)

    var reverse_lmobsq: seq[LineMatch]
    echo "--------------------------------------------"
    echo "Running reverse comparison..."
    echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\p"

    reverse_lmobsq = findLinematches(filename2st, filename1st, minLen, fuzzypercentit)
    let reverse_matchobsq = newToOldMatch(convertToStringMatches(reverse_lmobsq, filename2st, filename1st, fuzzypercentit))

    overlap2st = reportOverlap(text2st, text1st, reverse_matchobsq, minLen, true, fuzzypercentit)
    writeFile(filepath_overlap2st, overlap2st)

    compared_02tekst = markOverlapsInFile(text2st, text1st, minLen, reverse_matchobsq, boundary_lengthit, "SECOND")
    writeFile(filepath_compared_02tekst, compared_02tekst)



    if not (skippartseu == skipEchoFileInsertions):
      echo compared_01tekst


    messagest = "Files were written to the following subdirectory: " & subdirst
    echo "##################################################################################"
    echo messagest
  else:
    if not use_alternate_sourcesbo and (tmp1st == "" or tmp2st == ""):
      echo "One or both files (01.txt and/or 02.txt) is empty; please input texts to compare. \pProgram tof exiting..."
    elif use_alternate_sourcesbo and alter_invalidbo:
      echo "Please provide a valid " & source_filenamest & " with 2 pre-starred items...\pExiting tof..."

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
    #projectpathst: string = ""
    procst: string = "saveAndEchoResults"
    #----------------------------------
    lengthit: int = 0
    fuzzypercentit: int = 100
    skipeu: Skippings = skipNothing
    boundary_lengthit: int = 30
    use_alternate_sourcesbo: bool = false
    projectst: string = ""

  try:
    echo "----------------------------------------------------"
    echo "Thanks for using TextOverlapFinder " & $versionfl
    echo "For help type: ./tof -h or ./tof --help"
    echo "----------------------------------------------------"


    # firstly load the args from the commandline and set the needed vars 
    for kind, key, val in optob.getopt():
      case kind:
      of cmdArgument:           # without hyphen(s); not used here
        #projectpathst = key
        echo "/pYou have probably forgotten a hyphen - before your option..."
        echo "(no command-key (without hyphen) required)/p"
      of cmdShortOption, cmdLongOption:
        case key:
        of "a", "accuracy":
          if val != "" and val.all(isDigit):
            if parseInt(val) in 20..100:
              fuzzypercentit = parseInt(val)

          else:
            echo "You entered the accuracy-key(-a), but not a valid value (valid is like: -a:80 that is in range 20-100). accuracy = 100 means no fuzzyness (100 % of the chars must be matching) \pTof will continue with default-accuracy = 100 %..."

        of "b", "boundary_insertion_type":
          if val != "" and val.all(isDigit):
            boundary_lengthit = parseInt(val)
          else:
            echo "You entered the boundary-value(-b), but not a valid value (valid is like: -b:20). \pUsing default..."

        of "l", "length-minimum":
          if val != "" and val.all(isDigit):
            lengthit = parseInt(val)
            #echo "length has been set!"
          else:
            echo "You entered the length-key(-l), but not a valid value (valid is like: -l:20). \pYou can input manually now..."

        of "s", "skip-part":
          case val:
          of "e", "echo_file_insertions":
            skipeu = skipEchoFileInsertions

        of "u", "use-alternate-source":
          use_alternate_sourcesbo = true

        of "h", "help":
          procst = "echoHelpInfo"

        of "p", "project":
          if val != "":
            projectst = val
          else:
            echo "You entered an empty project-name; the cumulative matches-file cannot be updated."

      of cmdEnd: 
        assert(false) # cannot happen


    case procst
    of "saveAndEchoResults":
      saveAndEchoResults(lengthit, use_alternate_sourcesbo = use_alternate_sourcesbo, fuzzypercentit = fuzzypercentit, skippartseu = skipeu, boundary_lengthit = boundary_lengthit, projectst = projectst)
    of "echoHelpInfo":
      echoHelpInfo()


  except IOError:
    let errob = getCurrentException()
    echo "\pCannot open one or more files! 01.txt and 02.txt or alternatives from source_files.dat must be present. \pTechnical details:" 
    echo "-------------------------------------------------------"
    echo errob.name
    echo errob.msg
    echo "-------------------------------------------------------"
    echo "\pExiting program gracefully...\p"


  #unanticipated errors come here
  except:
    let errob = getCurrentException()
    echo "\p******* Unanticipated error *******" 
    echo errob.name
    echo errob.msg
    echo repr(errob)
    echo getStackTrace()
    echo "\p****End exception****\p"


var testbo: bool = false

if not testbo:
  #saveAndEchoResults()
  processCommandLine()

else:
  #echo ccat("Running Tof " & $versionfl & " ...", "")
  #echo ccat("hoofdstreng", " met een staartje", ccaNone)
  #echo "testing"

  #----------------------
  #echo cleanFile("    aap\n    noot**** mies")
  #echo safeSlice("", 2)
  #-------------------------
  #var st: string = "aap\p\p\p\pneushoorn\p\pnoot"
  #var newst: string = "aap\n\n\n\nneushoorn\n\nnoot"
  #var last: string = readFile("02.txt")

  #echo cleanFile(last, cleanSingleWhiteSpace)
  ##echo cleanFile(last, cleanAllButStripes)
  #-----------------------------

  #echo $charMatchScore("joop", "sdoglrlsldg")
  #echo fuzzyMatch("joop", "jaap", 70)
  #-----------------------------------------
  #echo findCommonSubstrings("xxxschaapyyy", "schaep", 3, 90)
  #-------------------------------
  #var 
  #  testsq: seq[LineMatch]
  #  fuzzit: int = 100
  #echo "\p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  #testsq = findLinematches("01.txt","02.txt", 15, fuzzit)
  #echo "===========================================================\p"
  #for x in testsq:
  #  echo x
  #  echo "-----------------------------------------"
  #echo "===========================================================\p"

  #var sobsq: seq[StringMatch]
  #sobsq = convertToStringMatches(testsq, "01.txt","02.txt", fuzzit)
  #for ob in sobsq:
  #  echo ob
  #  echo "-----------------------------------------"

  # "---------------------------------------------"
  #generateTestFile()


  #--------------------------------
  var sq: seq[string] = @[" aap ", "3noot5", "a mies p", "    ", "  das   ", "...kat,,"]
  for st in sq:
    echo "_" & st & "_"
    echo trimToFullWords("_" & st & "_")
  #--------------------------------

