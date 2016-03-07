#!/bin/sh

# show which processes use the most memory

ps aux --sort=-%mem | awk 'NR<=10{print $0}'
