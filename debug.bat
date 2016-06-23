@echo off
:: host format is, host [x] [y] [display]
start love . host 0 540 1
:: client format is, client [name] [x] [y] [display]
start love . client Player1 0 0 1
start love . client Player2 960 0 1