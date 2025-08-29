function scinot {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string]
        $expression
    )
    $split_1 = $expression.split("x")
    [double]$float = $split_1[0]
    $split_2 = $split_1[1].split("^")
    [double]$base = $split_2[0]
    [double]$exp = $split_2[1]
    return [double]($float * [Math]::Pow($base, $exp))
}

function root ($value, $root) {
    return [Math]::Exp([Math]::Log($value)/$root)
}

$global:avogadro = scinot 6.022x10^23

$global:PeriodicTable = @()

$PeriodicTable += @{ null = $true }
$Hydrogen = @{
    number = 1
    weight = 1.008
    neutrons = 0 # Most common isotope is Protium (1H)
}
$Helium = @{
    number = 2
    weight = 4.0026
    neutrons = 2 # Most common isotope is Helium-4
}
$Lithium = @{
    number = 3
    weight = 6.94
    neutrons = 4 # Most common isotope is Lithium-7
}
$Beryllium = @{
    number = 4
    weight = 9.0122
    neutrons = 5 # Most common isotope is Beryllium-9
}
$Boron = @{
    number = 5
    weight = 10.81
    neutrons = 6 # Most common isotope is Boron-11
}
$Carbon = @{
    number = 6
    weight = 12.011
    neutrons = 6 # Most common isotope is Carbon-12
}
$Nitrogen = @{
    number = 7
    weight = 14.007
    neutrons = 7 # Most common isotope is Nitrogen-14
}
$Oxygen = @{
    number = 8
    weight = 15.999
    neutrons = 8 # Most common isotope is Oxygen-16
}
$Fluorine = @{
    number = 9
    weight = 18.998
    neutrons = 10 # Most common isotope is Fluorine-19
}
$Neon = @{
    number = 10
    weight = 20.180
    neutrons = 10 # Most common isotope is Neon-20
}
$Sodium = @{
    number = 11
    weight = 22.990
    neutrons = 12 # Most common isotope is Sodium-23
}
$Magnesium = @{
    number = 12
    weight = 24.305
    neutrons = 12 # Most common isotope is Magnesium-24
}
$Aluminum = @{
    number = 13
    weight = 26.981
    neutrons = 14 # Most common isotope is Aluminum-27
}
$Silicon = @{
    number = 14
    weight = 28.085
    neutrons = 14 # Most common isotope is Silicon-28
}
$Phosphorus = @{
    number = 15
    weight = 30.974
    neutrons = 16 # Most common isotope is Phosphorus-31
}
$Sulfur = @{
    number = 16
    weight = 32.06
    neutrons = 16 # Most common isotope is Sulfur-32
}
$Chlorine = @{
    number = 17
    weight = 35.45
    neutrons = 18 # Most common isotope is Chlorine-35
}
$Argon = @{
    number = 18
    weight = 39.948
    neutrons = 22 # Most common isotope is Argon-40
}
$Potassium = @{
    number = 19
    weight = 39.098
    neutrons = 20 # Most common isotope is Potassium-39
}
$Calcium = @{
    number = 20
    weight = 40.078
    neutrons = 20 # Most common isotope is Calcium-40
}
$Scandium = @{number = 21; weight = 44.956; neutrons = 24}
$Titanium = @{number = 22; weight = 47.867; neutrons = 26}
$Vanadium = @{number = 23; weight = 50.942; neutrons = 28}
$Chromium = @{number = 24; weight = 51.996; neutrons = 28}
$Manganese = @{number = 25; weight = 54.938; neutrons = 30}
$Iron = @{number = 26; weight = 55.845; neutrons = 30}
$Cobalt = @{number = 27; weight = 58.933; neutrons = 32}
$Nickel = @{number = 28; weight = 58.693; neutrons = 31}
$Copper = @{number = 29; weight = 63.546; neutrons = 35}
$Zinc = @{number = 30; weight = 65.38; neutrons = 35}
$Gallium = @{number = 31; weight = 69.723; neutrons = 39}
$Germanium = @{number = 32; weight = 72.630; neutrons = 41}
$Arsenic = @{number = 33; weight = 74.922; neutrons = 42}
$Selenium = @{number = 34; weight = 78.971; neutrons = 45}
$Bromine = @{number = 35; weight = 79.904; neutrons = 45}
$Krypton = @{number = 36; weight = 83.798; neutrons = 48}
$Rubidium = @{number = 37; weight = 85.468; neutrons = 48}
$Strontium = @{number = 38; weight = 87.62; neutrons = 50}
$Yttrium = @{number = 39; weight = 88.906; neutrons = 50}
$Zirconium = @{number = 40; weight = 91.224; neutrons = 51}
$Niobium = @{number = 41; weight = 92.906; neutrons = 52}
$Molybdenum = @{number = 42; weight = 95.95; neutrons = 54}
$Technetium = @{number = 43; weight = 98; neutrons = 55}
$Ruthenium = @{number = 44; weight = 101.07; neutrons = 57}
$Rhodium = @{number = 45; weight = 102.91; neutrons = 58}
$Palladium = @{number = 46; weight = 106.42; neutrons = 60}
$Silver = @{number = 47; weight = 107.87; neutrons = 61}
$Cadmium = @{number = 48; weight = 112.41; neutrons = 64}
$Indium = @{number = 49; weight = 114.82; neutrons = 66}
$Tin = @{number = 50; weight = 118.71; neutrons = 69}
$Antimony = @{number = 51; weight = 121.76; neutrons = 71}
$Tellurium = @{number = 52; weight = 127.60; neutrons = 76}
$Iodine = @{number = 53; weight = 126.90; neutrons = 74}
$Xenon = @{number = 54; weight = 131.29; neutrons = 77}
$Cesium = @{number = 55; weight = 132.91; neutrons = 78}
$Barium = @{number = 56; weight = 137.33; neutrons = 81}
$Lanthanum = @{number = 57; weight = 138.91; neutrons = 82}
$Cerium = @{number = 58; weight = 140.12; neutrons = 82}
$Praseodymium = @{number = 59; weight = 140.91; neutrons = 82}
$Neodymium = @{number = 60; weight = 144.24; neutrons = 84}
$Promethium = @{number = 61; weight = 145; neutrons = 84}
$Samarium = @{number = 62; weight = 150.36; neutrons = 88}
$Europium = @{number = 63; weight = 151.96; neutrons = 89}
$Gadolinium = @{number = 64; weight = 157.25; neutrons = 93}
$Terbium = @{number = 65; weight = 158.93; neutrons = 94}
$Dysprosium = @{number = 66; weight = 162.50; neutrons = 97}
$Holmium = @{number = 67; weight = 164.93; neutrons = 98}
$Erbium = @{number = 68; weight = 167.26; neutrons = 99}
$Thulium = @{number = 69; weight = 168.93; neutrons = 100}
$Ytterbium = @{number = 70; weight = 173.05; neutrons = 103}
$Lutetium = @{number = 71; weight = 174.97; neutrons = 104}
$Hafnium = @{number = 72; weight = 178.49; neutrons = 106}
$Tantalum = @{number = 73; weight = 180.95; neutrons = 108}
$Tungsten = @{number = 74; weight = 183.84; neutrons = 110}
$Rhenium = @{number = 75; weight = 186.21; neutrons = 111}
$Osmium = @{number = 76; weight = 190.23; neutrons = 114}
$Iridium = @{number = 77; weight = 192.22; neutrons = 115}
$Platinum = @{number = 78; weight = 195.08; neutrons = 117}
$Gold = @{number = 79; weight = 196.97; neutrons = 118}
$Mercury = @{number = 80; weight = 200.59; neutrons = 121}
$Thallium = @{number = 81; weight = 204.38; neutrons = 123}
$Lead = @{number = 82; weight = 207.2; neutrons = 125}
$Bismuth = @{number = 83; weight = 208.98; neutrons = 126}
$Polonium = @{number = 84; weight = 209; neutrons = 125}
$Astatine = @{number = 85; weight = 210; neutrons = 125}
$Radon = @{number = 86; weight = 222; neutrons = 136}
$Francium = @{number = 87; weight = 223; neutrons = 136}
$Radium = @{number = 88; weight = 226; neutrons = 138}
$Actinium = @{number = 89; weight = 227; neutrons = 138}
$Thorium = @{number = 90; weight = 232.04; neutrons = 142}
$Protactinium = @{number = 91; weight = 231.04; neutrons = 140}
$Uranium = @{number = 92; weight = 238.03; neutrons = 146}
$Neptunium = @{number = 93; weight = 237; neutrons = 144}
$Plutonium = @{number = 94; weight = 244; neutrons = 150}
$Americium = @{number = 95; weight = 243; neutrons = 148}
$Curium = @{number = 96; weight = 247; neutrons = 151}
$Berkelium = @{number = 97; weight = 247; neutrons = 150}
$Californium = @{number = 98; weight = 251; neutrons = 153}
$Einsteinium = @{number = 99; weight = 252; neutrons = 153}
$Fermium = @{number = 100; weight = 257; neutrons = 157}
$PeriodicTable += $Thallium
$PeriodicTable += $Lead
$PeriodicTable += $Bismuth
$PeriodicTable += $Polonium
$PeriodicTable += $Astatine
$PeriodicTable += $Radon
$PeriodicTable += $Francium
$PeriodicTable += $Radium
$PeriodicTable += $Actinium
$PeriodicTable += $Thorium
$PeriodicTable += $Protactinium
$PeriodicTable += $Uranium
$PeriodicTable += $Neptunium
$PeriodicTable += $Plutonium
$PeriodicTable += $Americium
$PeriodicTable += $Curium
$PeriodicTable += $Berkelium
$PeriodicTable += $Californium
$PeriodicTable += $Einsteinium
$PeriodicTable += $Fermium
$PeriodicTable += $Promethium
$PeriodicTable += $Samarium
$PeriodicTable += $Europium
$PeriodicTable += $Gadolinium
$PeriodicTable += $Terbium
$PeriodicTable += $Dysprosium
$PeriodicTable += $Holmium
$PeriodicTable += $Erbium
$PeriodicTable += $Thulium
$PeriodicTable += $Ytterbium
$PeriodicTable += $Lutetium
$PeriodicTable += $Hafnium
$PeriodicTable += $Tantalum
$PeriodicTable += $Tungsten
$PeriodicTable += $Rhenium
$PeriodicTable += $Osmium
$PeriodicTable += $Iridium
$PeriodicTable += $Platinum
$PeriodicTable += $Gold
$PeriodicTable += $Mercury
$PeriodicTable += $Niobium
$PeriodicTable += $Molybdenum
$PeriodicTable += $Technetium
$PeriodicTable += $Ruthenium
$PeriodicTable += $Rhodium
$PeriodicTable += $Palladium
$PeriodicTable += $Silver
$PeriodicTable += $Cadmium
$PeriodicTable += $Indium
$PeriodicTable += $Tin
$PeriodicTable += $Antimony
$PeriodicTable += $Tellurium
$PeriodicTable += $Iodine
$PeriodicTable += $Xenon
$PeriodicTable += $Cesium
$PeriodicTable += $Barium
$PeriodicTable += $Lanthanum
$PeriodicTable += $Cerium
$PeriodicTable += $Praseodymium
$PeriodicTable += $Neodymium
$PeriodicTable += $Gallium
$PeriodicTable += $Germanium
$PeriodicTable += $Arsenic
$PeriodicTable += $Selenium
$PeriodicTable += $Bromine
$PeriodicTable += $Krypton
$PeriodicTable += $Rubidium
$PeriodicTable += $Strontium
$PeriodicTable += $Yttrium
$PeriodicTable += $Zirconium
$PeriodicTable += $Scandium
$PeriodicTable += $Titanium
$PeriodicTable += $Vanadium
$PeriodicTable += $Chromium
$PeriodicTable += $Manganese
$PeriodicTable += $Iron
$PeriodicTable += $Cobalt
$PeriodicTable += $Nickel
$PeriodicTable += $Copper
$PeriodicTable += $Zinc
$PeriodicTable += $Hydrogen
$PeriodicTable += $Helium
$PeriodicTable += $Lithium
$PeriodicTable += $Beryllium
$PeriodicTable += $Boron
$PeriodicTable += $Carbon
$PeriodicTable += $Nitrogen
$PeriodicTable += $Oxygen
$PeriodicTable += $Fluorine
$PeriodicTable += $Neon
$PeriodicTable += $Sodium
$PeriodicTable += $Magnesium
$PeriodicTable += $Aluminum
$PeriodicTable += $Silicon
$PeriodicTable += $Phosphorus
$PeriodicTable += $Sulfur
$PeriodicTable += $Chlorine
$PeriodicTable += $Argon
$PeriodicTable += $Potassium
$PeriodicTable += $Calcium

function Get-Table () {
    return $PeriodicTable
}

$global:pi = 3.1415926535
