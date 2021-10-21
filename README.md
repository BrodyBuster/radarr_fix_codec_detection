# radarr_fix_codec_detection

Script that will curse through your movie library and check to see if radarr correctly matched the audio codec. 

# Scope

Radarr detects the first audio stream in a media file, not the best audio stream. If you are using custom formats for audio, then this can be a problem. For instance you might have a movie that has a DTS-HD MA track and an AC3 track. If the AC3 track is the first track, then radarr will tag this file as AC3 even though there is a higher quality track in the file. This can 1) get you caught in a download loop as radarr will keep attempting to download the file with DTS-HD MA in the realease name, only to tag it as AC3 when it gets imported and renamed OR 2) cause the file to be upgraded later on to a different release. 

The script analysis each movie files and compares the audio tracks in the file with how radarr tagged it and will alert you if it comes across files where there is a higher quality audio track available, that is not the first stream.

You can use the method of your choice (mkvtoolnix or ffmpeg) to fix the problem once the offending movies are identified. I prefer to keep this a manual method, but the script can easily be modified to have ffmpeg reorder the streams. A text file containing offending movies is placed into /tmp/fix.txt. Filenames get appended.

I run this as a cron job and have the results emailed to me. 

The script uses the Radarr API to retrieve the movie database and extract the audio codec quality from there, then compares it to what mediainfo detected


# Prerequisites
1. Radarr
2. The script is written with the following filenaming convention from radarr as shown below. Script can be modified to fit a different filename template, but it will need to have the IMDB ID in the name. 
```
{Movie CleanTitle} {(Release Year)} [imdb-{ImdbId}]{[Quality Title]}{[MediaInfo AudioCodec}{ MediaInfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}
```
3. mediainfo installed
4. A method to update each new movies created time as they are placed into movie library. 

# Installation
1. Save script to to /usr/local/bin/
2. Make sure it's executable (chmod +x)
3. Edit fix-codec.sh and change the variables to your environment. Adjust the codec ranking per radarr custom formats.  
```
MOVIE_PATH="/mnt/movies"
RADARRAPI="[api key from radarr]"
RADARRIP="[ip address of radarr]"

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
```
# Cron job (example runs every 6 hrs) 
```
0 */6 * * *     /usr/local/bin/genreupdate.sh
```


