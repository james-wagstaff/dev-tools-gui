#include other scripts
. "$(Get-Location)/project-files/application-properties.ps1"
. "$(Get-Location)/project-files/system-properties.ps1"

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

function addTextBoxListeners {
    $syncHash.propertiesUpdateButton.Add_Click( {
            setCFApi($syncHash.cfApiText.Text)
            setCFUser($syncHash.cfUserText.Text)
            setCFPassword($syncHash.cfPasswordText.Text)
            [System.Windows.MessageBox]::Show("Properties updated")
        })
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

    $syncHash.properties_environment.ItemsSource = cfEnvironments
    
    $syncHash.properties_project.SelectedIndex = 0
    $syncHash.properties_environment.SelectedIndex = 0
    $syncHash.cfApiText.Text = getCFApi
    $syncHash.cfUserText.Text = getCFUser
    $syncHash.cfPasswordText.Text = getCFPassword
}

function addButtonListeners {
    $syncHash.properties_set_repo_location.add_click( {
        setRepoLocation
        loadContent
    })
    getAppProperties
    addTextBoxListeners
}

function setLoading {
    $syncHash.properties_get_properties.IsEnabled = $False
    $syncHash.properties_get_properties.Content = "Loading . . ."
}

function global:resetLoading {
    $syncHash.properties_get_properties.IsEnabled = $True
    $syncHash.properties_get_properties.Content = "get properties"
}

$newRunspace = [runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"         
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

function getAppProperties {
    $syncHash.properties_get_properties.add_click( {
            $cfMessage = $(allFineWithCf)
            if (-Not [string]::IsNullOrEmpty($cfMessage) ) {
                [System.Windows.MessageBox]::Show($cfMessage)
                return
            }

            setLoading
            $syncHash.proj = $syncHash.properties_project.SelectedValue
            $syncHash.env = $syncHash.properties_environment.SelectedValue
            $syncHash.workingDirectory = Get-Location
            $psCmd = [PowerShell]::Create().AddScript( {
                   
                    Invoke-Expression "cf orgs"
                    if (-Not $?) {
                        [System.Windows.MessageBox]::Show("Trying to login")
                        Invoke-Expression "cf login -a $getCFApi -u $getCFUser -p $getCFPassword -o identifix_cms -s Development"
                    }

                    $parseProps = "$($syncHash.workingDirectory)\project-files\parseAppProperties.ps1"
                    $output = Invoke-Expression "$parseProps $($syncHash.proj) $($syncHash.env)"

                    if (-Not $?) {
                        $syncHash.Window.Dispatcher.invoke(
                            [action] { 
                                $syncHash.properties_get_properties.IsEnabled = $True
                                $syncHash.properties_get_properties.Content = "get properties"
                            }
                        )
                        return
                    }
                   
                    $syncHash.Window.Dispatcher.invoke(
                        [action] { 
                            $syncHash.properties_get_properties.IsEnabled = $True
                            $syncHash.properties_get_properties.Content = "get properties"
                            $outputFile = "$($syncHash.properties_repo_location.Text)\$($syncHash.proj)\application.properties"
                            Out-File -FilePath $outputFile -InputObject $output
                            [System.Windows.MessageBox]::Show("Properties saved to $outputFile")
                        }
                    )
                })
            $psCmd.Runspace = $newRunspace 
            $psCmd.BeginInvoke()
        })
}

loadGui

