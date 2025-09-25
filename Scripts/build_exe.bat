@echo off
chcp 65001 >nul
echo ==================================================
echo ReadReport Packaging Tool
echo ==================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python not found. Please install Python first.
    pause
    exit /b 1
)

REM Check if pyinstaller is installed
echo Checking if PyInstaller is installed...
python -m PyInstaller --version >nul 2>&1
if %errorlevel% neq 0 (
    echo PyInstaller not found, installing...
    python -m pip install pyinstaller
    if %errorlevel% neq 0 (
        echo Error: Failed to install PyInstaller.
        pause
        exit /b 1
    )
    echo PyInstaller installed successfully.
) else (
    echo PyInstaller is already installed.
)

echo Packaging ReadReport.py...
echo.

REM Remove old build files
if exist "dist\ReadReport.exe" (
    echo Removing old exe file...
    del "dist\ReadReport.exe" >nul 2>&1
)

if exist "build" (
    echo Removing old build directory...
    rmdir /s /q build >nul 2>&1
)

if exist "ReadReport.spec" (
    echo Removing old spec file...
    del "ReadReport.spec" >nul 2>&1
)

echo.
echo Packaging with PyInstaller...
python -m PyInstaller --onefile --windowed ReadReport.py

if %errorlevel% neq 0 (
    echo.
    echo Error: Packaging failed.
    echo Please make sure you have all required dependencies installed:
    echo pip install pandas openpyxl mysql-connector-python pyinstaller
    pause
    exit /b 1
)

echo.
echo ==================================================
echo Packaging completed!
echo EXE file location: dist\ReadReport.exe
echo ==================================================
echo.
pause