#!/bin/bash

# Scan BioHEL output files (*.out) in the current directory and attempts to extract the rule set produced from each fo them

for i in *.out
do 
	name=rules_`basename $i .out`.dat
	if [ ! -f $name ]
	then
		echo $i
		cat $i | extractRules.pl > ${name}
	fi
done
