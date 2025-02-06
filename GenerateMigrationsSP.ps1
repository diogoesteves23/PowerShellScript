Param(
[Parameter(Mandatory=$true)]
[ValidateScript({Test-Path $_})]
[string]$ProjectPathUrl,
[Parameter(Mandatory=$true)]
[string]$BaseProject,
[Parameter(Mandatory=$true)]
[ValidateScript({Test-Path $_})]
[string]$DataBaseObjectsPathUrl,
[Parameter(Mandatory=$true)]
[string]$MigrationName,
[Parameter(Mandatory=$false)]
[bool]$ChangedToday=$false,
[Parameter(Mandatory=$false)]
[string[]]$DataBaseObjects=@()

) # END PARAMS

$MigrationPath = [IO.Path]::Combine($ProjectPathUrl, $BaseProject, "Repository\Migrations");
Write-Host (-join("Path Of Migrations: ", $MigrationPath));

Write-Host "Generate Migration";
cd $ProjectPathUrl;
$env:ASPNETCORE_ENVIRONMENT='local';
dotnet ef migrations add $MigrationName -o $MigrationPath -p $BaseProject -s [PROJECT_STARTUP];
Write-Host "Migration Generated";

$search = -join("*_",$MigrationName, ".cs");
$MigrationPath = [IO.Path]::Combine($ProjectPathUrl, $BaseProject, "Repository\Migrations");
$latest = Get-ChildItem -Path $MigrationPath -Filter $search | Sort-Object -Descending -Property LastWriteTime | select -First 1;
Write-Host $latest.FullName;
if(![string]::IsNullOrEmpty($latest.FullName))
{
    $codeToInclude = '';

    if($DataBaseObjects.Length -gt 0)
    {
        $firstLine = "true"; 
        foreach($obj in $DataBaseObjects)
        {
            if(![string]::IsNullOrEmpty($obj))
            {
                $objPath = [IO.Path]::Combine($DataBaseObjectsPathUrl, $obj);
                Write-Host (-join("Read Obj: ", $objPath));
                $contentObj = Get-Content -Path $objPath -Raw;
                $contentObj = $contentObj.ToString().Replace('"', '""');
                $codeOfObj = '';

                if($firstLine -eq $true.ToString())
                {
                    $codeOfObj = -join("string sqlCommand = @", '"', $contentObj, '";', "`n", " migrationBuilder.Sql(sqlCommand);", "`n`n");
                }
                else
                {
                    $codeOfObj = -join("sqlCommand = @", '"', $contentObj , '";', "`n" , " migrationBuilder.Sql(sqlCommand);" , "`n`n");
                }
                $codeToInclude = -join($codeToInclude,$codeOfObj);
                $firstLine = "false";
            }
        }

    }
    else
    { 
        $dataBaseAllObjects = Get-ChildItem -Path $DataBaseObjectsPathUrl -Filter "*.sql" | Sort-Object -Property Name | select ;

        if($ChangedToday)
        {
            $dataBaseAllObjects = Get-ChildItem -Path $DataBaseObjectsPathUrl -Filter "*.sql" | Sort-Object -Property Name | select | where-object {$_.LastWriteTimeUtc.Date -eq (Get-Date).Date};
        }

        $firstLine = "true"; 
        foreach($obj in $dataBaseAllObjects)
        {
            if(![string]::IsNullOrEmpty($obj))
            {
                $objPath = $obj.FullName;
                Write-Host (-join("Read Obj: ", $objPath));
                $contentObj = Get-Content -Path $objPath -Raw;
                $contentObj = $contentObj.ToString().Replace('"', '""');
                $codeOfObj = '';

                if($firstLine -eq $true.ToString())
                {
                    $codeOfObj = -join("string sqlCommand = @", '"', $contentObj, '";', "`n", " migrationBuilder.Sql(sqlCommand);", "`n`n");
                }
                else
                {
                    $codeOfObj = -join("sqlCommand = @", '"', $contentObj , '";', "`n" , " migrationBuilder.Sql(sqlCommand);" , "`n`n");
                }
                $codeToInclude = -join($codeToInclude,$codeOfObj);
                $firstLine = "false";
            }
        }
    }

    if(![string]::IsNullOrEmpty($codeToInclude))
    {
        $fileContent = Get-Content -Path $latest.FullName;
        if(![string]::IsNullOrEmpty($fileContent))
        {
            $linePreScript = $fileContent[12-1];
            $linePosScript = $fileContent[14-1];

            if($linePreScript.Trim() -eq '{' -and $linePosScript.Trim() -eq '}')
            {
                $fileContent[13-1] = $codeToInclude;
                $fileContent|Set-Content -Path $latest.FullName;
            }
        }
    }
}