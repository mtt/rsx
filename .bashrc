EDITOR=vi

#This is called after rsx exits
#Open up the tmp file take appropriate action

rsx_func () {
  RSX_TMP_FILE=`cat /tmp/rsx`
  if [ -d "$RSX_TMP_FILE" ]; then
    cd "$RSX_TMP_FILE"
  elif [ -f "$RSX_TMP_FILE" ]; then
    $EDITOR "$RSX_TMP_FILE"
  fi
}
#catch SIGHUP from ruby script
trap rsx_func 1
