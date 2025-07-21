## TextOverlapFinder

### Intro

TextOverlapFinder (TOF) enables you to find textual matches between two text-files. As opposed to the Linux diff command, which finds differences between texts, tof finds (partial) matches between texts. 


### Use-cases

Scientific case-based scenario:
- in scientific studies with Tof you can quickly assess related texts to extend your collection of research-texts on your research-case.
- what's in an article? Have one file as a reference-file with all the info on the case sofar and a new-file to compare it with. Run Tof to find out:
  * which matching info is in the new-file, thus profiling it.
  * find new info in the new-file by looking <u>between</u> the matches. That's where you can find the new not yet processed information.

Journalistic source-reconstruction:
- my primary use-case was to compare two journalistic stories on the same subject to see which parts overlap (are identical) and which are unique to each story.
- larger overlaps usually point to a common source which both stories have used, thus highlighting source-usage-relations.

Other uses:
- you can use the program to check for plagiarism.
- from 0.68 onward you can use fuzzy compare. By that you can determine equal forms and subjects (aot equal / common sources). However the fuzzy comparison is still experimental concerning its beta-quality.


### Latest

Tof > 2.0 is a new version of tof that can handle larger files. Tof 2 now has a line-based algorithm that avoids much memory-usage. Current version is tof 2.3.


### Installation

- install Nim
- tof has since 2.17 one external dependencies (nimclipboard)
- compile the with: nim c -d:release -d:ssl tof.nim
- or compile and run in one pass: nim c -r -d:ssl tof.nim
- run with: ./tof or ./tof.exe


### Basic usage

- in the dir where you have placed the executable tof (linux) or tof.exe (windows), you must place the files:
  - 01.txt, and
  - 02.txt
- in these text-files you must paste the texts you want to compare for overlaps / matches.
- open a terminal and enter ./tof or ./tof.exe
- upon running, you must enter the minimal length of strings you want to compare to become matches. (if you enter 3, then the word "the" would become a match, which would not be very usefull). Experiment with different lengths.
- let the program run.


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



### Projects

Since tof 2.18 you can use projects, as defined in the file projects.dat. By placing a star * right before the project you can make a project active. Append a file-path (separated with 3 underscores) where the tof-data must be stored for the project.

For the active project, all input and output will be expected and stored there, 
except for the projects.dat file and the executable. 
Only one project can be pre-starred and will be active; following stars will be ignored. 
Removing all stars will reset the data-dir to the executable-dir.

(btw this is different from the option -p:someproject which creates cumulative matches for all comps that use that option.)



### Registry of comparisons

A file registry_of_comparisons.txt is updated for every comparison whereby files are written to disk.
(>= Tof 2.17)




### Options for additional usage-possibilities


You can run the exec without options, but there are also the following options available:
```
-a or --accuracy; example -a:80

Normally accuracy is 100 % meaning no match-deviations are allowed.
When smaller that 100 (%), lets say 80 %, 
only 80 % of the characters must be matching.
(there are also other factors considered.)
Thus a fuzzy comparison arises (for now only beta-quality). 
Defaults to 100.
-----------------------------------------------------------------

-b or --boundary_insertion_type; example -b:20

The number indicates the boundary-length between short and 
long overlap-indicators / mark-ups. 
In the example, matches smaller than 20 are given small mark-ups, 
matches larger than 20 are given large mark-ups.

-----------------------------------------------------------------
-i or --internal_comp

Giving this option leads to an internal comparison, that is a comp. 
of a text with itself. It means that text of the clipboard 
is split in two halfs, these halfs are pasted in 01.txt and 02.txt, 
after which the comparison is run.
Thus a outline of the text arises. (from tof 2.173 onward)

-----------------------------------------------------------------
-l or --length-minimum; example -l:20

You can input the minimal lenghth of matching strings to be 
included in the list of matches. 
start with like 15 and experiment for the results. Defaults to 15.
-----------------------------------------------------------------

-p or --project; example -p:yourproject

Adding a project-name enables Tof to create two extra files to 
collect the matches from multiple comparisons. The files are:

1) project_yourproject_cumulative-matches.txt, and
2) project_yourproject_cumulative-matches_processed.txt

File 1 expands as new matches are added. File 2 is reworking 
of file 1 by trimming borders, 
removing dupicates and sorting the result. 
Available for Tof >= 2.16.
-----------------------------------------------------------------

-s or --skip-part; 

examples: 
-s:e
-s:e,a
-s:s
--skip-part:write_any_file

The following skippable items exist: 
* e, or echo_file_insertions - meaning skip on-screen 
rendering of the first file with inserted matches 
(show only the matches themselves on-screen).
* a, or write_any_file - meaning skip writing / saving any file, 
either first or second (reverse) pass 
(only show results to screen)
* s, or write_second_file - meaning skip writing / saving files 
of the reverse processing 
(skip the reverse pass and the saving of files in that pass)

This option allows multiple skippings separated 
by a comma as seen in the examples. 
File-writes are skippable from Tof >= 2.16.
-----------------------------------------------------------------

-u or --use-alternate-source; example -u

Instead of the text-files 01.txt and 02.txt, 
use marked files from the file-list "source_files.dat". 
Marking is done by prefixing an asterisk * before the two files 
you want to compare. 
The first two encountered marked ones will be used, 
others will be discarded. 
If not two files are pre-starred the program will report that and exit. 
No space between asterisk and filename is allowed.

```


### Batch-comparisons

Since Tof 2.2, Tof can do multiple comparisons with one command, called batch-comps. You only need:
- a folder named batch_comparisons where you have your executable (besides previous_comparisons)
- a list with weblinks, like myweblinks.lst, placed inside the folder batch_comparisons

Then you must run (on linux) either of below commands (both work since tof prepends the subdir if missing):  
./tof batch_comparisons/myweblinks.lst  
./tof myweblinks.lst

On windows you substitute ./tof.exe

The relevant output files are:  
project_myweblinks_cumulative-matches.txt  
project_myweblinks_cumulative-matches_processed.txt

Look at option -p for more info on these cumulatives.

When you use an active project (see paragraph "Projects"), you must put your myweblinks.lst in:
your_project_path/batch_comparisons/myweblinks.lst



### Future

Future-plans:
- support unicode
- deliver executable for windows

