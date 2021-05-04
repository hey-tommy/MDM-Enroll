#!/bin/bash
#
# MDM-Enroll v1.10
#
# Triggers an Apple Device Enrollment prompt and allows a user to easily enroll 
# into the MDM.
#
# ATTENTION: user's Mac MUST be assigned to a prestage in the MDM - otherwise, 
# no enrollment prompt will be presented.
#
# NOTE 1: While this script can run stand-alone, it is intended to be obfuscated 
# by being embedded in a binary within an .app bundle, which presents as single, 
# user-run app. This is done using a modified fork of bashapp, available at 
# https://github.com/hey-tommy/bashapp
#
# NOTE 2: For local testing, edit and run Set-EnvVars-Toggle.command to set 
# secrets environment variables
#
# WARNING: Be absolutely sure to NOT commit or push this file if you embed your 
# secrets inside it (which you should only be doing right prior to deployment)


# dialogOutput Function
#
# Handles displaying AppleScript dialogs

function dialogOutput ()
{
	# Parameter format:    dialogOutput [dialogText] 
	#                        (optional: [iconName]) 
	#                        (optional: [fallbackIcon]) 
	#                        (optional: [buttonsList]) 
	#                        (optional: [defaultButton]) 
	#                        (optional: [dialogTitle]) 
	#                        (optional: [returnButtonPressedVarName])
	#
	#      Note: function parameters are positional. If skipping an optional 
	#      parameter, but not skipping the one that follows it, replace the 
	#      skipped parameter with an empty string (i.e. "")
	
	local dialogText="$1"
	local dialogContent
	local returnButtonPressed

	# Check dialog icon resources & prepare icon path for dialog
	# shellcheck disable=2155
	if [[ -n "$2" ]]; then
		if [[ ("$2" != "note") && ("$2" != "caution") && ("$2" != "stop") ]]; then
			if [[ -f "$scriptDirectory"/"${!2}" ]]; then
				local iconPath="$scriptDirectory"/"${!2}"
				local dialogIcon="with icon alias POSIX file \"$iconPath\""
			elif [[ -f "$(dirname "$scriptDirectory")"/Resources/"${!2}" ]]; then
				local iconPath="$(dirname "$scriptDirectory")"/Resources/"${!2}"
				local dialogIcon="with icon alias POSIX file \"$iconPath\""
			elif [[ ("$3" == "note") || ("$3" == "caution") || ("$3" == "stop") ]]; then
				local dialogIcon="with icon $3"
			else
				local dialogIcon="with icon note"
			fi
		else
			local dialogIcon="with icon $2"
		fi
	else
		local dialogIcon=""
	fi

	if [[ -n "$4" ]]; then
		local dialogButtonsList='buttons {'"$4"'}'
		if [[ -n "$5" ]]; then
			local dialogDefaultButton='default button "'"$5"\"; fi
	fi

	if [[ -n "$6" ]]; then
		local dialogTitle="$6"; fi

	read -r -d '' dialogContent <<-EOF
	display dialog "$dialogText" with title "$dialogTitle" $dialogButtonsList \
	$dialogDefaultButton $dialogIcon
	EOF

	# Display dialog box
	returnButtonPressed=$(launchctl asuser "$currentUserAccountUID" osascript -e \
	"$dialogContent" | sed -E 's/^button returned:(.*)$/\1/')

	# Return button pressed, if requested
	if [[ -n "$7" ]]; then
		export -n "${7}"="$returnButtonPressed"; fi
}


# handleOutput Function
#
# Handles user interaction, logging and exiting

function handleOutput ()
{
	# Parameter format:    handleOutput [action] 
	#                        (optional: [messageString]) 
	#                        (optional: [exitCode]{int})
	#
	#      where [action] can be one of: 
	#             message        One-line message
	#             block          Multi-line message block, no blank lines in between
	#             blockdouble    Multi-line message block, with blank lines in between
	#             endblock       Marks end of multi-line message block
	#             exit           Exit app with an optional message and exit code
	#
	#      Note: function parameters are positional. If skipping an optional 
	#      parameter, but not skipping the one that follows it, replace the 
	#      skipped parameter with an empty string (i.e. "")

	# Output leading newline separator
	if [[ ($startBlock -ne 1) && ("$1" != "endblock") && ("$1" != "exit") ]] || \
	   [[ ("$1" == "exit") && (-n "${2:+empty}") ]]; then
		echo
		startBlock=1
	fi
	
	# Output main message output
	if [[ -n "${2:+empty}" ]]; then
		echo -e "$2"; fi
	
	# Output trailing newline separator
	if [[ "$1" != "block" ]]; then
		echo; fi

	# Clear startBlock var for subsequent function runs
	if [[ "$1" == "endblock" ]]; then
		unset startBlock; fi
	
	# Set exit code and exit app
	if [[ "$1" == "exit" ]]; then
		if [[ -n "${3+empty}" ]]; then
			exit "$3"
		else
			exit 0
		fi
	fi
}


