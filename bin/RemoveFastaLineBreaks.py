#!/usr/bin/env python3

import os,sys,re,getopt

def main(args):
    DeltaFile = None
    try:
        opts, args = getopt.getopt(args, "i:o:", ["inFile=", "outfile="])
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
        elif opt in ("-i", "--inFile"):
            inFile = arg
        elif opt in ("-o", "--outfile"):
            outFile = arg
    f = open(inFile, "r")
    n = open(outFile, "w")
    firstL = True
    for line in f:
        if (len(re.compile(r"^>.*").findall(line))):
            if (not firstL):
                n.write("\n")
            n.write(line)
            firstL = False
        else:
            n.write(line.replace("\n", ""))
    n.write("\n")
    f.close()
    n.close()

def usage():
    print("Usage: RemoveFastaLineBreaks.py -i /path/to/file.fasta -o /path/to/new.fasta")


if __name__ == "__main__":
    main(sys.argv[1:])
    