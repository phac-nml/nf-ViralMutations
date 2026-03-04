#!/usr/bin/env python3

import sys
import getopt
import re
import os
import math
import random
import csv
import pysam
import numpy


class RefNotFasta(Exception):
    pass


class SeqNotInReference(Exception):
    pass


class IncorrectCigarChar(Exception):
    pass


def main(args):
    RefFile, NewFile, Coverage, Target = None, None, None, None
    seed = None
    try:
        opts, args = getopt.getopt(args, "r:n:c:t:s:h", [
                                   "reference=", "new=", "coverage=", "target=", "seed=", "help"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    if opts == []:
        usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-r", "--reference"):
            RefFile = arg
        elif opt in ("-n", "--new"):
            NewFile = arg
        elif opt in ("-c", "--coverage"):
            Coverage = arg
        elif opt in ("-t", "--target"):
            Target = int(arg)
        elif opt in ("-s", "--seed"):
            seed = int(arg)

    Ranges, Depths = readDepth(Coverage, Target)
    Keep, Header = GetReads(Ranges, Depths, RefFile, Target, seed)
    WriteFile(Header, NewFile, Keep)
    exit(0)


def usage():
    print("DownsampleToCoverage.py -r Reference.bam -n Out.bam -c Coverage.txt -t 1000 -s 12345678")
    exit(2)


def readDepth(Coverage, Target):
    ranges = []
    depths = {}
    name = ""
    with open(Coverage, "r") as tsvin:
        tsvin = csv.reader(tsvin, delimiter="\t")
        start, stop, prev = 0, 0, 0
        prevname = ""
        for row in tsvin:
            if row[2] != "coverage":
                coverage = int(row[2])
                position = int(row[1])
                name = row[0]
                if prevname == "":
                    prevname = name
                try:
                    test = depths[name]
                except:
                    depths[name] = []
                depths[name].append(coverage)
                if coverage > Target:
                    if start == 0:
                        start = position
                        prev = position
                    else:
                        if position == (prev + 1):
                            prev = position
                            continue
                        elif position > (prev + 1):
                            stop = prev
                            ranges.append([row[0], start, stop])
                            start = position
                            prev = position
                            stop = 0
                if name != prevname:
                    ranges.append([prevname, start, prev])
                    start, stop, prev = 0, 0, 0
                    if coverage > Target:
                        if start == 0:
                            start = position
                            prev = position
                        else:
                            if position == (prev + 1):
                                prev = position
                                continue
                            elif position > (prev + 1):
                                stop = prev
                                ranges.append([name, start, stop])
                                start = position
                                prev = position
                                stop = 0
            prevname = name
        ranges.append([name, start, prev])
    [print(range) for range in ranges]
    return(ranges, depths)


def GetReads(Ranges, Depths, RefFile, Target, Seed):
    if Seed > 0:
        random.seed(Seed)
    keep = []
    with pysam.AlignmentFile(RefFile, "rb") as infile:
        print(infile.count())
        prev_end = 1
        np_ranges = numpy.array(Ranges)
        prev_name = infile.get_reference_name(0)
        if sum(int(x) for x in np_ranges[:, 2]) == 0:
            keep += list(infile.fetch())
            print(len(keep))
            return(list(set(keep)), infile.header)
        else:
            for overSeq in Ranges:
                if overSeq[1] > prev_end:
                    prev_name = overSeq[0]
                    end = overSeq[1] - 1
                    keep += list(infile.fetch(overSeq[0], prev_end, end))
                    prev_end = overSeq[2] + 1
                elif overSeq[0] != prev_name:
                    end = infile.get_reference_length(prev_name)
                    if end > prev_end:
                        keep += list(infile.fetch(prev_name, prev_end, end))
                    prev_end = 1
                    prev_name = overSeq[0]
                    if overSeq[1] > prev_end:
                        end = overSeq[1] - 1
                        keep += list(infile.fetch(overSeq[0], prev_end, end))
                        prev_end = overSeq[2] + 1
                # For segmented genomes, if the current region is a segment that has no location above the threshold
                # we have to keep everything. readDepth returned an element that is: [ 'regionName', 0, 0 ] among
                # other elements that are not zeros.
                # Otherwise, perform the downsampling for the current region
                if (overSeq[1] == 0) and (overSeq[2] == 0):
                    keep += list(infile.fetch(overSeq[0], 1, infile.get_reference_length(overSeq[0])))
                else:
                    temp = Downsample(overSeq, Depths, Target, infile)
                    keep += temp
                print(len(keep))
        if prev_end < infile.get_reference_length(Ranges[numpy.shape(np_ranges)[0] - 1][0]):
            end = infile.get_reference_length(Ranges[numpy.shape(np_ranges)[0] - 1][0])
            keep += list(infile.fetch(Ranges[numpy.shape(np_ranges)[0] - 1][0], prev_end, end))
        ref_names = set(np_ranges[:, 0])
        file_ref_names = set()
        for i in range(infile.nreferences):
            file_ref_names.add(infile.get_reference_name(i))
        missing = file_ref_names.difference(ref_names)
        for name in missing:
            keep += list(infile.fetch(name))
        print(len(keep))
        return(list(set(keep)), infile.header)


def Downsample(Range, Depths, Target, InFile):
    reads = list(InFile.fetch(Range[0], Range[1], Range[2]))
    keep = []
    random.shuffle(reads)
    for read in reads:
        start = read.reference_start
        end = read.reference_end
        if read.cigarstring != None:
            if (start > Range[1]) and (end < Range[2]):
                number = random.uniform(0, 1)
                localDepth = max(Depths[Range[0]][start:end])
                if number < (float(Target)/float(localDepth)):
                    keep.append(read)
                # else:
                    #Depths[start:end] -= 1
    return(keep)


def WriteFile(Header, NewFile, Keep):
    print("Writing reads.")
    with pysam.AlignmentFile(NewFile, "wb", header=Header) as outfile:
        [outfile.write(read) for read in Keep]
    print("reads written")


if __name__ == "__main__":
    main(sys.argv[1:])
