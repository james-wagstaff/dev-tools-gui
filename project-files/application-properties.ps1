. "$(Get-Location)/project-files/system-properties.ps1"
function cfEnvironments {
    return @('dev', 'qa', 'prod')
}

function getRepoLocation {
    $repo_root = [System.Environment]::GetEnvironmentVariable('REPOSITORIES_ROOT', [System.EnvironmentVariableTarget]::User)
    return $(if ([string]::IsNullOrEmpty($repo_root)) { './' } else { $repo_root })
}

function setRepoLocation {
    $DirDialog = New-Object System.Windows.Forms.FolderBrowserDialog;
    $result = $DirDialog.ShowDialog();
    if ($result -eq 'OK') {
        [System.Environment]::SetEnvironmentVariable('REPOSITORIES_ROOT', $DirDialog.SelectedPath, [System.EnvironmentVariableTarget]::User)
        $syncHash.properties_repo_location.Text = $DirDialog.SelectedPath
    }
}

function allFineWithCf {
    if (-Not $(areCFPropsSet)) {
        return "CF properties are not set"
    }
    if (-Not $(Test-Connection -ComputerName $($(getCFApi) -replace 'https://', '') -Count 1 -Quiet)) {
        return "Check vpn connection"
    }
    return
}