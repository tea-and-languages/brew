@echo off

if not exist .\bootstrap.exe mv brew.exe bootstrap.exe
.\bootstrap.exe README.md .\source\*.md
