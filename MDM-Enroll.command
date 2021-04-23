#!/bin/bash
#
# MDM-Enroll v1.4
#
# This script will trigger an Apple Device Enrollment prompt and allow a user to
# easily enroll into the MDM.
#
# NOTE: user's Mac MUST be assigned to a prestage in the MDM - otherwise, no enrollment
# prompt will be presented.
#
# For local testing, edit and run Set-Env.command to set secrets environment variables


# Disable HISTFILE, just in case it was forced enabled in non-interactive sessions.
# (a mostly useless attempt at an additional obfuscation layer)

HISTFILE=/dev/null
export HISTFILE=/dev/null


# handleOutput () Function
#
# Handles user interaction & logging

function handleOutput ()
{
	# Format: handleOutput [action] (optional:[message_string]) (optional:[exit_code])
	#						where [action] can be one of: 	message
	#														multimessage
	#														endblock
	#														exit

	# Output leading newline separator
	if [[ ("$1" != "multimessage" || $startBlock -ne 1) && ("$1" != "endblock") && ("$1" != "exit") ]] || \
	[[ ("$1" == "exit" && ! -z "${2:+unset}") ]]; then
		echo
		startBlock=1
	fi
	
	# Output main message output
	if [[ ! -z "${2:+unset}" ]]; then
		echo -e "$2"; fi
	
	# Output trailing newline separator
	if [[ "$1" != "multimessage" ]]; then
		echo; fi

	# Clear startBlock var for subsequent function runs
	if [[ "$1" == "endblock" ]]; then
		unset startBlock; fi
	
	# Set exit status and exit app
	if [[ "$1" == "exit" ]]; then
		if [[ ! -z "${3+unset}" ]]; then
			exit $3
		else
			exit 0
		fi
	fi
}


# Initialize strings & vars
logWebhookQueryString="currentUserFullName=\"\$currentUserFullName\"&currentUserAccount=\"\$currentUserAccount\
\"&accountType=\"\$accountType\"&computerName=\"\$computerName\"&serialNumber=\"\$serialNumber\
\"&macOSVersion=\"\$macOSVersion\"&externalIP=\"\$externalIP\"&dateStamp=\"\$dateStamp\""
logUpdateWebookQueryString="dateStamp=\"\$dateStamp\""

# Initialize secrets
#
# For local testing, edit and run Set-Env.command to set secrets environment variables
# When building for release, replace variable assignments in the following 4 if blocks with actual 
# secrets prior to compiling script with Platypus

if [[ -z ${adminCredentialsURL+unset} ]]; then
	adminCredentialsURL="[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"; fi
if [[ "$adminCredentialsURL" == "[ENCRYPTED CREDENTIALS STRING URL GOES HERE" ]]; then
    handleOutput multimessage "adminCredentialsURL not set"; fi

if [[ -z ${adminCredentialsPassphrase+unset} ]]; then
	adminCredentialsPassphrase="[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"; fi
if [[ "$adminCredentialsPassphrase" == "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]" ]]; then
    handleOutput multimessage "adminCredentialsPassphrase not set"; fi

if [[ -z ${logWebhookURL+unset} ]]; then
	logWebhookURL="[LOG WEBHOOK URL GOES HERE]"; fi
if [[ "$logWebhookURL" == "[LOG WEBHOOK URL GOES HERE]" ]]; then
    handleOutput multimessage "logWebhookURL not set"; fi

if [[ -z ${logUpdateWebhookURL+unset} ]]; then
	logUpdateWebhookURL="[LOG UPDATE WEBHOOK URL GOES HERE]"; fi
if [[ "$logUpdateWebhookURL" == "[LOG UPDATE WEBHOOK URL GOES HERE]" ]]; then
    handleOutput multimessage "logUpdateWebhookURL not set"; fi

if [[ -z ${organizationName+unset} ]]; then
	organizationName="[ORGANIZATION NAME GOES HERE]"; fi
if [[ "$organizationName" == "[ORGANIZATION NAME GOES HERE]" ]]; then
    handleOutput multimessage "organizationName not set"; fi

if [[ $startBlock -eq 1 ]]; then
	handleOutput exit "For local testing, edit and run Set-Env.command to set secrets variables\
    \nExiting..." 1
fi

# Required for proper running regardless of whether running compiled or as script
scriptDirectory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Determine whether machine is already MDM-enrolled
enrolledInMDM="$(profiles status -type enrollment | tail -n 1 | grep -ci Yes)"
enrolledInMDMviaDEP="$(profiles status -type enrollment | head -n 1 | grep -ci Yes)"

