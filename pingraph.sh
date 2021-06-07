#!/bin/bash

# Vérifie le nombre de paquet à envoyer. Si null alors on envoie 100 paquets par défaut.
[[ -z "$1" ]] && c=100 || c=$1

timestampHR=$(date +"%Y-%m-%d-%H-%M-%S")
timestampStart=$(date --date now +%s)

filePing="ping-test-$timestamp"
fileStat="ping-stat.csv"
fileGraph="ping-graph-$timestampHR.png"

maxLat=60

sudo ping mytelephony.beonevoip.be -i 0.02 -s 216 -c $c | tee $filePing

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

for i in $(seq $c)
do
latency=100
findIt=$(grep "icmp_seq=$i\s" $filePing)

[[ ! -z "$findIt"  ]] && latency=$(echo $findIt | grep -o "time=[0-9]*\.[0-9]" | awk -F= '{print $2}')

echo  $i","$latency,$avg,$mdev >> $fileStat
done
sleep 1

graph $fileStat -o $fileGraph --figsize 1920x1080 --xlabel 'Paquets' --ylabel 'Time (ms)' --title "Ping Test $timestampHR (duration: $durationMin min, $durationSec sec)" --no-tight --fontsize 12 --marker '' --yrange 0:$maxLat --xrange 0:$c

rm $fileStat
