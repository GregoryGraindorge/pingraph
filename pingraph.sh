#!/bin/bash
function logo(){
cat << "EOF"

 _______  ______  __    __   ______   _______    ______   _______   __    __ 
|       \|      \|  \  |  \ /      \ |       \  /      \ |       \ |  \  |  \
| $$$$$$$\\$$$$$$| $$\ | $$|  $$$$$$\| $$$$$$$\|  $$$$$$\| $$$$$$$\| $$  | $$
| $$__/ $$ | $$  | $$$\| $$| $$ __\$$| $$__| $$| $$__| $$| $$__/ $$| $$__| $$
| $$    $$ | $$  | $$$$\ $$| $$|    \| $$    $$| $$    $$| $$    $$| $$    $$
| $$$$$$$  | $$  | $$\$$ $$| $$ \$$$$| $$$$$$$\| $$$$$$$$| $$$$$$$ | $$$$$$$$
| $$      _| $$_ | $$ \$$$$| $$__| $$| $$  | $$| $$  | $$| $$      | $$  | $$
| $$     |   $$ \| $$  \$$$ \$$    $$| $$  | $$| $$  | $$| $$      | $$  | $$
 \$$      \$$$$$$ \$$   \$$  \$$$$$$  \$$   \$$ \$$   \$$ \$$       \$$   \$$
-----------------------------------------------------------------------------

EOF
}

function Main_Install(){

        # Check la version de Python
        checkpythonversion=$(python -V | grep "3.[0-9]")
        if [[ -z "$checkpythonversion" ]]; then 

                getPythonVersion=$(find /usr/bin -name "python*" -not -type l 2>/dev/null | grep -o "3.[0-9]" | uniq)
                [[ -n "$getPythonVersion" ]] && sudo update-alternatives --install /usr/bin/python python /usr/bin/python$getPythonVersion 1

        fi

        tmp=/dev/pip-tmp && mkdir $tmp && tmpdir=$tmp

        sudo apt update && \
        sudo apt install python3-pip -y
        pip3 install graph-cli --cache-dir=$tmp --build $tmp

        sudo apt install libatlas-base-dev libopenjp2-7 -y && sudo apt autoremove -y

        symlnk=/bin/pingraph
        [[ ! -f "$symlnk" ]] && ln -s /opt/pingraph/pingraph.sh $symlnk

        graph --help

}

function Uprade_Sys(){

        sudo apt update && sudo apt upgrade -y && \
        sudo apt autoremove -y && \
        sudo apt clean -y

}

function Force_Update(){

        sudo apt clean -y && sudo apt autoremove -y && \
        rm -rf /var/lib/apt/lists/* 

}

function Help(){

        logo
        printf "\t%s\n\n" "Pingraph est un outil qui permet de générer des graphiques sur base d'un ping test." \
                        "Exemple: pingraph -c 10000 -d /root/myDir"
        printf "\t%b\n"   "-c,\t Nombre de paquets à envoyer (Default: 100)" \
                        "-i,\t Installation du tool" \
                        "-h,\t Montre ce menu" \
                        "-d,\t Dossier où stocker le graphique" \
                        "-u,\t Upgrade le système avant l'installation" \
                        "-f,\t Force l'upgrade\n"
        exit 1

}

## ------------------------------- ##
# Lancement du tool
## ------------------------------- ##

# Check flags
while getopts ic:hd:uf flag
do
        case "${flag}" in
                h) Help;;
                c) userLoad=${OPTARG};;
                d) outputPath=${OPTARG};;
                i) install=true;;
                u) upgrade=true;;
                f) force=true;;
        esac
done

[[ -n "$force" ]] && Force_Update # Force la mise à jour du raspbery si besoin
[[ -n "$upgrade" ]] && Uprade_Sys # Mise à jour du raspberry
[[ -n "$install" ]] && Main_Install # Installation de l'outil graph-cli via pip

sleep 1

# Check si Graph est bien installé dans le système
isInstall=$(which graph)
if [[ -z "$isInstall" ]]; then
        echo "Veuillez d'abord installé le tool avec la commande \"pingraph -i\"" 
        echo "Help: \"pingraph -h\"" 
        exit 1
fi

logo

outputPath="." # Chemin pour le stockage du graph.
load=100 # Nombre de paquets à envoyer par défaut.

# Si l'utilisateur a fournit un nombre de paquet à envoyer, on modifie la variable $load
[[ -n "$userLoad" ]] && load=$userLoad

timestampHR=$(date +"%Y.%m.%d - %Hh%M")
timestampFile=$(date +"%Y.%m.%d-%Hh%M")
timestampStart=$(date --date now +%s)

filePing="ping-test-"$timestampFile # Output pour les ping
fileStat="ping-stat.csv" # Fichier temporaire pour extraire les infos des ping
fileGraph=$outputPath/"ping-graph-$timestampFile.png" # Output du graph

maxLat=50 # Latence maximum pour le graph

# Lancement du ping test
sudo ping mytelephony.beonevoip.be -i 0.02 -s 216 -c $load | tee $filePing

printf "\n%s\n" "Extraction des statistiques pour la création du graphique."

# Extraction des infos du fichier ping
min=$(grep "rtt" $filePing | awk -F/ '{print $4}' | awk '{print $3}')
max=$(grep "rtt" $filePing | awk -F/ '{print $6}')
avg=$(grep "rtt" $filePing | awk -F/ '{print $5}')
mdev=$(grep "rtt" $filePing | awk -F/ '{print $7}' | awk '{print $1}')

latencyAsInt=$(echo $max | awk -F. '{print $1}')
[[ $latencyAsInt -gt $maxLat  ]] && maxLat=$(($latencyAsInt+10))
[[ $maxLat -lt $(($maxLat - $avg)) ]] maxLat=$(($maxLat+($maxLat/4)))

# Création du fichier de statistiques temporaire
echo "id,latency (min $min ms / max $max ms),average ($avg ms),jitter ($mdev ms)" > $fileStat

# Définition des informations nécessaire pour créer le graph
timestampEnd=$(date --date now +%s)
delta=$(($timestampEnd - $timestampStart))
durationMin=$(($delta%3600/60))
durationSec=$(($delta%60))

# Insertion des valeurs dans le fichier stat temporaire. 
for i in $(seq $load)
        do
                latency=100
                findIt=$(grep "icmp_seq=$i\s" $filePing)

                [[ ! -z "$findIt"  ]] && latency=$(echo $findIt | grep -o "time=[0-9]*\.[0-9]" | awk -F= '{print $2}')

                echo  $i","$latency,$avg,$mdev >> $fileStat
        done

sleep 1

# Création du graph
printf "\n%s\n" "Création du graphique - Veuillez patienter..."
graph $fileStat -o $fileGraph --figsize 1920x1080 \
                --xlabel 'Paquets' --ylabel 'Time (ms)' \
                --title "Ping Test $timestampHR (duration: $durationMin min, $durationSec sec)" \
                --no-tight --fontsize 12 --marker '' \
                --yrange 0:$maxLat --xrange 0:$load && \
                printf "\n%s\n\n" "Le fichier $fileGraph a bien été créé."

# Suppression du fichier de statistiques temporaire
rm $fileStat
