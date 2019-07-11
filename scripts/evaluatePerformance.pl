#!/usr/bin/perl -w

# Receives a set of predicted and real class labels and computes the accuracy and the confusion matrix for such predictions

use strict;

my @predictions=<STDIN>;
chomp @predictions;

my $agent=&initializeAgent;

foreach my $line (@predictions) {
	my @values=split(/ /,$line);
	if(defined $values[0] and defined $values[1]) {
		&addPrediction($agent,$values[1],$values[0]);
	} else {
		die "Wrong prediction |$line|";
	}
}

&dumpStats($agent);


sub initializeAgent {
        my %agent;
        $agent{total}=0;
        $agent{correct}=0;

        return \%agent;
}

sub addPrediction {
        my $agent=shift @_;
        my $realClass=shift @_;
        my $predClass=shift @_;

        $agent->{total}++;
        if($realClass eq $predClass) {
                $agent->{correct}++;
        } else {
                $agent->{error}++;
        }

        $agent->{confMatrix}{$realClass}{$predClass}=0
		if(not defined $agent->{confMatrix}{$realClass}{$predClass});

        $agent->{confMatrix}{$realClass}{$predClass}++;
}

sub computeAcc {
        my $agent=shift @_;

        return $agent->{correct}/$agent->{total};
}


sub dumpStats {
        my $agent=shift @_;

        my $acc=$agent->{correct}/$agent->{total};
        print "Acc on dataset $acc\n";

        my @classes=sort keys %{$agent->{confMatrix}};
        print "Confusion matrix. Rows = real class, Columns = pred. class\n";

        print "\t";
        foreach (@classes) {
                print "$_\t";
        }
        print "\n";
        print "-"x8;
        foreach (@classes) {
                print "-"x8;
        }
        print "\n";

        foreach my $c1 (@classes) {
                print "$c1|\t";
                foreach my $c2 (@classes) {
        		$agent->{confMatrix}{$c1}{$c2}=0 
				if(not defined $agent->{confMatrix}{$c1}{$c2});
                        print "$agent->{confMatrix}{$c1}{$c2}\t";
                }
                print "\n";
        }

}



