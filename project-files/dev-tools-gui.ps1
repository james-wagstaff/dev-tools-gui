#Load gui
$syncHash = [hashtable]::Synchronized(@{})


function loadGui {
    $inputXml = Get-Content -Path './project-files/dev-tools-gui/MainWindow.xaml'
    $inputXml = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
    [reflection.assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")
    $syncHash.xaml = [xml]$inputXml
    $reader = (New-Object System.Xml.XmlNodeReader $syncHash.xaml)
    $syncHash.Window = [Windows.Markup.XamlReader]::Load($reader)
    init
    $syncHash.Window.showDialog() | out-null
}

function init {
    loadGuiObjectReferences #Load object references before showing dialog
    loadContent #load combobox content for properties section
    addButtonListeners #add button listeners for properties section
}

function loadGuiObjectReferences {
    $syncHash.xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $syncHash.Add($($_.Name), $syncHash.Window.FindName($_.Name))
    }
}
function loadContent {
    $syncHash.properties_repo_location.Text = getRepoLocation

    $syncHash.properties_project.Items.Clear()
    $repos = Get-ChildItem "$(getRepoLocation)" -directory | Select-Object Name
    $repos | % {
        $syncHash.properties_project.AddChild($_.Name)
    }
    $environments = 'dev', 'qa', 'prod'
    $environments | % {
        $syncHash.properties_environment.AddChild($_)
    }
    $syncHash.properties_project.SelectedIndex = 0
    $syncHash.properties_environment.SelectedIndex = 0
}

function addButtonListeners {
    setRepoLocation
    getAppProperties
    copyButtonListener
    
}

function getRepoLocation {
    $repo_root = [System.Environment]::GetEnvironmentVariable('REPOSITORIES_ROOT', [System.EnvironmentVariableTarget]::User)
    return $(if ([string]::IsNullOrEmpty($repo_root)) { './' } else { $repo_root })
}
function setRepoLocation {
    $syncHash.properties_set_repo_location.add_click( {
            $DirDialog = New-Object System.Windows.Forms.FolderBrowserDialog;
            $result = $DirDialog.ShowDialog();
            if ($result -eq 'OK') {
                [System.Environment]::SetEnvironmentVariable('REPOSITORIES_ROOT', $DirDialog.SelectedPath, [System.EnvironmentVariableTarget]::User)
                $syncHash.properties_repo_location.Text = $DirDialog.SelectedPath
                loadContent
            }
        })
}

function copyButtonListener {
    $syncHash.properties_copy_button.add_click( {
            Set-Clipboard -Value $syncHash.properties_output.text
        })
}

$newRunspace = [runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"         
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
function getAppProperties {
    $syncHash.properties_get_properties.add_click( {
            $syncHash.properties_get_properties.IsEnabled = $False
            $syncHash.properties_get_properties.Content = "Loading . . ."
            $syncHash.proj = $syncHash.properties_project.SelectedValue
            $syncHash.env = $syncHash.properties_environment.SelectedValue
            $syncHash.workingDirectory = Get-Location
            $psCmd = [PowerShell]::Create().AddScript( {
                    $parseProps = "$($syncHash.workingDirectory)\project-files\parseAppProperties.ps1"
                    $output = Invoke-Expression "$parseProps $($syncHash.proj) $($syncHash.env)"
                   # $output = ./$parseProps $($syncHash.proj) $($syncHash.env)
                     if (-Not $?) {
                        $syncHash.Window.Dispatcher.invoke(
                            [action] { 
                                $syncHash.properties_output.Text = "
                                Could not get properties. Possible solutions:
                                1) Check vpn connection
                                2) Install jq -> choco install jq
                                "
                                $syncHash.properties_get_properties.IsEnabled = $True
                                $syncHash.properties_get_properties.Content = "get properties"
                            }
                        )
                        return
                    }
                    if ([string]::IsNullOrEmpty($output)) {
                        $syncHash.Window.Dispatcher.invoke(
                            [action] { 
                                $syncHash.properties_output.Text = 'Please check vpn connection'
                                $syncHash.properties_get_properties.IsEnabled = $True
                                $syncHash.properties_get_properties.Content = "get properties"
                            }
                        )
                        return
                    }
                    $output = $output.split(' ')
                    $sb = [System.Text.StringBuilder]::new()
                    $output | % {
                        $sb.AppendLine($_)
                    }
                    $syncHash.Window.Dispatcher.invoke(
                        [action] { 
                            $syncHash.properties_get_properties.IsEnabled = $True
                            $syncHash.properties_get_properties.Content = "get properties"
                            $syncHash.properties_output.Text = $sb.toString()
                        }
                    )
                })
            $psCmd.Runspace = $newRunspace 
            $psCmd.BeginInvoke()
        })
}

loadGui

