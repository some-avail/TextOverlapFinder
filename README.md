## TextOverlapFinder

### Intro

TextOverlapFinder (TOF) enables you to find textual matches between two text-files. As opposed to the Linux diff command, which finds differences between texts, tof finds matches between texts. 


### Use-cases

- my primary use-case was to compare two journalistic stories on the same subject to see which parts overlap (are identical) and which are unique to each story.
- larger overlaps usually point to a common source which both stories have used.
- in scientific studies generally you can quickly assess the overlapping information, and by that the unique information being the rest.
- you can use the program to check for plagiarism.
- from 0.68 onward you can use fuzzy compare. By that you can determine equal forms and subjects (aot equal / common sources). However the fuzzy comparison is still experimental concerning its beta-quality.


### Latest

Tof 2.0 is a new version of tof that can handle larger files. Tof <= 1 could not handle large files and on Linux would be OOM-ed (out-of-memory (oom) killing of programs that use to much memory) for files > 40 K on my 8 GB laptop. Tof 2.0 now has a line-based algorithm that avoids much memory-usage.

### Installation

- install Nim
- tof has no external dependencies.
- compile the with: nim c -d:release tof.nim
- or compile and run in one pass: nim c -r tof.nim
- run with: ./tof or ./tof.exe
- futurally compilates may be delivered.


### Usage

- in the dir where you have placed the executable tof (linux) or tof.exe (windows), you must place the files:
  - 01.txt, and
  - 02.txt
- in these text-files you must paste the texts you want compare for overlaps / matches.
- open a terminal and enter ./tof or ./tof.exe
- upon running, you must enter the minimal length of strings you want to compare to become matches. (if you enter 3, then the word "the" would become a match, which would not be very usefull). Experiment with different lengths.
- let the program run.


### Commands and options

You can run the exec without options, but there are also the following options available:
<pre>```
-a or --accuracy; example -a:80

Normally accuracy is 100 % meaning no match-deviations are allowed.
When smaller that 100 (%), lets say 80 %, only 80 % of the characters must be matching.
(there are also other factors considered.)
Thus a fuzzy comparison arises (for now only beta-quality). Defaults to 100.
-----------------------------------------------------------------

-b or --boundary_insertion_type; example -b:20

The number indicates the boundary-length between short and long overlap-indicators / mark-ups. 
In the example, matches smaller than 20 are given small mark-ups, 
matches larger than 20 are given large mark-ups.
-----------------------------------------------------------------

-l or --length-minimum; example -l:20

You can input the minimal lenghth of matching strings to be included in the list of matches. start with like 15 and experiment for the results. Defaults to 15.
-----------------------------------------------------------------

-p or --project; example -p:yourproject

Adding a project-name enables Tof to create two extra files to collect the matches from multiple comparisons. The files are:

1) project_yourproject_cumulative-matches.txt, and
2) project_yourproject_cumulative-matches_processed.txt

File 1 expands as new matches are added. File 2 is reworking of file 1 by trimming borders, removing dupicates and sorting the result. Available for Tof >= 2.16.
-----------------------------------------------------------------

-s or --skip-part; 

examples: 
-s:e
-s:e,a
-s:s
--skip-part:write_any_file

The following skippable items exist: 
* e, or echo_file_insertions - meaning skip on-screen rendering of the first file with inserted matches (show only the matches themselves on-screen).
* a, or write_any_file - meaning skip writing / saving any file, either first or second (reverse) pass (only show results to screen)
* s, or write_second_file - meaning skip writing / saving files of the reverse processing (skip the reverse pass and the saving of files in that pass)

This option allows multiple skippings separated by a comma as seen in the examples. File-writes are skippable from Tof >= 2.16.
-----------------------------------------------------------------

-u or --use-alternate-source; example -u

Instead of the text-files 01.txt and 02.txt, use marked files from the file-list "source_files.dat". Marking is done by prefixing an asterisk * before the two files you want to compare. The first two encountered marked ones will be used, others will be discarded. If not two files are pre-starred the program will report that and exit. No space between asterisk and filename is allowed.

```</pre>


### Output

The output contains two parts:
- the first part shows the match-data between files:
  - stats:
    - starting-char of the match in the first text
    - length of the match
    - starting-char of the match in the second text
  - the actual match; a substring (that is like a sentence or paragraph depnding on the minimal length)
- the second part shows a representation of the first file where all the matching segments are marked as such, like so: 

unique text-frag of file1

----overlap start----

matching fragment

----overlap end -----

following unique frag of file1

etc.

- furthermore from 0.65 onward, results of the comparison are -besides echoing to screen- written to a subdirectory named: previous_comparisons


### Done

- write results to files.
- implement a command-structure with options.
- added fuzzy compare (beta)
- added large-files-handling (>= 2.0)


### Future

Future-plans:
- deliver executable for windows

