# AD Group modification monitor
# Copyright 2015 Fred Young
# https://github.com/wanion/Monitor-AD-Groups

If (-Not(Test-Path .\GroupMembers.csv)) { @() | Export-Csv .\GroupMembers.csv }

$Configuration = Get-Content -Raw .\Settings.json | ConvertFrom-Json
$GroupMembership = {Import-Csv .\GroupMembers.csv}.Invoke()
$Text = (Get-Culture).TextInfo

Function Get-GroupViaDirectorySearcher {
	Param ($sAMAccountName)
	$Filter = "(&(&objectclass=group)(samaccountname=$sAMAccountName))"
	$DS = New-Object System.DirectoryServices.DirectorySearcher ([ADSI]$Configuration.SearchRoot),$Filter
	$DS.FindOne()
}

Function Check-Group {
	Param($Group, $Members)

	$Notices = @()

	# Check removed members
	$Usernames = $Members | % { ([ADSI]"LDAP://$_").SamAccountName[0] }
	ForEach($Member in $GroupMembership | ? { $_.Group -eq $Group }) {
		If ($Usernames -NotContains $Member.Username) {
			$GroupMembership.Remove($Member) | Out-Null
			$Notices += "{0} {1} ({2}) has been removed. They were originally added {3}." -f $Text.ToTitleCase($Member.ObjectClass), $Member.Username, $Member.DisplayName, (Get-Date $Member.Added -Format f)
			"$(Get-Date -Format s)`t{0} {1} ({2}) removed from {3}. They were first seen {4}." -f $Text.ToTitleCase($Member.ObjectClass), $Member.Username, $Member.DisplayName, $Group, (Get-Date $Member.Added -Format f) | Add-Content GroupMonitor.log
		}
	}

	# Check added members
	ForEach($Member in $Members) {
		$MemberRef = ([ADSI]"LDAP://$Member")
		$SamAccountName = $MemberRef.SamAccountName[0]
		$ObjectClass = ($MemberRef.ObjectClass | Select -Last 1)
		$DisplayName = $MemberRef.DisplayName[0]
		If (-Not ($GroupMembership | ? {$_.Group -eq $Group -And $_.Username -eq $SamAccountName })) {
			$Notices += "{0} {1} ({2}) has been added." -f $Text.ToTitleCase($ObjectClass), $SamAccountName, $DisplayName
			"$(Get-Date -Format s)`t{0} {1} ({2}) added to {3}." -f $Text.ToTitleCase($ObjectClass), $SamAccountName, $DisplayName, $Group | Add-Content GroupMonitor.log
            $GroupMembership.Add((New-Object PSObject -Property @{
                "Group" = $Group
                "Username" = $SamAccountName
                "DisplayName" = $DisplayName
                "ObjectClass" = $ObjectClass
                "Added" = (Get-Date -Format s)
                }))
		}
	}
	If ($Notices.Count -gt 0) {
		Send-MailMessage -From $Configuration.EmailFrom -To $Configuration.EmailTo -Subject ($Configuration.EmailSubject -Replace '{group}',$Group) -SMTPServer $Configuration.SMTPServer -Body ($Notices -Join "`n")
	}
}

ForEach ($Group in $Configuration.Groups) {
	If ($GroupRef = Get-GroupViaDirectorySearcher($Group)) {
		Check-Group $GroupRef.Properties['sAMAccountName'][0] $GroupRef.Properties['member']
	} else {
		"Couldn't find group $Group."
	}
}

$GroupMembership | Select Group,Username,DisplayName,ObjectClass,Added | Export-Csv -NoType "GroupMembers.csv"