### utility functions

function _diff() {
	gci -rec -file -inc *.bak | % {
		$bak = resolve-path -Path $_ -Relative
		$src  = $bak -replace "\.bak",""
		
		for ($i = 1; ; $i++) {
			$patch = "$src-$i.patch"
			if (-not (Test-Path -Path $patch)) {
				break
				
			}
		}
		
		diff --color=always -p -u -w "$bak" "$src"	 > $patch
		remove-item -for $bak -erroract ignore
			
		# "test -s" equivalent
		if (-not ((Test-Path -Path $patch) -and ((Get-Item -Path $patch).Size -gt 0))) {
			remove-item -force -path $patch -erroract ignore
			continue
			
		}
		
		write-host "$patch"
		/bin/cat $patch
		
	}
	#read-host "press ENTER";clear
}

function _backup() {
	$arg1 = $args[0]
	copy-item -Path $arg1 -Destination "$arg1.bak"
	
}

function _notify_patch() {
	$arg1 = $args[0]
	write-host "`n$($PSStyle.Foreground.BrightYellow)PATCHING: $arg1$($PSStyle.Reset)"
	#write-host "`nPATCHING: $arg1"
	
}

function Find-InString {
	param (
		[ValidateSet("Regex", "Plain")]
		[String] $SearchType,
		
		[String] $String,
		[String] $Pattern
		
	)
	
	if ($SearchType -eq "Regex") {
		return ($String -match $Pattern)
		
	} elseif ($SearchType -eq "Plain") {
		return $String.Contains($Pattern)
		
	}
}

function Replace-InString {
	param (
		[ValidateSet("Regex", "Plain")]
		[String] $SearchType,
		
		[String] $String,
		[String] $Pattern,
		[String] $Replacement
	)
	
	if ($SearchType -eq "Regex") {
		return ($String -replace $Pattern, $Replacement)
		
	} elseif ($SearchType -eq "Plain") {
		return $String.Replace($Pattern, $Replacement)
		
	}
}

# garbage sed clone that runs 2 bajillion % slower
function Edit-FileByLine {
	param(
		[Parameter(Mandatory)]
		[String] $Path,
		
		[Switch] $Backup,
		
		[ValidateSet("Regex", "Plain")]
		[String] $SearchType,
		[String] $Pattern,
		[String] $Replacement,
		
		[ValidateSet("Regex", "Plain")]
		[String] $DeleteThroughSearchType,
		[String] $DeleteThrough,
		
		[int] $ActionDeleteNextNLines,
		
		[Switch] $DBG
	)
	
	$LinesForDeletion = 0
	$DeleteThrough_Running = $false
	
	$SearchType -eq "" ? ($SearchType = "Plain") : {}
	
	if ((($Replacement -ne "") -or ($DeleteThrough -ne "")) -and $ActionDeleteNextNLines) {
		throw "-Replacement/-DeleteThrough and -ActionDeleteNextNLines are mutually exclusive and can't be used together."
	}
	
	if ($Backup) {
		_backup $Path
		
	}
	
	$ct = 1
	$Contents = /bin/cat $Path
	Remove-Item $Path
	
	$Contents | % {
		if ($DBG) {
			write-warning "checking line $ct :"
			write-host $_
			$ct++
		}
		
		#Set-PSDebug -trace 1
		if ($LinesForDeletion -gt 0) {
			$LinesForDeletion -= 1
			return # drop line, don't append
			
		} elseif ($DeleteThrough_Running) {
			if (Find-InString -Search $DeleteThroughSearchType -String $_ -Pattern $DeleteThrough) {
				#	write-warning "FOUND $DeleteThrough WITH `"$_`", STOPPING!"
				$DeleteThrough_Running = $false
				
				# if replacement is defined, shove that in instead
				if ($Replacement -ne "") {
					$Replacement >> $Path
					
				}
			}
			
			return # throw away current line regardless
			
		} else {
			# if target line found, set lines-to-be-deleted to N
			if ($ActionDeleteNextNLines -and (Find-InString -Search $SearchType -String $_ -Pattern $Pattern)) {
				$LinesForDeletion = $ActionDeleteNextNLines
				$FixedLine = $_ # keep this line!
				
			# if target line found, start deleting lines untill pattern matches
			} elseif (($DeleteThrough -ne "") -and (Find-InString -Search $SearchType -String $_ -Pattern $Pattern)) {
				$DeleteThrough_Running = $true
				return # THROW AWAY CURRENT LINE!
				
			} else {
				$FixedLine = Replace-InString -Search $SearchType -String $_ -Pattern $Pattern -Replacement $Replacement
				
			}
			
			$FixedLine >> $Path
			
		}
	}
}
