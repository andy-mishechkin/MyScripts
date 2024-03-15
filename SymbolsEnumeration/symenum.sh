#!/bin/bash
# symenum.ps1 - script for symbols enumeration
# This script was created only for research and teaching goals and may be useful in realization of various symbols generators.
# Parameters: 
# --seqlength - Mandatory Parameter. The length of symbols sequence (amount of symbols)
# --digits - Specify this parameter to include digits to symbol sequence. This is also the default symbols set, if no 
# --digits --latin_upper --latin_lower parameters are specified
# --latin_upper - Specify this parameter to include latin upper letters to symbol sequence
# --latin_lower - Specify this parameter to include latin lower letters to symbol sequence
# Examples:
# ./symenum.ps1 --seqlength 4 - Enumerate the sequence from 4 digits symbols only
# ./symenum.ps1 --seqlength 4 --latin_upper - Enumerate the sequence from 4 latin upper letters only
# ./symenum.ps1 --seqlength 8 --digits --latin_upper --latin_lower - Enumerate the sequence from 8 symbols 
# which contains latin upper and lower letters and digits

declare SSYMBOLS

while [ $# -gt 0 ]; do
    if [[ $1 == "--"* ]]; then
        param_name="${1/--/}"
        case $param_name in
                seqlength)
                declare seqlength=$2 
                ;;
                digits)
                for i in {0..9}; do SSYMBOLS+=$i; done
                ;;
                latin_upper)
                for i in {A..Z}; do SSYMBOLS+=$i; done
                ;;
                latin_lower)
                for i in {a..z}; do SSYMBOLS+=$i; done
                ;;
            esac 
    fi
    shift
done

if [[ -z "$seqlength" ]]; then
    echo "[!] Error! You should specify the length of symbol sequence as --seqlength parameter"
    exit 1
fi

if [[ -z "$SSYMBOLS" ]]; then
    echo "[!] Symbol set is not sprecified. Will be used digits only (default value)"
    for i in {0..9}; do SSYMBOLS+=$i; done
fi

echo "Source symbols set: [$SSYMBOLS]"

declare -a arrSeq[$seqlength]
declare -a arrSeqSteps[$seqlength]

#Length of string 
length_SSYMBOLS=${#SSYMBOLS}
echo "Length of source symbols set: [$length_SSYMBOLS]"

for ((i=0; i<$seqlength; ++i)); do 
    arrSeq[i]=${SSYMBOLS:0:1};
    arrSeqSteps[i]=$(($length_SSYMBOLS**$((i+1))))
done

AmountOfSets=$(($length_SSYMBOLS**$seqlength))
echo "Total amount of symbols sets: [$AmountOfSets]"
Iter=0
while true; do
    for ((i=0; i<$length_SSYMBOLS; ++i)); do
        arrSeq[0]=${SSYMBOLS:$i:1}
        echo ${arrSeq[@]}
        ((++Iter))
    done
    echo "Iteration: [$Iter]"
    echo "------------------------------------------------"
    for ((i=0; i<$seqlength-1; ++i)); do   
        if (($Iter==${arrSeqSteps[$i]})); then
            j=$(($i+1))
            jSymbols=${SSYMBOLS#*${arrSeq[$j]}}
            arrSeq[$j]=${jSymbols:0:1}
            arrSeq[$i]=${SSYMBOLS:0:1}
            arrSeqSteps[$i]=$((${arrSeqSteps[$i]}+$(($length_SSYMBOLS**$((i+1))))))
        fi
    done
    if (($Iter ==  $AmountOfSets)); then break; fi
done
