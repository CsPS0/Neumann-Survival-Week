# Adds the INTERNET permission to every Android preset in an export_presets.cfg that lacks it.
# Co-op needs it. Without it Android refuses to open the network socket.
param([Parameter(Mandatory = $true)][string]$Path)

$lines = [System.IO.File]::ReadAllLines($Path)
$out = New-Object System.Collections.Generic.List[string]
$android = @{}
$has = @{}
$cur = ''
foreach ($l in $lines) {
	if ($l -match '^\[preset\.(\d+)(\.options)?\]$') { $cur = $Matches[1] }
	if ($l -match '^permissions/internet=') { $has[$cur] = $true }
	if ($l -match '^platform="Android"$') { $android[$cur] = $true }
}
$changed = $false
foreach ($l in $lines) {
	$out.Add($l)
	if ($l -match '^\[preset\.(\d+)\.options\]$') {
		$n = $Matches[1]
		if ($android[$n] -and -not $has[$n]) {
			$out.Add('permissions/internet=true')
			$out.Add('permissions/access_network_state=true')
			$changed = $true
		}
	}
}
if ($changed) {
	[System.IO.File]::WriteAllLines($Path, $out.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
	Write-Host 'Added the Android INTERNET permission to HORROR-GAME\export_presets.cfg.'
}
