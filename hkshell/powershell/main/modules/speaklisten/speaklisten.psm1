function sl_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function sl_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function sl_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host $message -ForegroundColor $messageColor
}

function speak {
    $a_ = $args

    
}
