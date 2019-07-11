#!/usr/bin/perl -w

# Runs an ensemble on BioHEL rule sets on a test file (in ARFF format). 
# The first command line argument is the test file. All other arguments are rule set files.
# Sends its output to STDOUT as tuples <predicted class,real class> for each row in the test file

use strict;

my @args=@ARGV;
my $testSet=shift @args;
my $dumpPred=shift @args;


my $metadata=&parseMetadata($testSet);
my $instances=&parseInstances($metadata,$testSet);
my $ensemble=&parseEnsemble($metadata,@args);
&classifyInstances($metadata,$ensemble,$instances,$dumpPred);

sub parseEnsemble {
	my $metadata=shift @_;
	my @classifiers=@_;

	my @ensemble;
	foreach my $file (@classifiers) {
		my $ruleSet=&parseRuleSet($metadata,$file);
		push @ensemble,$ruleSet;
	}
	return \@ensemble;
}

sub initializeAgent {
        my $metadata=shift @_;

        my %agent;
        $agent{total}=0;
        $agent{correct}=0;
        $agent{error}=0;

        my $att=$metadata->{class};
        my @classes=@{$att->{nomValues}};

        foreach my $c1 (@classes) {
                foreach my $c2 (@classes) {
                        $agent{confMatrix}{$c1}{$c2}=0;
                }
        }

        return \%agent;
}

sub addPrediction {
        my $agent=shift @_;
        my $realClass=shift @_;
        my $predClass=shift @_;

        $agent->{total}++;
	return if(not defined $predClass);
        if($realClass eq $predClass) {
                $agent->{correct}++;
        } else {
                $agent->{error}++;
        }

        $agent->{confMatrix}{$realClass}{$predClass}++;
}

sub dumpStats {
        my $metadata=shift @_;
        my $agent=shift @_;

        my $acc=$agent->{correct}/$agent->{total};
        print "Acc on dataset $acc\n";

        my $att=$metadata->{class};
        my @classes=@{$att->{nomValues}};
        print "Confusion matrix. Rows = real class, Columns = pred. class\n";

        print "\t";
        foreach my $c1 (@classes) {
                print "$c1\t";
        }
        print "\n";
        foreach my $c1 (@classes) {
                print "-"x8;
        }
        print "\n";

        foreach my $c1 (@classes) {
                print "$c1|\t";
                foreach my $c2 (@classes) {
                        print "$agent->{confMatrix}{$c1}{$c2}\t";
                }
                print "\n";
        }

}


sub classifyInstances {
	my $metadata=shift @_;
	my $ensemble=shift @_;
	my $instances=shift @_;
	my $dumpPred=shift @_;

	my $agent=&initializeAgent($metadata);

	foreach my $instance (@{$instances}) {
		my $pred=&classifyEnsemble($metadata,$ensemble,$instance);
		my $realClass=$instance->[$metadata->{numAtt}-1];
		&addPrediction($agent,$realClass,$pred);
                if($dumpPred) {
                        print "$pred $realClass\n";
                }
	}
        if(not $dumpPred) {
                &dumpStats($metadata,$agent);
        }
}

sub classifyEnsemble {
	my $metadata=shift @_;
	my $ensemble=shift @_;
	my $instance=shift @_;

	my %votes;
	my @tied;
	my $maxVotes=0;

	foreach my $class (@{$metadata->{class}->{nomValues}}) {
		$votes{$class}=0;
	}

	foreach my $ruleSet (@{$ensemble}) {
		my $pred=&classifyInstance($metadata,$ruleSet,$instance);
		$votes{$pred}++ if(defined $pred);
	}

	foreach my $class (@{$metadata->{class}->{nomValues}}) {
		if($votes{$class}>$maxVotes) {
			splice @tied;
			push @tied,$class;
			$maxVotes=$votes{$class};
		} elsif($votes{$class}==$maxVotes) {
			push @tied,$class;
		}
	}

	return undef if($maxVotes==0);
	return $tied[int(rand(@tied))];
}

sub classifyInstance {
	my $metadata=shift @_;
	my $ruleSet=shift @_;
	my $instance=shift @_;

	foreach my $rule (@{$ruleSet->{rules}}) {
		return $rule->{class} if(&{$metadata->{matchFunc}}($rule,$instance));
	}
	return $ruleSet->{defaultClass};
}

sub ruleMatchesNominal {
	my $rule=shift @_;
	my $instance=shift @_;

	my $terms=$rule->{terms};
	foreach my $term (@{$terms}) {
		my $value=$instance->[$term->[0]];
		return 0 if($term->[2]->[$value]==0);
	}
	return 1;
}

