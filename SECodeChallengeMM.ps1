# This script performs the actions in the Powershell Coding Challenge for the Support Engineering Team - Mike McLaughlin

New-Item -Path C:\ -Name "CleanTemp.log" -ItemType "file"

$trigger = New-JobTrigger -Weekly -DaysOfWeek Sunday -At "1:00 AM"
$opt = New-ScheduledJobOption -RunElevated -StartIfOnBattery

# Replaced user account info with domain\credentials due to pushing to github
# For the sake of this challenge I used our it administrator account for testing, for a production scenario I would more likely use a service account
$cred = Get-Credential -UserName domain\credentials

# To keep everything in a single script I decided to create a scheduled job that runs a scriptblock directly
# Due to creating a recurring job only once, I didn't need to remove old jobs
# This creates the Scheduled job which reports the information on the local system TEMP folder before and after removing its contents and clears the recycling bin
Register-ScheduledJob -Name ClearTempJob -Trigger $trigger -Credential $cred -ScheduledJobOption $opt -scriptblock { 
	$date = Get-Date
	$OldItems = $date.AddHours(-24)
	
	# This filter is used with many of my variables to add a timestamp to my log file
	filter timestamp {"$(Get-Date -Format G): $_"}
	
	# This creates a path to C:\Windows\Temp. I assume this is the Temp folder that was being asked for in the instructions. 
	# If I was meant to use my local user temp folder, I would have replaced this with $env:temp
	$path = [Environment]::GetEnvironmentVariable("TEMP", "Machine")
	
	$files = Get-ChildItem $path -File | Measure-Object | Select-Object `
		-expandproperty Count | timestamp
	$folders = Get-ChildItem $path -Directory | Measure-Object | Select-Object `
		-expandproperty Count | timestamp
		
	# Error action here was used because the script was erroring if the temp folder was empty
	$size = Get-ChildItem $path | Measure-Object -sum Length `
		-ErrorAction SilentlyContinue | Select-Object -expandproperty Sum | timestamp 
	
	$before = "Before Removal Files, Folders, and Size:" | timestamp
	$after = "After Removal Files, Folders, and Size:" | timestamp
	$tlog = "C:\CleanTemp.log"

		Add-Content -Path $tlog -Value $before, $files, $folders, $size
		
		# During testing I wasn't having any items not deleting due to being pinned open. 
		# I ultimate decide to just continue on ErrorAction as a means to exclude items that would be pinned open
		Get-ChildItem $path -Recurse | Where-Object { $_.CreationTime -lt $OldItems } | Remove-Item `
			-Force -Recurse -ErrorAction SilentlyContinue

	$files2 = Get-ChildItem $path -File | Measure-Object | Select-Object `
		-expandproperty Count | timestamp
	$folders2 = Get-ChildItem $path -Directory | Measure-Object | Select-Object `
		-expandproperty Count | timestamp
	$size2 = Get-ChildItem $path | Measure-Object -sum Length `
		-ErrorAction SilentlyContinue | Select-Object -expandproperty Sum | timestamp
		Add-Content -Path $tlog -Value $after, $files2, $folders2, $size2

	$path2 = Split-Path -Path $path -Qualifier
		Clear-RecycleBin -DriveLetter $path2 -Force

	# In order to show success or failure I decided to check to see if the size of the temp folder changed
	# I struggled to find a solution to making a scheduled job report success or failure to a log file, so this was my solution
	# Scheduled jobs do however create their own application event log of success or failure, which can be used to show if the job was complete
	If ($size -eq $size2) {
		$failure = "Scheudled Job failed to remove any items" | timestamp
		Add-Content -Path C:\CleanTemp.log -Value $failure
	} Else {
		$success = "Scheduled Job successfully removed items" | timestamp
		Add-Content -Path $tlog -Value $success
	}
}



