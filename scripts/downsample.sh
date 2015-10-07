#!/bin/bash

# exit on errr
set -e

# import logging/versioning
source /mnt/hds/proj/bioinfo/SCRIPTS/log.bash

VERSION=1.3.0
log VERSION $VERSION

##################
# MATCH PATTERNS #
##################

# Change the file matching pattern here if needed

FORWARD_PATTERN='*_1.fastq.gz'
REVERSE_PATTERN='*_2.fastq.gz'

#########
# USAGE #
#########

if [[ $# < 3 ]]; then
    echo "Usage:"
    echo "	$0 indir outdir reads"
    echo ""
    echo "	with:"
    echo "		indir: The input directory. The script will expect forward and reverse"
    echo "		       strand files found with a matching pattern."
    echo "		       - forward match pattern: $FORWARD_PATTERN"
    echo "		       - reverse match pattern: $REVERSE_PATTERN"
    echo "		outdir: The output directory. Will be created if it does not exist."
    echo "		       One output file per strand will be created in this directory."
    echo "		       The output file name will be the first file name in the input"
    echo "		       directory matched with above mentioned patterns."
    echo "		reads: The amount of read pairs to keep."

    exit 1
fi

##########
# params #
##########

INDIR=$1
OUTDIR=$2
READS=$3

[[ ! -e $OUTDIR ]] && mkdir $OUTDIR

SEQTK_DIR=/mnt/hds/proj/bioinfo/SCRIPTS/git/downsampling/seqtk/

########
# RUN! #
########

# get first file name - forward
FORWARD_OUTFILE=`ls -1 ${INDIR}/${FORWARD_PATTERN} | head -1`
if [[ ! -e $FORWARD_OUTFILE ]]; then
    error 'No forward strands found!'
    exit 1
fi
FORWARD_OUTFILE=`basename $FORWARD_OUTFILE`

# get first file name - reverse
REVERSE_OUTFILE=`ls -1 ${INDIR}/${REVERSE_PATTERN} | head -1`
if [[ ! -e $REVERSE_OUTFILE ]]; then
    error 'No reverse strands found!'
    exit 1
fi
REVERSE_OUTFILE=`basename $REVERSE_OUTFILE`

# get a random number (range 0-32k)
SEED=$RANDOM

log 'Input files FORWARD:'
ls ${INDIR}/${FORWARD_PATTERN}

log 'Input files REVERSE:'
ls ${INDIR}/${REVERSE_PATTERN}

log 'Running:'
# create a temp file to store the PID of seqtk
PIDFILE=`mktemp`

# init the seqtk command
COMMAND1="${SEQTK_DIR}/seqtk sample -s $SEED"
COMMAND2="gzip --to-stdout"

# create forward downsample files -- and put it in the background
for FASTQFILE in `( cd ${INDIR} && ls -1 ${FORWARD_PATTERN} )`; do
    log "$COMMAND1 <(zcat ${INDIR}/${FASTQFILE}) $READS | $COMMAND2 > ${OUTDIR}/${FASTQFILE} &"
    ( echo $BASHPID >> $PIDFILE; exec $COMMAND1 <(zcat ${INDIR}/${FASTQFILE}) $READS ) | $COMMAND2 > ${OUTDIR}/${FASTQFILE} &
done

wait # so the node doesn't go down

# create reverse downsample file
for FASTQFILE in `( cd ${INDIR} && ls -1 ${REVERSE_PATTERN} )`; do
    log "$COMMAND1 <(zcat ${INDIR}/${FASTQFILE}) $READS | $COMMAND2 > ${OUTDIR}/${FASTQFILE} &"
    ( echo $BASHPID >> $PIDFILE; exec $COMMAND1 <(zcat ${INDIR}/${FASTQFILE}) $READS ) | $COMMAND2 > ${OUTDIR}/${FASTQFILE} &
done

# remove the background seqtk on ctrl+c
trap "while read -r PID; do kill $PID; done < ${PIDFILE}; rm $PIDFILE" INT KILL

wait # until everything to complete
