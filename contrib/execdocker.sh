docker run -it -e LANG=en_GB.UTF-8 -e LC_ALL=en_GB.UTF-8 -u 1000 --mount type=bind,source="$(pwd)",target=/bistools -w /bistools mcr.microsoft.com/powershell:lts-ubuntu-22.04 pwsh ./ccoutput.ps1 --prefix FilePrefixCC
