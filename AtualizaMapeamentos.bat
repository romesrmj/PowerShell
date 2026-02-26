@echo off
setlocal

REM Caminho local temporário
set LOCALBAT=%TEMP%\restart_local.bat

REM Se ainda estiver rodando da rede, copia e reexecuta localmente
if /I not "%~f0"=="%LOCALBAT%" (
    copy "%~f0" "%LOCALBAT%" >nul
    start "" "%LOCALBAT%"
    exit /b
)

REM ================================
REM A partir daqui roda LOCALMENTE
REM ================================

REM Tempo para reiniciar (em segundos)
set TEMPO_RESTART=10

REM Agenda o reboot (não precisa de admin)
shutdown /r /t %TEMPO_RESTART% /f

REM Remove todos os mapeamentos de rede do usuário
net use * /delete /y

exit /b
