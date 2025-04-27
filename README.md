# hkshell



## Getting started

There is two ways you can use these tools:

    1) Just put the contents of the module folder in one of the folders defined in $env:PSModulePath.
    2) You can import the modhandler module with Import-Module '/any/path/to/hkshell/modules/modhandler', then use the hksimport command to import "sub-modules"

## Usage

    MODULES:
        backup
            > Format-BackupConfiguration help
            > Start-Backup help
        execute
            > Start-Execute /path/to/script.ps1 -args "-noprofile"

## Support
Email me at Gregory.Logs@proton.me

## Roadmap
ATM this repo is not in development but always available to tweak and fix stuff.

## Contributing
Feel free to reach out to me about adding to existing modules or adding new modules.

## Authors and acknowledgment
Gregory Shoemake        Owner

## License
Licensed under MIT

## Project status
Stable
