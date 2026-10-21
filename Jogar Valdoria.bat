@echo off
rem Duplo clique para jogar: sobe o servidor do mundo (Jev) e abre o jogo na tela inicial.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\unreal\play.ps1" %*
if errorlevel 1 pause
