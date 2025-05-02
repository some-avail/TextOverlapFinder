## TextOverlapFinder

### Intro

TextOverlapFinder (TOF) enables you to find textual matches between two text-files. As opposed to the Linux diff command, which finds differences between texts, tof finds matches between texts. 

### Use-cases

- my primary use-case was to compare two journalistic stories on the same subject to see which parts overlap (are identical) and which are unique to each story.
- you can use the program to check for plagiarism.


### Usage

As a starting-app the interface is still limited (0.5). 
- in the dir where you have placed the executable tof (linux) or tof.exe (windows), you must place the files:
  - 01.txt, and
  - 02.txt
- in these text-files you must paste the texts you want compare for overlaps / matches.
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



### Future

Future-plans:

- implement a command-structure with options.
- write results to files.
