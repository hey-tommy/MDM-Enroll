#!/bin/bash
# MDM-Enroll v1.11
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

# TODO: write all text errors to stderr (either via >&2 or err)
# TODO: convert all tabs to spaces except for heredoc areas
# TODO: declare all constants
# TODO: proper & useful commenting

# dialogOutput Function
#
# Handles displaying AppleScript dialogs

function dialogOutput ()
{
	# Parameter format:    dialogOutput [dialogText] 
	#                        (optional: [iconName]) 
	#                        (optional: [fallbackIcon]) 
	#                        (optional: [buttonsList])   *** see below 
	#                        (optional: [defaultButton]) 
	#                        (optional: [dialogAppTitle]) 
	#                        (optional: [dialogTimeout]) 
	#                        (optional: [returnButtonPressedVarName])
	#
	#      *** Each button name should be double-quoted, then comma-delimited.
	#          Pass this entire parameter surrounded with single quotes. Also, 
	#          while there is no way to have NO buttons in AppleScript dialogs, 
	#          any button can be made blank by setting the button name to an empty 
	#          string (i.e ""). Lastly, if this parameter is omitted entirely, 
	#          the dialog will automatically get an OK and Cancel buttons.          
	#
	#      Note: function parameters are positional. If skipping an optional 
	#      parameter, but not skipping the one that follows it, replace the 
	#      skipped parameter with an empty string (i.e. "")
	
	local dialogText="$1"

	# Check dialog icon resources & prepare icon path for dialog
	if [[ -n "$2" ]]; then
		if [[ ("$2" != "note") && ("$2" != "caution") && ("$2" != "stop") ]]; then
			if [[ -f "${2}" ]]; then
				local iconPath="${2}"
			elif [[ -f "$scriptDirectory"/"${2}" ]]; then
				local iconPath="$scriptDirectory"/"${2}"
			elif [[ -f "$scriptDirectory"/Resources/"${2}" ]]; then
				local iconPath="$scriptDirectory"/Resources/"${2}"
			elif [[ -f "$(dirname "$scriptDirectory")"/Resources/"${2}" ]]; then
				local iconPath
				iconPath="$(dirname "$scriptDirectory")"/Resources/"${2}"
			fi

			if [[ -n "$iconPath" ]]; then
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
		local dialogButtonsList="buttons {$4}"	
		if [[ -n "$5" ]]; then
			local dialogDefaultButton="default button \"$5\""; fi
	fi

	if [[ -n "$6" ]]; then
		local dialogAppTitle="$6"; fi

	if [[ -n "$7" ]]; then
		local dialogTimeout="giving up after $7"; fi

	local dialogContent
	read -r -d '' dialogContent <<-EOF
	display dialog "$dialogText" with title "$dialogAppTitle" $dialogButtonsList \
	$dialogDefaultButton $dialogIcon $dialogTimeout
	EOF

	# Display dialog box
	local returnButtonPressed
	returnButtonPressed=$(launchctl asuser "$currentUserAccountUID" osascript -e \
	"$dialogContent" | sed -E 's/^button returned:(.*)$/\1/')

	# Return button pressed, if requested
	if [[ -n "$8" ]]; then
		export -n "${8}"="$returnButtonPressed"; fi
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
	if [[ ($startBlock -ne 1) && ("$1" != "endblock") && ("$1" != "exit") ]] \
	|| [[ ("$1" == "exit") && (-n "${2:+empty}") ]]; then
		echo
		startBlock=1
	fi
	
	# Output main message output
	if [[ -n "${2:+empty}" ]]; then
		echo -e "$2"; fi
	
	### TODO: implement GUI messaging via dialogOutput

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
		elif [[ -z "${!secretsVarNames[index]+empty}" \
		     || "${!secretsVarNames[index]}" == "${secretsPlaceholders[index]}" ]]; then        
			handleOutput block "${secretsVarNames[index]}"' not set';
		fi
	done
	
	if [[ $startBlock -eq 1 ]]; then
		handleOutput exit "For local testing, edit & run Set-EnvVars-Toggle.command `
		`to set secrets env vars \nExiting..." 1
		## TODO: Add dialog output if secrets not embedded
	fi
}


# buildQueryString Function
#
# Concatenates query string parameters

function buildQueryString ()
{
	if [[ -n "${!1}" ]]; then
		export -n "${1}"+='&'; fi
	
	export -n "${1}"+="$2"'='"${!2}"
}


# initiateEnrollment Function
#
# Handles privilege elevation and initiates actual MDM enrollment
#
# shellcheck disable=2016

function initiateEnrollment ()
{

# TODO: create an expect script concatenating function

if [[ "$accountType" == "Admin" ]]; then

	# Admin user workflow
	handleOutput message "User is an admin"

	# Trigger enrollment
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
			## TODO: Add to log + dialog output if user could not be demoted
		else
            handleOutput blockdouble "User was demoted on second attempt."
		fi
	else
		handleOutput blockdouble "User was demoted on first attempt."
	fi

fi

}


# shellcheck disable=2034,2154

function main ()
{

# TODO: Internet connectivity test

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
isJamfPro=1   #Set this to 1 if your MDM is Jamf Pro
macOSVersion="$(sw_vers -productVersion)"
dialogAppTitle="$organizationName MDM Enrollment Tool"
if [[ $isJamfPro -eq 1 ]]; then
	selfServiceAppName="$organizationName Self Service"
	iconSelfService="Pic-Logo.icns"
fi
iconLogo="Pic-Logo.png"
iconClock="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Clock.icns"
if [[ ${macOSVersion::2} -ge 11 ]]; then
	iconDEP="/System/Library/CoreServices/ManagedClient.app/Contents/PlugIns`
	`/ConfigurationProfilesUI.bundle/Contents/Resources/SystemPrefApp.icns"
else
	iconDEP="/System/Library/PreferencePanes/Profiles.prefPane/Contents`
	`/Resources/Profiles.icns"
fi

# Determine script/executable's parent directory regardless of how it was invoked
if [[ -z "${scriptDirectory+empty}" ]]; then
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

# Determine current logged-in user account
currentUserAccount="$(stat -f%Su /dev/console)"
currentUserAccountUID="$(id -u "$currentUserAccount")"

# Get Full Name of user and URL-encode
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
computerName="$(scutil --get ComputerName | sed -e 's/ /%20/g')"
buildQueryString logWebhookQueryString computerName

# Get serial number
serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 \
| awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
buildQueryString logWebhookQueryString serialNumber

# Get OS version
buildQueryString logWebhookQueryString macOSVersion

# Get external IP address
externalIP="$(dig @resolver4.opendns.com myip.opendns.com +short | tail -n 1)"
buildQueryString logWebhookQueryString externalIP

# Determine whether machine is already MDM-enrolled
enrolledInMDM="$(profiles status -type enrollment | tail -n 1 | grep -ci Yes)"
enrolledInMDMviaDEP="$(profiles status -type enrollment | head -n 1 | grep -ci Yes)"

# Get timestamp
dateStamp="$(date +"%F %T" | sed -e 's/ /%20/g' | sed -e 's/:/%3A/g')"
buildQueryString logWebhookQueryString dateStamp
buildQueryString logUpdateWebookQueryString dateStamp

if [[ -n "$logWebhookURL" ]]; then
	# Build full webhook query URL
	logWebhookFullQueryURL="$logWebhookURL"\?"$logWebhookQueryString"

	# Log admin credentials access
	logWebhookResult=$(curl -s "$logWebhookFullQueryURL" \
	| sed -En 's/.*"status": "([^"]+)"}$/\1/p')
else
	logWebhookResult="skipped"
fi

# Exit if already MDM-enrolled
if [[ $enrolledInMDM -eq 1 ]]; then
	handleOutput block "Already enrolled in MDM."

	if [[ $enrolledInMDMviaDEP -eq 1 ]]; then
		handleOutput block "Enrolled via DEP."
        handleOutput exit "Exiting..."
	elif [[ ${macOSVersion::2} -ge 11 ]]; then
        handleOutput block "Not enrolled via DEP, but enrollment is supervised (Big Sur)."
        handleOutput exit "Exiting..."
    fi
fi

# Retrieve and decrypt admin account credentials
if [[ "$logWebhookResult" == "success" || "$logWebhookResult" == "skipped" ]]; then
	adminCredentials=$(curl -s "$adminCredentialsURL" \
	| openssl enc -aes256 -d -a -A -salt -k "$adminCredentialsPassphrase")
	adminAccount=$(echo "$adminCredentials" | head -n 1)
	adminAccountPass=$(echo "$adminCredentials" | tail -n 1)
else
	handleOutput exit "Could not log credentials access, so credentials `
	`were not retrieved. \n\nExiting..." 2
fi

### TODO: check for existence of retrieved admin account +log/throw error/dialog
### TODO: check for validity of retrieved admin password +log/throw error/dialog

if [[ -n "$moreInfoURL" ]]; then
	introDialogButtons='"What is MDM?","MDM FAQ","Continue"'
else
	introDialogButtons='"Continue"'; fi

# TODO: move dialog text definitions to a separate function that gets called
#       from dialogOutput

introDialogButtonPressed=""
initiateEnrollmentButtonPressed=""

while [[ "$initiateEnrollmentButtonPressed" != 'Initiate enrollment' ]]; do

	while [[ "$introDialogButtonPressed" != 'Continue' ]]; do
		if [[ "$mdmInfoDialogButtonPressed" != 'MDM FAQ' ]]; then
			dialogOutput \
				"This tool will enroll you into our MDM platform.\n\n`
				`Enrolling into MDM will help keep your Mac protected and `
				`up-to-date.\n\n" \
				"$iconLogo" \
				"note" \
				"$introDialogButtons" Continue "" "" \
				"introDialogButtonPressed"
		fi

		mdmInfoDialogButtonPressed=""

		if [[ "$introDialogButtonPressed" == "What is MDM?" ]]; then
			dialogOutput \
				"What is MDM?\n\n`
				`MDM (Mobile Device Management) allows $organizationName to `
				`configure, secure, and update your Mac, as well as install `
				`software and device policies.\n\n`
				`What MDM is NOT:\n\n`
				`MDM is not a spying, monitoring, or content filtering system. `
				`It does NOT allow $organizationName to monitor your screen, `
				`keyboard, camera, or microphone.\n\n\n`
				`Have more questions? Click \\\"MDM FAQ\\\" below.\n" \
				"$iconSelfService" \
				"note" \
				'"MDM FAQ","Back"' \
				"Back" \
				"" \
				"" \
				"mdmInfoDialogButtonPressed"
		fi
		
		if [[ "$introDialogButtonPressed" == 'MDM FAQ' 
		   || "$mdmInfoDialogButtonPressed" == 'MDM FAQ' ]]; then
			open -n "$moreInfoURL"; fi
	done

	introDialogButtonPressed=""

	dialogOutput \
		"After clicking \\\"Initiate enrollment\\\" below, you will receive a `
		`notification in the top-right corner of your screen.\n\n`
		`You will need to click that notification and follow the prompts to enroll.\n" \
		"$iconLogo" \
		"caution" \
		'"Back","Initiate enrollment"' \
		"Initiate enrollment" \
		"" \
		"" \
		"initiateEnrollmentButtonPressed"

done

initiateEnrollment &

dialogOutput "\n\nWaiting 5 seconds for enrollment notification...\n\n" \
	"$iconClock" \
	"" \
	'"Waiting..."' \
	"" \
	"" \
	5

completedEnrollmentButtonPressed=""

dialogOutput \
	"Click on the DEVICE ENROLLMENT notification in the top-right corner of your `
	`screen.\n\n`
	`Then, click \\\"Allow\\\" and enter your Mac password to enroll (if prompted).\n\n\n`
	`Once done, click \\\"I'm enrolled!\\\" below.\n" \
	"$iconDEP" \
	"note" \
	'"Clicked \"Allow\", nothing happened","No notification?","I'\''m enrolled!"' \
	"" \
	"" \
	"" \
	"completedEnrollmentButtonPressed"

### TODO: Verify enrollment success and add results to log

if [[ "$completedEnrollmentButtonPressed" == "I'm enrolled!" ]]; then
	if [[ "$isJamfPro" -eq 1 ]]; then
		dialogOutput \
			"Thanks for enrolling your Mac!\n\nThe enrollment process will `
			`complete in the background over the next 5 minutes.\n\nAfter that, `
			`you will find a new \\\"$selfServiceAppName\\\" app in your `
			`Applications folder (icon like the one on the left). Use it to `
			`install any of the available apps - even if you're not an admin." \
			"$iconSelfService" \
			"note" \
			'"Exit"'
	else
		dialogOutput \
			"Thanks for enrolling your Mac!\n\nThe enrollment process will `
			`complete in the background over the next 5 minutes.\n\n" \
			"$iconLogo" \
			"note" \
			'"Exit"'
	fi
fi

case "$completedEnrollmentButtonPressed" in

	("Clicked \"Allow\", nothing happened")
		dialogOutput \
			"This can sometimes happen if something in the background interrupts `
			`the enrollment process.\n\n`
			`Please try closing your System Preferences \n(if open), and run `
			`this app again." \
			"caution" \
			"" \
			'"Exit"'
		;;

	("No notification?")
		dialogOutput \
			"Please try running this app again.\n\n\n`
			`If you still don't get a DEVICE ENROLLMENT notification, contact `
			`$organizationName IT and let them know.\n" \
			"caution" \
			"" \
			'"Exit"'
		;;

esac

if [[ -n "$logUpdateWebhookURL" ]]; then
	# Build full update webhook query URL
	logUpdateWebhookFullQueryURL="$logUpdateWebhookURL"\?"$logUpdateWebhookQueryString"

	# Update log with enrollment results 
	logUpdateWebhookResult=$(curl -s "$logUpdateWebhookFullQueryURL" \
	| sed -En 's/.*"status": "([^"]+)"}$/\1/p')
else
	logUpdateWebhookResult="skipped"
fi

if [[ "$logUpdateWebhookResult" != "success" \
   && "$logUpdateWebhookResult" != "skipped" ]]; then
	handleOutput exit "Could not log enrollment results. \n\nExiting..." 4; fi

}

main "$@"