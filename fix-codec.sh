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
LAST_START="2000-10-18 00:00:00"
SCRIPT=$(realpath $0)
DATE_CREATED=$(date "+%Y-%m-%d %T")
MOVIE_PATH=$(realpath -s $MOVIE_PATH)
MOVIEDB=$(curl -s http://$RADARRIP:7878/radarr/api/v3/movie?apiKey=$RADARRAPI | grep -o '"[^"]*"\s*:\s*"[^"]*"' | grep -E '^"(relativePath|audioCodec)"' 2>/dev/null)

if [ -z "$MOVIEDB" ]; then
  echo "Radarr DB could not be retrieved. Please check config ... exiting"
  exit
fi 

DB_COUNT=$(echo "$MOVIEDB" | wc -l)
RADARR_COUNT=$(expr $DB_COUNT / 2)

clear
echo "Script last run on $LAST_START"

echo "Getting movies from $MOVIE_PATH"
declare -a FILE_LIST
while IFS= read -u 3 -d $'\0' -r FILE; do
    FILE_LIST+=( "$FILE" )
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
  MOVIE=$(basename "$X")
  IMDB_TT=$(echo "$X" | grep -Po '(?<=imdb-)[^]]+')
  RADARR_CODEC=$(echo "$MOVIEDB" | grep "$IMDB_TT" -A2 | grep "audioCodec" | cut -d '"' -f4)
  
  if [ -z "$RADARR_CODEC" ]; then
     echo -e "${BLUE}$MOVIE${NC}"
     echo -e "[ ${RED}NOK${NC} ] Movie not found in radarr db" 
     echo -e "$MOVIE$ -> Not found in Radarr db" >> /tmp/fix.txt
  fi   
  
  if [[ "$RADARR_CODEC" == "AC3" ]]; then
    SCORE=$AC3
  elif [[ "$RADARR_CODEC" == "DTS" ]]; then
    SCORE=$DTS
  elif [[ "$RADARR_CODEC" == "DTS-ES" ]]; then
    SCORE=$DTSES
  elif [[ "$RADARR_CODEC" == "DTS-HD HRA" ]]; then
    SCORE=$DTSHDHRA
  elif [[ "$RADARR_CODEC" == "EAC3" ]]; then
    SCORE=$EAC3
  elif [[ "$RADARR_CODEC" == "EAC3 Atmos" ]]; then
    SCORE=$EAC3ATMOS
  elif [[ "$RADARR_CODEC" == "DTS-HD MA" ]]; then
    SCORE=$DTSHDMA
  elif [[ "$RADARR_CODEC" == "TrueHD" ]]; then
    SCORE=$TRUEHD
  elif [[ "$RADARR_CODEC" == "DTS-X" ]]; then
    SCORE=$DTSX
  elif [[ "$RADARR_CODEC" == "TrueHD Atmos" ]]; then
    SCORE=$TRUEHDATMOS
  else
    SCORE=0
  fi
  STREAM=1
  AUDIO_LIST=$(mediainfo "$X" "--inform=General;%Audio_Format_List%" | tr "/" "\n" |  awk '{$1=$1};1')
#  NO_STREAMS=$(echo "$AUDIO_LIST" | wc -l)
  echo "$AUDIO_LIST" | while read -r LINE ; do
    CODEC=$(echo $LINE)
    if [[ "$CODEC" == "AC-3" ]]; then
      CODEC_CLEAN="AC3"
      VALUE=$AC3
    elif [[ "$CODEC" == "DTS" ]]; then
      CODEC_CLEAN="DTS"
      VALUE=$DTS
    elif [[ "$CODEC" == "DTS ES" ]] || [[ "$CODEC" == "DTS ES XXCH" ]] || [[ "$CODEC" == "DTS ES XXCH XBR" ]]; then
      CODEC_CLEAN="DTS-ES"
      VALUE=$DTSES
    elif [[ "$CODEC" == "DTS XBR" ]]; then
      CODEC_CLEAN="DTS-HD HRA"
      VALUE=$DTSHDHRA
    elif [[ "$CODEC" == "E-AC-3" ]]; then
      CODEC_CLEAN="EAC3"
      VALUE=$EAC3
    elif [[ "$CODEC" == "E-AC-3 JOC" ]]; then
      CODEC_CLEAN="EAC3 Atmos"
      VALUE=$EAC3ATMOS
    elif [[ "$CODEC" == "DTS XLL" ]] || [[ "$CODEC" == "DTS ES XXCH XLL" ]] || [[ "$CODEC" == "DTS ES XLL" ]]; then
      CODEC_CLEAN="DTS-HD MA"
      VALUE=$DTSHDMA
    elif [[ "$CODEC" == "MLP FBA" ]]; then
      CODEC_CLEAN="TrueHD"
      VALUE=$TRUEHD
    elif [[ "$CODEC" == "DTS XLL X" ]]; then
      CODEC_CLEAN="DTS-X"
      VALUE=$DTSX
    elif [[ "$CODEC" == "MLP FBA 16-ch" ]]; then
      CODEC_CLEAN="TrueHD Atmos"
      VALUE=$TRUEHDATMOS
    else
      CODEC_CLEAN="GARBAGE"
      VALUE=0
    fi
    if [ $STREAM -eq 1 ] && [[ "$CODEC_CLEAN" == "$RADARR_CODEC" ]]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$MOVIE${NC}"
      echo -e "[ ${GREEN}OK${NC} ] Audio Stream #$STREAM matches radarr quality" 
      echo -e "       Radarr: $RADARR_CODEC [$SCORE]"
      echo -e "       Stream #$STREAM: $CODEC_CLEAN [$VALUE]"
#### This ignores the fact that radarr has a bug that identifies EAC3 7.1 as AC3 5.1  
    elif [ $STREAM -eq 1 ] && [[ "$RADARR_CODEC" == "AC3" ]] && [[ "$CODEC_CLEAN" == "EAC3 Atmos" ]]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$MOVIE${NC}"
      echo -e "$MOVIE$ -> Check to make sure that this is EAC3 7.1" >> /tmp/fix.txt
      echo -e "[ ${YELLOW}OK${NC} ] Radarr misidentifed EAC3 7.1 as AC3 5.1" 
      echo -e "       Radarr: $RADARR_CODEC [$SCORE]"
      echo -e "       Stream #$STREAM: $CODEC_CLEAN [$VALUE]"
    elif [ $STREAM -eq 1 ] && [[ "$RADARR_CODEC" == "AC3" ]] && [[ "$CODEC_CLEAN" == "EAC3" ]]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$MOVIE${NC}"
      echo -e "$MOVIE$ -> Check to make sure that this is EAC3 7.1" >> /tmp/fix.txt
      echo -e "[ ${YELLOW}OK${NC} ] Radarr misidentifed EAC3 7.1 as AC3 5.1" 
      echo -e "       Radarr: $RADARR_CODEC [$SCORE]"
      echo -e "       Stream #$STREAM: $CODEC_CLEAN [$VALUE]" 
#### end of radarr bug check
    elif [ $SCORE -lt $VALUE ]; then
      echo -e "[$COUNTER OF $MOVIE_COUNT] - ${BLUE}$MOVIE${NC}"
      echo -e "$MOVIE$ -> Has better audio available" >> /tmp/fix.txt
      echo -e "[ ${RED}NOK${NC} ] Audio Stream #$STREAM is higher quality than radarr" 
      echo -e "        Stream #$STREAM: $CODEC_CLEAN [$VALUE]"
      echo -e "        Radarr: $RADARR_CODEC [$SCORE]"
    elif [ $SCORE -gt $VALUE ]; then
      echo -e "       Stream #$STREAM $CODEC_CLEAN [$VALUE]"
    fi
  STREAM=$((STREAM + 1))
  done
  COUNTER=$((COUNTER + 1))  
done

sed -i -E "0,/(LAST_START=).*/{s|(LAST_START=).*|LAST_START=\"$DATE_CREATED\"|}" "$SCRIPT"
