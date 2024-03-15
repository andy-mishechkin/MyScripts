<#
.SYNOPSIS
SymEnumerator.ps1 - script for symbols enumeration
 
.DESCRIPTION
This script was created only for research and teaching goals and may be useful in realization of various symbols generators.
 
.PARAMETER -seqlength
Mandatory Parameter. The length of symbols sequence (amount of symbols)
 
.PARAMETER -digits
Specify this parameter to include digits to symbol sequence. This is also the default symbols set, if no -digits -latin_upper -latin_lower
parameters are specified
 
.PARAMETER -latin_upper
Specify this parameter to include latin upper letters to symbol sequence 
 
.PARAMETER -latin_lower
Specify this parameter to include latin lower letters to symbol sequence 
 
.EXAMPLE
PS> .\SymEnumerator.ps1 -seqlength 4
Enumerate the sequence from 4 digits symbols only
 
.EXAMPLE
PS> .\SymEnumerator.ps1 -seqlength 4 -latin_upper
Enumerate the sequence from 4 latin upper letters only
 
.EXAMPLE
PS> .\SymEnumerator.ps1 -seqlength 8 -digits -latin_upper -latin_lower
Enumerate the sequence from 8 symbols which contains latin upper and lower letters and digits
#>

Param(      
    [Parameter(Mandatory, HelpMessage="The length of symbol sequence as --seqlength parameter")] 
    [int] $seqlength,
    [Parameter()] [switch] $digits,
    [Parameter()] [switch] $latin_upper,
    [Parameter()] [switch] $latin_lower                               
)
$SSymbols = New-Object System.Collections.Generic.List[char]
$ArrSeq = New-Object -TypeName 'Char[]' -ArgumentList $seqlength
$ArrSeqSteps = New-Object -TypeName 'ulong[]' -ArgumentList $seqlength

$Codes = @()
if ($digits -or ((-not $digits) -and (-not $latin_upper) -and (-not $latin_lower))) { $Codes += (48..57) }
if ($latin_upper) { $Codes += (65..90) }
if ($latin_lower) { $Codes += (97..122) }

$Codes | ForEach-Object { $SSymbols.Add([char]$_) > $null }
Write-Output "Source symbols set: [$SSymbols]"
$SSymbolsLength = $SSymbols.Count

for($i=0; $i -lt $seqlength; $i++) {
    $ArrSeq[$i] = $SSymbols[0]
    $ArrSeqSteps[$i] = [System.Math]::Pow($SSymbolsLength, ($i+1))
}

Write-Output "ArrSeqStep: $(-join $ArrSeqSteps)"

$AmountOfSets = [System.Math]::Pow($SSymbolsLength, $seqlength)
Write-Output "Total amount of symbols sets: [$AmountOfSets]"

$Iter=0
while ($true) {
    for ($i=0; $i -lt $SSymbolsLength; $i++) {
        $ArrSeq[0] = $SSymbols[$i]
        Write-Output $(-join $ArrSeq)
        $Iter++
    }
    Write-Output "Iteration: [$Iter]"
    Write-Output "--------------------------------------------"
    for ($i=0; $i -lt ($seqlength-1); ++$i) {
        if ($Iter -eq $ArrSeqSteps[$i]) {
            $j = $i+1
            $NextIndex = $SSymbols.IndexOf($ArrSeq[$j]) + 1
            $jSymbols = $SSymbols.GetRange($NextIndex, ($SSymbols.Count - $NextIndex))
            $ArrSeq[$j] = $jSymbols[0]
            $ArrSeq[$i] = $SSymbols[0]
            $ArrSeqSteps[$i] = $ArrSeqSteps[$i] + ([System.Math]::Pow($SSymbolsLength, ($i+1)))
        }
    }
    if ($Iter -eq $AmountOfSets) { break }
}