[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$TargetOU,

    [string]$UserPrincipalNameSuffix = "bagayan.local",

    [securestring]$InitialPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

if (-not $InitialPassword) {
    $InitialPassword = Read-Host "Mot de passe initial des comptes" -AsSecureString
}

function ConvertTo-SafeIdentifier {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
    $characters = foreach ($character in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark) {
            $character
        }
    }

    (-join $characters).Normalize([Text.NormalizationForm]::FormC) `
        -replace "[^a-zA-Z0-9]", ""
}

function Get-AvailableSamAccountName {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName
    )

    $candidate = $BaseName.Substring(0, [Math]::Min(20, $BaseName.Length))
    $counter = 1

    while (Get-ADUser -Filter "SamAccountName -eq '$candidate'" -ErrorAction SilentlyContinue) {
        $suffix = $counter.ToString()
        $maxBaseLength = 20 - $suffix.Length
        $candidate = $BaseName.Substring(0, [Math]::Min($maxBaseLength, $BaseName.Length)) + $suffix
        $counter++
    }

    $candidate
}

Get-ADOrganizationalUnit -Identity $TargetOU | Out-Null

$lines = Get-Content -LiteralPath $InputFile -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("#") }

foreach ($line in $lines) {
    $parts = $line -split "\s+", 2

    if ($parts.Count -ne 2) {
        Write-Warning "Ligne ignorée : '$line'. Format attendu : Prénom Nom"
        continue
    }

    $givenName = $parts[0]
    $surname = $parts[1]
    $safeGivenName = (ConvertTo-SafeIdentifier $givenName).ToLowerInvariant()
    $safeSurname = (ConvertTo-SafeIdentifier $surname).ToLowerInvariant()

    if (-not $safeGivenName -or -not $safeSurname) {
        Write-Warning "Ligne ignorée : '$line'. Impossible de produire un identifiant valide."
        continue
    }

    $baseName = ($safeGivenName.Substring(0, 1) + $safeSurname).ToLowerInvariant()
    $samAccountName = Get-AvailableSamAccountName -BaseName $baseName
    $displayName = "$givenName $surname"
    $upn = "$samAccountName@$UserPrincipalNameSuffix"

    if ($PSCmdlet.ShouldProcess($upn, "Créer l'utilisateur Active Directory")) {
        try {
            New-ADUser `
                -Name $displayName `
                -DisplayName $displayName `
                -GivenName $givenName `
                -Surname $surname `
                -SamAccountName $samAccountName `
                -UserPrincipalName $upn `
                -Path $TargetOU `
                -AccountPassword $InitialPassword `
                -Enabled $true `
                -ChangePasswordAtLogon $true

            Write-Host "Compte créé : $upn" -ForegroundColor Green
        }
        catch {
            Write-Error "Échec pour '$displayName' : $($_.Exception.Message)"
        }
    }
}