sub ruleMatchesReal {
	my $rule=shift @_;
	my $instance=shift @_;

	my $terms=$rule->{terms};
	foreach my $term (@{$terms}) {
		my $value=$instance->[$term->[0]];

		my $max=@{$term};
		my $matched=0;
		for(my $index=2;$index<$max;$index++) {
			my $realInt = $term->[$index];
			if($realInt->[0] eq "gt") {
				if($value >= $realInt->[1]) {
					$matched=1;
					last;
				}
			} elsif($realInt->[0] eq "lt") {
				if($value <= $realInt->[1]) {
					$matched=1;
					last;
				}
			} else {
				if($value >= $realInt->[1] and $value <= $realInt->[2]) {
					$matched=1;
					last;
				}
			}
		}
		return 0 if($matched==0);
	}
	return 1;
}

sub ruleMatches {
	my $rule=shift @_;
	my $instance=shift @_;

	my $terms=$rule->{terms};
	foreach my $term (@{$terms}) {
		my $value=$instance->[$term->[0]];
		if($term->[1] eq "nominal") {
			return 0 if($term->[2]->[$value]==0);
		} else {
			my $max=@{$term};
			my $matched=0;
			for(my $index=2;$index<$max;$index++) {
				my $realInt = $term->[$index];
				if($realInt->[0] eq "gt") {
					if($value >= $realInt->[1]) {
						$matched=1;
						last;
					}
				} elsif($realInt->[0] eq "lt") {
					if($value <= $realInt->[1]) {
						$matched=1;
						last;
					}
				} else {
					if($value >= $realInt->[1] and $value <= $realInt->[2]) {
						$matched=1;
						last;
					}
				}
			}
			return 0 if($matched==0);
		}
	}
	return 1;
}

			

sub parseRuleSet {
	my $metadata=shift @_;
	my $fileName=shift @_;

	open(FH,$fileName) or die "Cannot open rule set";
	my @lines=<FH>;
	close(FH);
	chomp @lines;

	my %ruleSet;
	foreach my $line (@lines) {
		if($line=~/^Default rule -> (.+)$/) {
			if(&classExists($metadata,$1)) {
				$ruleSet{defaultClass}=$1;
			} else {
				die "Unknown default class $1\n";
			}
		} else {
			my $rule=&parseRule($metadata,$line);
			push @{ $ruleSet{rules}},$rule if(defined $rule);
		}
	}
	return \%ruleSet;
}

sub parseRule {
	my $metadata=shift @_;
	my $line=shift @_;

	my %rule;
	my @terms=split(/\|/,$line);

	$rule{class}=pop @terms;
	if(not &classExists($metadata,$rule{class})) {
		die "Unknown class $rule{class}\n";
	}

	foreach my $term (@terms) {
		if($term=~/Att (.+) is (.+)$/) {
			my $att=&getAttributeByName($metadata,$1);
			push @{$rule{terms}},&parseAttribute($metadata,$att,$2);
		} else {
			print STDERR "Parse error reading $term\n";
			return undef;
		}
	}
	return \%rule;
}

sub parseAttribute {
	my $metadata = shift @_;
	my $att = shift @_;
	my $term = shift @_;

	my @term;

	push @term,$att->{numAtt};

	if($att->{type} eq "nominal") {
		push @term,"nominal";
                my @valuesMap;
                for(my $i=0;$i<@{$att->{nomValues}};$i++) {
                        $valuesMap[$i]=0;
                }
                my @values=split(/,/,$term);
                foreach my $value (@values) {
                        $valuesMap[&getPosOfAttributeValue($att,$value)]=1;
                }
                push @term,\@valuesMap;
	} else {
		push @term,"real";
		my @intervals;
                if($term=~/^(\[.+\])$/) {
                        my $int=$1;
                        $int=~s/\[//g;
                        $int=~s/\]$//g;
                        my @preds=split(/\]/,$int);
                        foreach my $int (@preds) {
				my @intDef;
				if($int=~/^>(-?[0-9]+\.?[0-9]*e?-?[0-9]*)$/i) {
					push @intDef,"gt";
					push @intDef,$1;
				} elsif($int=~/^<(-?[0-9]+\.?[0-9]*e?-?[0-9]*)$/i) {
					push @intDef,"lt";
					push @intDef,$1;
				} elsif($int=~/^(-?[0-9]+\.?[0-9]*e?-?[0-9]*),(-?[0-9]+\.?[0-9]*e?-?[0-9]*)$/i) {
					push @intDef,"int";
					push @intDef,$1;
					push @intDef,$2;
				} else {
					die "Unknown interval type $int";
				}
				push @intervals,\@intDef;
			}
		}
		push @term,@intervals;
	}
	return \@term;
}

