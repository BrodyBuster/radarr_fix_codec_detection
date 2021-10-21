# Requires mediainfo
# wget https://mediaarea.net/repo/deb/repo-mediaarea_1.0-19_all.deb && dpkg -i repo-mediaarea_1.0-19_all.deb && apt-get update

#!/bin/bash
MOVIE_PATH="/mnt/movies"
RADARRAPI="[api key]"
RADARRIP="[ip addr]"
RADARRURL="http://$RADARRIP:7878/radarr/api/v3/movie?apiKey=$RADARRAPI"

# Codec ranking 
AC3=10
DTS=20
DTSES=40
DTSHDHRA=40
EAC3=80
EAC3ATMOS=160
DTSHDMA=320
TRUEHD=640
DTSX=1280
TRUEHDATMOS=2560

RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[;33m'
LAST_START="1900-01-01 00:00:00"
SCRIPT=$(realpath $0)
DATE_CREATED=$(date "+%Y-%m-%d %T")
MOVIE_PATH=$(realpath -s $MOVIE_PATH)
MOVIEDB=$(curl -s http://$RADARRIP:7878/radarr/api/v3/movie?apiKey=$RADARRAPI | grep -o '"[^"]*"\s*:\s*"[^"]*"' | grep -E '^"(relativePath|audioCodec)"' 2>/dev/null)

if [ -z "$MOVIEDB" ]; then
  echo "Radarr db Empty. Please check config ... exiting"
  exit
fi 

DB_COUNT=$(echo "$MOVIEDB" | wc -l)
RADARR_COUNT=$(expr $DB_COUNT / 2)

clear
echo "Script last run on $LAST_START"

echo "Getting movies from $MOVIE_PATH"
declare -a FILE_LIST
while IFS= read -u 3 -d $'\0' -r file; do
    FILE_LIST+=( "$file" )
done 3< <(find $MOVIE_PATH -iname "*imdb-tt*" -type f -newermt "$LAST_START" -print0)
echo "Done getting movies"

MOVIE_COUNT=$(echo ${#FILE_LIST[@]})
if [ "$MOVIE_COUNT" -eq 0 ]; then
    echo "No new movies to process"
    sed -i -E "0,/(LAST_START=).*/{s|(LAST_START=).*|LAST_START=\"$DATE_CREATED\"|}" "$SCRIPT"
    exit;
fi
FILE_COUNT=$(find $MOVIE_PATH -iname "*imdb-tt*" -type f | wc -l)

echo "Number of movies in library path: $FILE_COUNT"
echo "Number of movies in Radarr DB: $RADARR_COUNT"

if [[ $RADARR_COUNT != $FILE_COUNT ]]; then
  echo "Number of movie files does not match Radarr DB ... exiting"
  exit
fi   

echo "Number of movies to process: $MOVIE_COUNT"
echo "Processing Movies ..."

COUNTER=1
for X in "${FILE_LIST[@]}"; do
  movie=$(basename "$X")
  imdb_tt=$(echo "$X" | grep -Po '(?<=imdb-)[^]]+')
  radarr_codec=$(echo "$MOVIEDB" | grep "$imdb_tt" -A2 | grep "audioCodec" | cut -d '"' -f4)
  
  if [ -z "$radarr_codec" ]; then
     echo -e "${BLUE}$movie${NC}"
     echo -e "[ ${RED}NOK${NC} ] Movie not found in radarr db" 
     echo -e "$movie$ -> Not found in Radarr db" >> /tmp/fix.txt
  fi   
  
  if [[ "$radarr_codec" == "AC3" ]]; then
    score=$AC3
  elif [[ "$radarr_codec" == "DTS" ]]; then
    score=$DTS
  elif [[ "$radarr_codec" == "DTS-ES" ]]; then
    score=$DTSES
  elif [[ "$radarr_codec" == "DTS-HD HRA" ]]; then
    score=$DTSHDHRA
  elif [[ "$radarr_codec" == "EAC3" ]]; then
    score=$EAC3
  elif [[ "$radarr_codec" == "EAC3 Atmos" ]]; then
    score=$EAC3ATMOS
  elif [[ "$radarr_codec" == "DTS-HD MA" ]]; then
    score=$DTSHDMA
  elif [[ "$radarr_codec" == "TrueHD" ]]; then
    score=$TRUEHD
  elif [[ "$radarr_codec" == "DTS-X" ]]; then
    score=$DTSX
  elif [[ "$radarr_codec" == "TrueHD Atmos" ]]; then
    score=$TRUEHDATMOS
  else
    score=0
  fi
  stream=1
  audio_list=$(mediainfo "$X" "--inform=General;%Audio_Format_List%" | tr "/" "\n" |  awk '{$1=$1};1')
  no_streams=$(echo "$audio_list" | wc -l)
  echo "$audio_list" | while read -r line ; do
    codec=$(echo $line)
    if [[ "$codec" == "AC-3" ]]; then
      codec_clean="AC3"
      value=$AC3
    elif [[ "$codec" == "DTS" ]]; then
      codec_clean="DTS"
      value=$DTS
    elif [[ "$codec" == "DTS ES" ]] || [[ "$codec" == "DTS ES XXCH" ]] || [[ "$codec" == "DTS ES XXCH XBR" ]]; then
      codec_clean="DTS-ES"
      value=$DTSES
    elif [[ "$codec" == "DTS XBR" ]]; then
      codec_clean="DTS-HD HRA"
      value=$DTSHDHRA
    elif [[ "$codec" == "E-AC-3" ]]; then
      codec_clean="EAC3"
      value=$EAC3
    elif [[ "$codec" == "E-AC-3 JOC" ]]; then
      codec_clean="EAC3 Atmos"
      value=$EAC3ATMOS
    elif [[ "$codec" == "DTS XLL" ]] || [[ "$codec" == "DTS ES XXCH XLL" ]] || [[ "$codec" == "DTS ES XLL" ]]; then
      codec_clean="DTS-HD MA"
      value=$DTSHDMA
    elif [[ "$codec" == "MLP FBA" ]]; then
      codec_clean="TrueHD"
      value=$TRUEHD
    elif [[ "$codec" == "DTS XLL X" ]]; then
      codec_clean="DTS-X"
      value=$DTSX
    elif [[ "$codec" == "MLP FBA 16-ch" ]]; then
      codec_clean="TrueHD Atmos"
      value=$TRUEHDATMOS
    else
      codec_clean="GARBAGE"
      value=0
    fi
    if [ $stream -eq 1 ] && [[ "$codec_clean" == "$radarr_codec" ]]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$movie${NC}"
      echo -e "[ ${GREEN}OK${NC} ] Audio Stream #$stream matches radarr quality" 
      echo -e "       Radarr: $radarr_codec [$score]"
      echo -e "       Stream #$stream: $codec_clean [$value]"
    # This ignores the fact that radarr has a bug that identifies EAC3 7.1 as AC3 5.1  
    elif [ $stream -eq 1 ] && [[ "AC3" == "$radarr_codec" ]] && [[ "EAC3" == "$codec_clean" ]] || [[ "EAC3 Atmos" == "$codec_clean" ]]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$movie${NC}"
      echo -e "$movie$ -> Check to make sure that this is EAC3 7.1" >> /tmp/fix.txt
      echo -e "[ ${YELLOW}OK${NC} ] Radarr misidentifed EAC3 7.1 as AC3 5.1" 
      echo -e "       Radarr: $radarr_codec [$score]"
      echo -e "       Stream #$stream: $codec_clean [$value]" 
    elif [ $score -lt $value ]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$movie${NC}"
      echo -e "$movie$ -> Has better audio available" >> /tmp/fix.txt
      echo -e "[ ${RED}NOK${NC} ] Audio Stream #$stream is higher quality than radarr" 
      echo -e "        Stream #$stream: $codec_clean [$value]"
      echo -e "        Radarr: $radarr_codec [$score]"
    elif [ $score -gt $value ]; then
      echo -e "       Stream #$stream $codec_clean [$value]"
    fi
  stream=$((stream + 1))
  done
  COUNTER=$((COUNTER + 1))  
done

sed -i -E "0,/(LAST_START=).*/{s|(LAST_START=).*|LAST_START=\"$DATE_CREATED\"|}" "$SCRIPT"
