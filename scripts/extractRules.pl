#!/usr/bin/perl -w

# Scans a BioHEL output file and identifies when the rule set is printed. It sends it to STDOUT and discards the rest

my $found=0;

while(<STDIN>) {
	chomp;
	if(/^Phenotype/) {
		$found=1;
		next;
	}
	if($found) {
		if(/^[0-9]/) {
			s/^[0-9]+://g;
			print "$_\n";
		} else {
			$found=0;
		}
	}
}