# initializeSecrets Function
#
# Ensures that secrets are initialized and exits if they aren't properly set

# shellcheck disable=2120

function initializeSecrets ()
{
    # Parameter format: none
	#                   or optionally, a list of secrets variable names to be used
	#					(each var name should be a separate parameter) 
    
    # For local testing, edit and run Set-EnvVars-Toggle to set secrets environment 
	# variables. When doing final testing or building for release, either run 
	# your edited Set-Secrets-Toggle to embed your secrets into this script, or 
	# manually replace variable assignments with your secrets below
    
    
	if [[ $# -eq 0 ]]; then
        declare -a secretsVarNames=( 
            adminCredentialsURL
            adminCredentialsPassphrase
            logWebhookURL
            logUpdateWebhookURL
			moreInfoURL
            organizationName
        )
    else
        declare -a secretsVarNames
        argumentsIndex=0
        for arguments; do
            secretsVarNames[((argumentsIndex++))]="$arguments"; done
    fi

    declare -a secretsActualValues=(
        "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
        "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
        "[LOG WEBHOOK URL GOES HERE]"
        "[LOG UPDATE WEBHOOK URL GOES HERE]"
		"[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
        "[ORGANIZATION NAME GOES HERE]"
    )

    declare -a secretsPlaceholders=(
        "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
        "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
        "[LOG WEBHOOK URL GOES HERE]"
        "[LOG UPDATE WEBHOOK URL GOES HERE]"
		"[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
        "[ORGANIZATION NAME GOES HERE]"
    )

	for index in "${!secretsVarNames[@]}"; do
		if [[ "${secretsActualValues[index]}" != "${secretsPlaceholders[index]}" ]]; then
			export -n "${secretsVarNames[index]}"="${secretsActualValues[index]}"
		elif [[ -z ${!secretsVarNames[index]+empty} || \
		        "${!secretsVarNames[index]}" == "${secretsPlaceholders[index]}" ]]; then        
			handleOutput block "${secretsVarNames[index]}"' not set';
		fi
	done
	
	#shellcheck disable=2154
	if [[ $startBlock -eq 1 ]]; then
		handleOutput exit "For local testing, edit & run Set-EnvVars-Toggle.command `
		`to set secrets env vars \nExiting..." 1
	fi
}


# buildQueryString Function
#
# Concatanates query string parameters

function buildQueryString ()
{
	if [[ -n "${!1}" ]]; then
		export -n "${1}"+='&'; fi
	
	export -n "${1}"+="$2"'='"${!2}"
}


# Disable HISTFILE, just in case it was forced enabled in non-interactive sessions.
# (a mostly useless attempt at an additional obfuscation layer)
HISTFILE="/dev/null"
export HISTFILE="/dev/null"

initializeSecrets;

#initializeSecrets \
#	"adminCredentialsURL" \
#	"adminCredentialsPassphrase" \
#	"logWebhookURL" \
#	"logUpdateWebhookURL" \
#	"moreInfoURL" \
#	"organizationName";

# Initialize variables
# shellcheck disable=2034
iconLogo="Pic-Logo.icns"
# shellcheck disable=2034
iconSysPrefs="Pic-SysPrefs.icns"
# shellcheck disable=2154
dialogTitle="$organizationName MDM Enrollment Tool"

if [[ -n "$moreInfoURL" ]]; then
	introDialogButtons='"More info","Continue"'
else
	introDialogButtons='"Continue"'; fi

# Determine script/executable's parent directory regardless of how it was invoked
if [[ -z ${scriptDirectory+empty} ]]; then
	if [[ -n "${1:+empty}" ]]; then
		scriptDirectory="$1"
	else
		scriptDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
		# zsh variant
		# scriptDirectory="$(cd "$(dirname "${(%):-%x}")" &> /dev/null && pwd)"
	fi
fi

# Determine if running as GUI-only (i.e invoked as .app bundle)
if [[ "$(pwd)" == "/" ]]; then
	guiOnly=1; fi

# Determine whether machine is already MDM-enrolled
enrolledInMDM="$(profiles status -type enrollment | tail -n 1 | grep -ci Yes)"
enrolledInMDMviaDEP="$(profiles status -type enrollment | head -n 1 | grep -ci Yes)"

if [[ $enrolledInMDM -eq 1 ]]; then
	handleOutput block "Already enrolled in MDM."

	if [[ $enrolledInMDMviaDEP -eq 1 ]]; then
		handleOutput block "Enrolled via DEP."
        handleOutput exit "Exiting..."
	elif [[ $(sw_vers -productVersion | cut -d '.' -f 1) -ge 11 ]]; then
        handleOutput block "Not enrolled via DEP, but enrollment is supervised (Big Sur)."
        handleOutput exit "Exiting..."
    fi
fi

# Determine current logged-in user account
currentUserAccount="$(stat -f%Su /dev/console)"
currentUserAccountUID="$(id -u "$currentUserAccount")"

# Get Full Name of user and URL-encode
# shellcheck disable=2034
currentUserFullName="$(dscl . -read /Users/"$currentUserAccount" RealName \
| cut -d: -f2 | sed -e 's/^[ \t]*//' | grep -v "^$" | sed -e 's/ /%20/g')"
buildQueryString logWebhookQueryString currentUserFullName
buildQueryString logWebhookQueryString currentUserAccount

# Check if user is admin or standard
if dseditgroup -o checkmember -m "$currentUserAccount" admin|grep -q -w ^yes; then
	accountType="Admin"
else
	accountType="Standard"
fi
buildQueryString logWebhookQueryString accountType

# Get computer name and URL-encode
# shellcheck disable=2034
computerName="$(scutil --get ComputerName | sed -e 's/ /%20/g')"
buildQueryString logWebhookQueryString computerName

# Get serial number
# shellcheck disable=2034
serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 \
| awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
buildQueryString logWebhookQueryString serialNumber

# Get OS version
# shellcheck disable=2034
macOSVersion="$(sw_vers -productVersion)"
buildQueryString logWebhookQueryString macOSVersion

# Get external IP address
# shellcheck disable=2034
externalIP="$(dig @resolver4.opendns.com myip.opendns.com +short | tail -n 1)"
buildQueryString logWebhookQueryString externalIP

# Get timestamp
# shellcheck disable=2034
dateStamp="$(date +"%F %T" | sed -e 's/ /%20/g' | sed -e 's/:/%3A/g')"
buildQueryString logWebhookQueryString dateStamp
buildQueryString logUpdateWebookQueryString dateStamp

if [[ -n "$logWebhookURL" ]]; then
	# Build full webhook query URL
	# shellcheck disable=2154
	logWebhookFullQueryURL="$logWebhookURL"\?"$logWebhookQueryString"
	#logWebhookFullQueryURL="$(eval "echo \"$(echo "$logWebhookURL"\?"$logWebhookQueryString")\"")"

	# Log admin credentials access
	logWebhookResult=$(curl -s "$logWebhookFullQueryURL" \
	| sed -En 's/.*"status": "([^"]+)"}$/\1/p')
else
	logWebhookResult="skipped"
fi

# Retrieve and decrypt admin account credentials
# shellcheck disable=2154
if [[ "$logWebhookResult" == "success" || "$logWebhookResult" == "skipped" ]]; then
	adminCredentials=$(curl -s "$adminCredentialsURL" \
	| openssl enc -aes256 -d -a -A -salt -k "$adminCredentialsPassphrase")
	adminAccount=$(echo "$adminCredentials" | head -n 1)
	adminAccountPass=$(echo "$adminCredentials" | tail -n 1)
else
	handleOutput exit "Could not log credentials access, so credentials `
	`were not retrieved. \n\nExiting..." 2
fi

introDialogButtonPressed=""
initiateEnrollmentButtonPressed=""

while [[ "$initiateEnrollmentButtonPressed" != 'Initiate' ]]; do

	while [[ "$introDialogButtonPressed" != 'Continue' ]]; do
		dialogOutput "This tool will enroll you into our MDM platform. \
		\n\nEnrolling into the MDM will help keep your Mac protected and up-to-date." \
		iconLogo note "$introDialogButtons" Continue "" introDialogButtonPressed

		if [[ "$introDialogButtonPressed" == 'More info' ]]; then
			# Replace URL with internal MDM enrollment info doc/FAQ
			open -n "$moreInfoURL"; fi
	done

	introDialogButtonPressed=""

	dialogOutput "Click on the DEVICE ENROLLMENT notification, which will appear \
	in the top right of your screen several seconds after you click Continue \
	below.\n\n\nPlease click Initiate to begin." iconSysPrefs caution \
	'"Back","Initiate"' Initiate "" initiateEnrollmentButtonPressed

done

# Initiate enrollment
if [[ "$accountType" == "Admin" ]]; then

	# Admin user workflow
	handleOutput message "User is an admin"

	# Trigger enrollment
	# shellcheck disable=2016
	echo "$adminAccountPass" | expect -c '
	log_user 0
	set adminAccountPass [gets stdin]
	set timeout 5
	spawn su '"$adminAccount"'
	expect "Password:"
	send "$adminAccountPass\r"
	expect " % "
	send "sudo profiles renew -type enrollment\r"
	expect "Password:"
	send "$adminAccountPass\r"
	expect " % "
	sleep 1
	send "exit\r"
	expect eof
	'

else

	# Standard user workflow
	handleOutput message "User is NOT an admin"

	# Promote, trigger enrollment, then demote
	# shellcheck disable=2016
	echo "$adminAccountPass" | expect -c '
	set adminAccountPass [gets stdin]
	log_user 0
	set timeout 5
	spawn su '"$adminAccount"'
	expect "Password:"
	send "$adminAccountPass\r"
	expect " % "
	send "sudo dseditgroup -o edit -a '"$currentUserAccount"' -t user admin\r"
	expect "Password:"
	send "$adminAccountPass\r"
	expect " % "
	send "sudo profiles renew -type enrollment\r"
	expect " % "
	sleep 45
	send "sudo dseditgroup -o edit -d '"$currentUserAccount"' -t user admin\r"
	expect " % "
	sleep 1
	send "exit\r"
	expect eof
	'
	
	# Double-check that user has been successfully demoted
	handleOutput blockdouble "Double-checking demotion..."

	if dseditgroup -o checkmember -m "$currentUserAccount" admin \
	| grep -q -w ^yes; then
		
		handleOutput blockdouble "User is still an admin - fixing now!"

		# Demote user
		# shellcheck disable=2016
		echo "$adminAccountPass" | expect -c '
		log_user 0
        set adminAccountPass [gets stdin]
		set timeout 5
		spawn su '"$adminAccount"'
		expect "Password:"
		send "$adminAccountPass\r"
		expect " % "
		send "sudo dseditgroup -o edit -d '"$currentUserAccount"' -t user admin\r"
		expect "Password:"
		send "$adminAccountPass\r"
		expect " % "
		sleep 1
		send "exit\r"
		expect eof
		'

		# Triple-check that user has been successfully demoted
		handleOutput blockdouble "Triple-checking demotion..."

		if dseditgroup -o checkmember -m "$currentUserAccount" admin \
		| grep -q -w ^yes; then
            handleOutput exit "User is STILL an admin! \nLogging an error & exiting." 3
		else
            handleOutput blockdouble "User was demoted on second attempt."
		fi
	else
		handleOutput blockdouble "User was demoted on first attempt."
	fi

fi

if [[ -n "$logUpdateWebhookURL" ]]; then
	# Build full update webhook query URL
	# shellcheck disable=2154
	logUpdateWebhookFullQueryURL="$logUpdateWebhookURL"\?"$logUpdateWebhookQueryString"

	# Update log with enrollment results 
	logUpdateWebhookResult=$(curl -s "$logUpdateWebhookFullQueryURL" \
	| sed -En 's/.*"status": "([^"]+)"}$/\1/p')
else
	logUpdateWebhookResult="skipped"
fi

if [[ "$logUpdateWebhookResult" != "success" && "$logUpdateWebhookResult" != "skipped" ]]; then
	handleOutput exit "Could not log enrollment results. \n\nExiting..." 4; fi