sub getAttributeByName {
        my $metadata = shift @_;
        my $attName = shift @_;

	foreach my $att (@{$metadata->{attributes}}) {
		return $att if($att->{name} eq $attName);
	}
	die "Cannot find attribute with name $attName\n";
}

sub parseMetadata {
	my $fileName=shift @_;

	open(FH,$fileName) or die "Cannot open metadata";
	my %metadata;
	$metadata{numNominal}=0;
	$metadata{numReal}=0;
	my $countAtt=0;

	while(my $line=<FH>) {
		chomp $line;
		if($line=~/^\@relation (.+)$/i) {
			$metadata{relation}=$1;
		} elsif($line=~/^\@attribute[\s\t]+/i) {
			$line=~s/^\@attribute[\s\t]+//gi;
			$line=~s/\t/ /g;
			#$line=~s/\s+/ /g;
			my $name;
			my $def;
			if($line=~/^'(.+)' (.+)$/i) {
				$name=$1;
				$def=$2;
			} elsif($line=~/^([^ ]+)\s+(.+)$/i) {
				$name=$1;
				$def=$2;
			} else {
				die "Unknown att def $line";
			}
			my %att;
			$att{name}=$name;
			$att{numAtt}=$countAtt;
			if($def=~/real|numeric|integer/i) {
				$att{type}="real";
				$metadata{numReal}++;
			} elsif($def=~/^{(.+)}$/i) {
				$att{type}="nominal";
				my @values=split(/,/,$1);
				for(my $i=0;$i<@values;$i++) {
					$values[$i]=~s/^\s+//g;
				}
				$att{nomValues}=\@values;
				$metadata{numNominal}++;
			} else {
				die "Unknown attribute type $def";
			}
			push @{$metadata{attributes}},\%att;
			$countAtt++;
		} elsif($line=~/^\@data/i) {
			if($metadata{numNominal}>0 and $metadata{numReal}==0) {
				$metadata{matchFunc}=\&ruleMatchesNominal;
			} elsif($metadata{numNominal}==1 and $metadata{numReal}>0) {
				$metadata{matchFunc}=\&ruleMatchesReal;
			} else {
				$metadata{matchFunc}=\&ruleMatches;
			}

			$metadata{numAtt}=$countAtt;
			my $class=pop @{$metadata{attributes}};
			$metadata{numClasses}=@{$class->{nomValues}};
			$metadata{class}=$class;
			last;
		}
	}

	close(FH);
	return \%metadata;
}

sub parseInstances {
	my $metadata=shift @_;
	my $fileName=shift @_;

	open(FH,$fileName) or die "Cannot open data set";
	my @instances;

	my $inHeader=1;
	while (my $line=<FH>) {
		chomp $line;
		if($inHeader) {
			if($line=~/^\@data/i) {
				$inHeader=0;
			}
		} else {
			next if($line=~/^$/);
			my @values=split(/,/,$line);
			foreach(@values) {
				s/^\s+//g;
			}
			my $class=pop @values;
                        my @instance;
                        $#instance=$metadata->{numAtt};
                        my $count=0;
			foreach my $value (@values) {
				my $att=$metadata->{attributes}->[$count];
				if($att->{type} eq "real") {
					$instance[$count] = $value;
				} else {
					$instance[$count] = &getPosOfAttributeValue($att,$value);
				}
				$count++;
			}
			$instance[$count]=$class;
			push @instances,\@instance;
		}
	}

	close(FH);
	return \@instances;
}


sub isNum {
	my $value=shift @_;

	return 0 if(not $value=~/[0-9]/);
	return 1 if($value=~/^(-?[0-9]*\.?[0-9]*e?-?[0-9]*)$/i);
	return 0;
}

sub classExists {
	my $metadata=shift @_;
	my $class=shift @_;

	my $att=$metadata->{class};
	return 1 if(grep(/^$class$/,@{$att->{nomValues}}));
	return 0;
}


sub getPosOfAttributeValue {
        my $att = shift @_;
        my $value = shift @_;

        for(my $i=0;$i<@{$att->{nomValues}};$i++) {
                return $i if($att->{nomValues}->[$i] eq $value);
        }

        die "Unknown value $value for attribute $att->{name}\n";
}

