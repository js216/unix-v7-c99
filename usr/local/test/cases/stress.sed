/^# cat \/usr\/dict\/words/,/^# echo r""c/{
/^# /!d
}
s/^[0-9][0-9]* Killed$/PID Killed/
s/^ticks [1-9][0-9]*$/ticks N/
