#!/usr/bin/env ash

if [ "${1}" = "late" ]; then
  
  #----------------------------------------------------------
  # Copy to disk

  cp -fv /usr/bin/bc /tmpRoot/usr/bin/
  cp -fv /usr/bin/od /tmpRoot/usr/bin/
  cp -fv /usr/bin/tr /tmpRoot/usr/bin/
  cp -fv /usr/bin/xxd /tmpRoot/usr/bin/

  #----------------------------------------------------------
  # ding ;)

  ding(){
      printf \\a
  }

  #----------------------------------------------------------
  # Check file exists

  file="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [[ ! -f ${file} ]] && file="/usr/lib/libhwcontrol.so.1"
  
  if [[ ! -f ${file} ]]; then
      ding
      echo -e "${Error}ERROR ${Off} File not found!"
      exit 1
  fi

#----------------------------------------------------------
# Edit file

findbytes(){
    # Get decimal position of matching hex string
    match=$(od -v -t x1 "$1" |
    sed 's/[^ ]* *//' |
    tr '\012' ' ' |
    grep -b -i -o "$hexstring" |
    #grep -b -i -o "$hexstring ".. |
    sed 's/:.*/\/3/' |
    bc)

    # Convert decimal position of matching hex string to hex
    array=("$match")
    if [[ ${#array[@]} -gt "1" ]]; then
        num="0"
        while [[ $num -lt "${#array[@]}" ]]; do
            poshex=$(printf "%x" "${array[$num]}")
            echo "${array[$num]} = $poshex"  # debug

            seek="${array[$num]}"
            xxd=$(xxd -u -l 12 -s "$seek" "$1")
            #echo "$xxd"  # debug
            printf %s "$xxd" | cut -d" " -f1-7
            bytes=$(printf %s "$xxd" | cut -d" " -f6)
            #echo "$bytes"  # debug

            num=$((num +1))
        done
    elif [[ -n $match ]]; then
        poshex=$(printf "%x" "$match")
        echo "$match = $poshex"  # debug

        seek="$match"
        xxd=$(xxd -u -l 12 -s "$seek" "$1")
        #echo "$xxd"  # debug
        printf %s "$xxd" | cut -d" " -f1-7
        bytes=$(printf %s "$xxd" | cut -d" " -f6)
        #echo "$bytes"  # debug
    else
        bytes=""
    fi
}

  #----------------------------------------------------------
  # Backup file

  if [[ ! -f ${file}.bak ]]; then
      if cp "$file" "$file".bak ; then
          echo "Backup successful."
      else
          ding
          echo -e "${Error}ERROR ${Off} Backup failed!"
          exit 1
      fi
  else
      # Check if backup size matches file size
      filesize=$(wc -c "${file}" | awk '{print $1}')
      filebaksize=$(wc -c "${file}.bak" | awk '{print $1}')
      if [[ ! $filesize -eq "$filebaksize" ]]; then
          echo -e "${Yellow}WARNING Backup file size is different to file!${Off}"
          echo "Maybe you've updated DSM since last running this script?"
          echo "Renaming file.bak to file.bak.old"
          mv "${file}.bak" "$file".bak.old
          if cp "$file" "$file".bak ; then
              echo "Backup successful."
          else
              ding
              echo -e "${Error}ERROR ${Off} Backup failed!"
              exit 1
          fi
      else
          echo "File already backed up."
      fi
  fi

  # Check if the file is already edited
  hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
  findbytes "$file"
  if [[ $bytes == "9090" ]]; then
      echo -e "\n${Cyan}File already edited.${Off}"
      exit
  else

      # Check if the file is okay for editing
      hexstring="80 3E 00 B8 01 00 00 00 75 2. 48 8B"
      findbytes "$file"
      if [[ $bytes =~ "752"[0-9] ]]; then
          echo -e "\nEditing file."
      else
          ding
          echo -e "\n${Red}hex string not found!${Off}"
          exit 1
      fi
  fi


  # Replace bytes in file
  posrep=$(printf "%x\n" $((0x${poshex}+8)))
  if ! printf %s "${posrep}: 9090" | xxd -r - "$file"; then
      ding
      echo -e "${Error}ERROR ${Off} Failed to edit file!"
      exit 1
  fi

  #----------------------------------------------------------
  # Check if file was successfully edited

  echo -e "\nChecking if file was successfully edited."
  hexstring="80 3E 00 B8 01 00 00 00 90 90 48 8B"
  findbytes "$file"
  if [[ $bytes == "9090" ]]; then
      echo -e "File successfully edited."
      echo -e "\n${Cyan}You can now create your M.2 storage"\
          "pool in Storage Manager.${Off}"
  else
      ding
      echo -e "${Error}ERROR ${Off} Failed to edit file!"
      exit 1
  fi
fi
