#!/usr/bin/perl -w

# This script automatically launches a large number of BioHEL runs with the given number of parallel runs
# For the script to operate file names have to follow a certain pattern:
# BioHEL config files will have the suffix .conf
# Training set files will start in "TrainFold". The corresponding test files will simply replace "Train" for "Test"
# The number of repetitions of the runs will be controlled by the first command line argument (if defined)
# The index of the first repetition to perform will be controlled by the second argument (if defined)
# The combinations of all config file x all pairs of (training,test) files x number of repeititons will be launched
# with the amount of parallelism specified in $parallelRuns

my $numRepetitions=10;
my $currentRep=1;
my $programa="biohelcuda";

my $parallelRuns=3;

if(defined $ARGV[0]) {
	$numRepetitions=$ARGV[0];
}

if(defined $ARGV[1]) {
	$currentRep=$ARGV[1];
	$numRepetitions+=$currentRep-1;
}

`>proves.log`;

my @configs=glob "*.conf";
my @dataFiles=glob "TrainFold*";
my $numParalels=0;
my $configAct=0;
my $dataFileAct=0;
while($currentRep<=$numRepetitions) {
	unless ($numParalels<$parallelRuns) {
		wait;
		$numParalels--;
	}
	my $prefixRun=`basename $configs[$configAct] .conf`;
	chomp $prefixRun;
	my ($dataFileName)=($dataFiles[$dataFileAct]=~/Train(.*)$/);
	$prefixRun.=$dataFileName."rep$currentRep".".out";
	my $testFile=$dataFiles[$dataFileAct];
	$testFile=~s/Train/Test/g;
	my $pid=fork;
	if(!$pid) {
		if(not -f $prefixRun) {
			exec "$programa $configs[$configAct] $dataFiles[$dataFileAct] $testFile > $prefixRun";
		} else {
			exit;
		}
	} else {
		my $myTime=`date`;
		chomp $myTime;
		`echo $myTime: Executant la prova $prefixRun >> proves.log`;
		$dataFileAct++;
		if($dataFileAct==@dataFiles) {
			$dataFileAct=0;
			$configAct++;
			if($configAct==@configs) {
				$configAct=0;
				$currentRep++;
			}
		}
		$numParalels++;
	}
}

wait;
