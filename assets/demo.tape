# Where should we write the GIF?
Output assets/demo.gif

Set PlaybackSpeed 3.0
Set CursorBlink false

Set WindowBar Colorful
Set FontSize 12
Set Padding 0
Set Width 1280
Set Height 1200
Set TypingSpeed 100ms

Sleep 3s
Type "./create-scw-wireguard_pi-hole_unbound.sh"
Enter
Sleep 160
Ctrl+Q
Sleep 10
Type "scw instance server terminate with-ip=true with-block=true zone=nl-ams-1 $(scw instance server list zone=all name=wireguard-vps -o json | jq -r '.[].id')"
Enter
Sleep 10