if [[ $enrolledInMDM -eq 1 ]]; then
	handleOutput multimessage "Already enrolled in MDM."

	if [[ $enrolledInMDMviaDEP -eq 1 ]]; then
		handleOutput multimessage "Enrolled via DEP."
        handleOutput exit "Exiting..."
	elif [[ $(sw_vers -productVersion | cut -d '.' -f 1) -ge 11 ]]; then
        handleOutput multimessage "Not enrolled via DEP, but enrollment is supervised (Big Sur)."
        handleOutput exit "Exiting..."
    fi
fi

# Determine current logged-in user account
currentUserAccount="$(stat -f%Su /dev/console)"
currentUserAccountUID=$(dscl . -read "/Users/$currentUserAccount" UniqueID | awk '{print $2}')

# Get Full Name of user and URL-encode
currentUserFullName="$(dscl . -read /Users/$currentUserAccount RealName | cut -d: -f2 | sed -e 's/^[ \t]*//' \
| grep -v "^$" | sed -e 's/ /%20/g')"

# Check if user is admin or standard
if dseditgroup -o checkmember -m "$currentUserAccount" admin|grep -q -w ^yes; then
	accountType="Admin"
else
	accountType="Standard"
fi

# Get computer name and URL-encode
computerName="$(scutil --get ComputerName | sed -e 's/ /%20/g')"

# Get serial number
serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"

# Get OS version
macOSVersion="$(sw_vers -productVersion)"

# Get external IP address
externalIP="$(dig @resolver4.opendns.com myip.opendns.com +short | tail -n 1)"

# Get timestamp
dateStamp="$(date +"%F %T" | sed -e 's/ /%20/g' | sed -e 's/:/%3A/g')"

# Build full webhook query URL
logWebhookFullQueryURL="$(eval "echo \"$(echo "$logWebhookURL"\?"$logWebhookQueryString")\"")"

# Log admin credentials access
logWebhookResult=$(curl -s "$logWebhookFullQueryURL" | sed -En 's/.*"status": "([^"]+)"}$/\1/p')

if [[ "$logWebhookResult" == "success" ]]; then
	# Retrieve and decrypt admin account credentials
	adminCredentials=$(curl -s "$adminCredentialsURL" | openssl enc -aes256 -d -a -A -salt -k "$adminCredentialsPassphrase")
	adminAccount=$(echo "$adminCredentials" | head -n 1)
	adminAccountPass=$(echo "$adminCredentials" | tail -n 1)
else
	handleOutput exit "Could not log credentials access, so credentials were not retrieved." 2
fi

read -r -d '' enrollmentWelcomeDialog <<EOF
display dialog "This tool will enroll you into our MDM platform.\n\nEnrolling into the MDM will help keep your Mac \
protected and up-to-date." with title "$organizationName MDM Enrollment Tool" buttons {"Continue"} default button \
"Continue" with hidden answer with icon alias POSIX file "$scriptDirectory/Pic-Logo.icns"
EOF

# Display dialog box
/bin/launchctl asuser "$currentUserAccountUID" osascript -e "$enrollmentWelcomeDialog" > /dev/null

read -r -d '' enrollmentContinueDialog <<EOF
display dialog "Click on the DEVICE ENROLLMENT notification, which will appear in the top right of your screen several \
seconds after you click Continue below.\n\n\nPlease click Continue to begin." with title "$organizationName Laptop Managment \
Enrollment" buttons {"Continue"} default button "Continue" with hidden answer with icon alias POSIX file \
"$scriptDirectory/Pic-SysPrefs.icns"
EOF

# Display dialog box
/bin/launchctl asuser "$currentUserAccountUID" osascript -e "$enrollmentContinueDialog" > /dev/null

# Mitigate a macOS Downloads folder access permission prompt, which pops up when this script is compiled via Platypus
cd /tmp

# Initiate enrollment
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
	echo
	echo Double-checking demotion...

	if dseditgroup -o checkmember -m "$currentUserAccount" admin|grep -q -w ^yes; then

		echo
		echo User is still an admin - fixing now!
		echo

		# Demote user
		echo "$adminAccountPass" | expect -c '
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

		# Tripple-check that user has been successfully demoted
		echo
		echo Tripple-checking demotion...

		if dseditgroup -o checkmember -m "$currentUserAccount" admin|grep -q -w ^yes; then
			echo
			echo User is STILL an admin - logging an error!
			echo
			exit 4
		else
			echo
			echo User was demoted on second attempt.
			echo
		fi
	else
		echo
		echo User was demoted on first attempt.
		echo		
	fi 

fi
