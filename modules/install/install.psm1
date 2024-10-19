function install {
    [CmdletBinding()]
    param (
        [Parameter()]
        $app
    )
    if ($app -is [System.Array]) {
        return bulkInstall $app
    }
    if (($app -is [System.IO.FileInfo]) -or ($app -is [System.IO.DirectoryInfo])) {
        $app = $app.name
    }
    if ($app -isnot [string]) {
        Write-Host Argument type $($filename.GetType()) is not a valid type -ForegroundColor Red
        return
    }
}
