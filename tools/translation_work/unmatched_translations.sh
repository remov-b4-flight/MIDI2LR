#!/bin/bash
echo "

This script identifies translation strings in the lua files that are not
matched by translation strings in Lightroom. Strings should not show up in the
output. Those that do are evidence that Lightroom has removed the translation
and a new translation is needed. Results will be in unmatched.txt."
if [[ ! -f TranslatedString.txt ]] ; then
    echo -e '

For this to run properly, you must copy
TranslatedStrings.txt from the 
Adobe/Adobe Lightroom Classic/Resources/de 
directory into this directory.
\e[1;31mFile "TranslatedStrings.txt" not found\e[0m, aborting.'
    exit
fi
grep -Poh '\$\$\$/(?!MIDI2LR)[^=]*=' ../../src/plugin/*.lua | sort | uniq > matches.txt
grep -oFf matches.txt TranslatedStrings.txt | grep -vFf - matches.txt > unmatched.txt
echo "This part identifies MIDI2LR translation strings that are not matched in the
translation strings provided by MIDI2LR. Unmatched strings are in
unmatchedMIDI2LR.txt."
grep -oh '\$\$\$/MIDI2LR[^=]*=' ../../src/plugin/*.lua | sort | uniq  > m2matches.txt
grep -oFf m2matches.txt ../../data/plugin/TranslatedStrings_en.txt | grep -vFf - m2matches.txt > unmatchedMIDI2LR.txt
rm matches.txt
rm m2matches.txt
echo "Strings in c++ files are in cpp.txt. Some strings may be truncated."
grep -Poh '(?<=juce::translate\(|TRANS\()[^)]*' ../../src/application/* | sort | uniq > cpp.txt
