#!/bin/bash

function Main_Install(){

        # Installation du tool
        checkPythonVersion=$(python -V | grep "3.7")
        [[ -z "$checkPythonVersion" ]] && update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
        python -V

        tmp=/dev/pip-tmp
        mkdir $tmp

        TMPDIR=$tmp
        sudo apt update && sudo apt upgrade -y && \
        sudo apt autoremove -y && \
        sudo apt clean -y

        sudo apt install python3-pip -y
        pip3 install graph-cli --cache-dir=$tmp --build $tmp

        graph --help

        sudo apt install libatlas-base-dev libopenjp2-7 -y && sudo apt autoremove

        mkdir ~/pingraph && cd $_
        exit 1

}

function Force_Update(){

    sudo apt clean -y && sudo apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* 

    Main_Install

}

function Help(){

        printf "%s\n" "@@@@@@@@@"
        printf "%s\n" "---------"
        printf "%s\n" "TOOLGRAPH"
        printf "%s\n" "---------"
        printf "%s\n\n" "@@@@@@@@@"

        printf "%b\n" "-c: Nombre de paquets à envoyer (Default: 100)" "-i: Install" "-h: Show this menu" "-d: Dossier où stocker le graphique\n" "-f: Force l'update quand celle-ci ne fonctionnne pas correctement"
        exit 1

}


## ------------------------------- ##
# Lancement du tool
## ------------------------------- ##
outputPath="." # Chemin pour le stockage du graph.
load=100 # Nombre de paquets à envoyer par défaut.

# Check flags
while getopts ic:hd:f flag
do
        case "${flag}" in
                i) Main_Install;;
                c) userLoad=${OPTARG};;
                h) Help;;
                d) outputPath=${OPTARG};;
                f) Force_Update;;
        esac
done

# Si l'utilisateur a fournit un nombre de paquet à envoyer, on modifie la variable $load
[[ -n "$userLoad" ]] && load=$userLoad

timestampHR=$(date +"%Y-%m-%d-%H-%M-%S")
timestampStart=$(date --date now +%s)

filePing="ping-test-"$timestampHR
fileStat="ping-stat.csv"
fileGraph=$outputPath/"ping-graph-$timestampHR.png"

maxLat=60

sudo ping mytelephony.beonevoip.be -i 0.02 -s 216 -c $load | tee $filePing

min=$(grep "rtt" $filePing | awk -F/ '{print $4}' | awk '{print $3}')
max=$(grep "rtt" $filePing | awk -F/ '{print $6}')
avg=$(grep "rtt" $filePing | awk -F/ '{print $5}')
mdev=$(grep "rtt" $filePing | awk -F/ '{print $7}' | awk '{print $1}')

latencyAsInt=$(echo $max | awk -F. '{print $1}')
[[ $latencyAsInt -gt $maxLat  ]] && maxLat=$latencyAsInt

echo "id,latency (min $min ms / max $max ms),average ($avg ms),jitter ($mdev ms)" > $fileStat

timestampEnd=$(date --date now +%s)
delta=$(($timestampEnd - $timestampStart))
durationMin=$(($delta%3600/60))
durationSec=$(($delta%60))

for i in $(seq $load)
do
latency=100
findIt=$(grep "icmp_seq=$i\s" $filePing)

[[ ! -z "$findIt"  ]] && latency=$(echo $findIt | grep -o "time=[0-9]*\.[0-9]" | awk -F= '{print $2}')

echo  $i","$latency,$avg,$mdev >> $fileStat
done
sleep 1

graph $fileStat -o $fileGraph --figsize 1920x1080 --xlabel 'Paquets' --ylabel 'Time (ms)' --title "Ping Test $timestampHR (duration: $durationMin min, $durationSec sec)" --no-tight --fontsize 12 --marker '' --yrange 0:$maxLat --xrange 0:$load

rm $fileStat
