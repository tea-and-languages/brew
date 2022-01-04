@echo off

if not exist .\bootstrap.exe copy brew.exe bootstrap.exe
.\bootstrap.exe README.md .\source\*.md
