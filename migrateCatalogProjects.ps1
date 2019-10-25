# Variables
$ProjectFilePath = "C:\labfiles\tmp"

$TargetServerName = "labserverzqboa73y2zauw.database.windows.net"
$SSISDBServerAdminUserName = "LabUser"
$SSISDBServerAdminPassword = 'Pa$$w0rd'

# Load the IntegrationServices Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null;

# Store the IntegrationServices Assembly namespace to avoid typing it every time
$SSISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"

Write-Host "Connecting to source server ..."

# Create a connection to the server

$sqlConnectionString = "Data Source=.;Initial Catalog=master;Integrated Security=SSPI;" 
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString

# Create the Integration Services object
$integrationServices = New-Object $SSISNamespace".IntegrationServices" $sqlConnection

if ($integrationServices.Catalogs.Count -gt 0)  
{  
    $catalog = $integrationServices.Catalogs["SSISDB"] 
 
    write-host "Enumerating all folders..." 
 
    $folders = $catalog.Folders 
 
    if ($folders.Count -gt 0) 
    { 
        foreach ($folder in $folders) 
        { 
            $foldername = $folder.Name 
            Write-Host "Exporting Folder " $foldername " ..." 
 
            # Create a new file folder 
            mkdir $ProjectFilePath"\"$foldername 
 
            # Export all projects 
            $projects = $folder.Projects 
            if ($projects.Count -gt 0) 
            { 
                foreach($project in $projects) 
                { 
                    $fullpath = $ProjectFilePath + "\" + $foldername + "\" + $project.Name + ".ispac" 
                    Write-Host "Exporting to " $fullpath "  ..." 
                    [System.IO.File]::WriteAllBytes($fullpath, $project.GetProjectBytes()) 
                } 
            } 
        } 
    } 
} 

Write-Host "Exporting done."

Write-Host "Connecting to destination server ..."

# Create a connection to the server
$destsqlConnectionString = "Data Source=" + $TargetServerName + ";User ID="+ $SSISDBServerAdminUserName +";Password="+ $SSISDBServerAdminPassword + ";Initial Catalog=SSISDB"
Write-Host $destsqlConnectionString
$destsqlConnection = New-Object System.Data.SqlClient.SqlConnection $destsqlConnectionString

# Create the Integration Services object
$integrationServicesdest = New-Object $SSISNamespace".IntegrationServices" $destsqlConnection

# Get the catalog
$catalogdest = $integrationServicesdest.Catalogs["SSISDB"]

write-host "Enumerating all folders..."

$destfolders = ls -Path $ProjectFilePath -Directory

if ($destfolders.Count -gt 0)
{
    foreach ($destfilefolder in $destfolders)
    {
        Write-Host "Creating Folder " $destfilefolder.Name " ..."

        # Create a new folder
        $destfolder = New-Object $SSISNamespace".CatalogFolder" ($catalogdest, $destfilefolder.Name, "Folder description")
        $destfolder.Create()

        $projects = ls -Path $destfilefolder.FullName -File -Filter *.ispac
        if ($projects.Count -gt 0)
        {
            foreach($projectfile in $projects)
            {
                $projectfilename = $projectfile.Name.Replace(".ispac", "")
                Write-Host "Deploying " $projectfilename " project ..."

                # Read the project file, and deploy it to the folder
                [byte[]] $projectFileContent = [System.IO.File]::ReadAllBytes($projectfile.FullName)
                $destfolder.DeployProject($projectfilename, $projectFileContent)
            }
        }
    }
}

Write-Host "All done."