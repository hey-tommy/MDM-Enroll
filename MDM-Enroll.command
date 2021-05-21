#!/bin/bash
#
###################
# MDM-Enroll v2.4
###################
#
# Triggers a macOS device enrollment prompt and allows a user to easily enroll 
# into the MDM.
#
# This tool utilizes Automated Device Enrollment, formerly (and better) known
# as DEP (Device Enrollment Progam), to trigger a device enrollment 
# notification, which the user can then use to initiate MDM enrollment.
# 
# Because the tool uses DEP, the user's Mac must be present in Apple Business 
# Manager and assigned to an MDM server. And in that MDM, the Mac must also have 
# an enrollment settings profile assigned to it (what Jamf Pro calls a PreStage 
# Enrollment). If all of these requirements aren't met, enrollment will not be 
# possible, and this tool will notify the user accordingly (see 
# displayEnrollmentResultsUI for dialog text).
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


########### TODO Tracker

#### √   Legend:
# ^  ^<< Completed (also moved to bottom of list)
# ^<<<<< Priority  (# to ####)

###    TODO: Add verbiage re: no restart required
##     TODO: Make notInPrestage local
##     TODO: Replace hardcoded timing with variables/constants 
##     TODO: add 10.12 MDM routines & logic
##     TODO: implement oldestMacOS as a variable
#      TODO: create an expect script concatenating function
#      TODO: write all text errors to stderr (either via >&2 or err)
#      TODO: declare all constants
#      TODO: proper & useful commenting
#      TODO: move dialog text definitions to a separate function that gets 
           # called from dialogOutput

#### √ TODO: check for existence of retrieved admin account +log/throw error/dialog
#### √ TODO: check for validity of retrieved admin password +log/throw error/dialog
#### √ TODO: check if machine is assigned to a prestage
#### √ TODO: Verify enrollment success and add results to log
###  √ TODO: exit if OS version is below macOS 10.12 Sierra (or 10.13 if not 
           # implementing 10.12 MDM routines)
##   √ TODO: Add dialog output if secrets not embedded
##   √ TODO: Add to log output if user could not be demoted
#    √ TODO: internet connectivity test (needs text + dialog, exit code 2)
#    √ TODO: convert all tabs to spaces except for heredoc areas


# initializeEarlyVariables Function
#
# Initializes variables/constants needed prior to initializing secrets

function initializeEarlyVariables ()
{
    # Parameter format: initializeEarlyVariables (optional:[scriptDirectory])
    #     See note in main () for info on scriptDirectory

    # Determine script/executable's parent directory regardless of how it was invoked
    if [[ -z "${scriptDirectory+empty}" ]]; then
        if [[ -n "${1:+empty}" ]]; then
            scriptDirectory="$1"
        else
            scriptDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
        fi
    fi    

    # Disable HISTFILE, just in case it was forced enabled in non-interactive 
    # sessions (a mostly useless attempt at an additional obfuscation layer)
    HISTFILE="/dev/null"
    export HISTFILE="/dev/null"

    # Determine current logged-in user account (needed early for dialog output)
    currentUserAccount="$(stat -f%Su /dev/console)"
    currentUserAccountUID="$(id -u "$currentUserAccount")"

    # Determine macOS version (needed early for setting icon resources)
    macOSVersion="$(sw_vers -productVersion)"
    # TESTING
    #macOSVersion=10.2.4
}


# initializeSecrets Function
#
# Ensures that secrets are initialized & exits if they aren't properly set

function initializeSecrets ()
{
    # Parameter format:    none
    #
    # For local testing, edit and run Set-EnvVars-Toggle to set secrets environment 
    # variables. When doing final testing or building for release, either run 
    # your edited Set-Secrets-Toggle to embed your secrets into this script, or 
    # manually replace variable assignments with your secrets below
    
    declare -a secretsVarNames=( 
        adminCredentialsURL
        adminCredentialsPassphrase
        organizationName
        moreInfoURL
        logMainWebhookURL
        logUpdateWebhookURL
    )

    declare -a secretsActualValues=(
        "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
        "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
        "[ORGANIZATION NAME GOES HERE]"
        "[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
        "[LOG MAIN WEBHOOK URL GOES HERE]"
        "[LOG UPDATE WEBHOOK URL GOES HERE]"
    )

    declare -a secretsPlaceholders=(
        "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
        "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
        "[ORGANIZATION NAME GOES HERE]"
        "[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
        "[LOG MAIN WEBHOOK URL GOES HERE]"
        "[LOG UPDATE WEBHOOK URL GOES HERE]"
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
        dialogOutput \
            "\nFor local testing, first edit, then run:\n`
            `> Set-EnvVars-Toggle.command\n`
            `to set secrets environment variables.\n" \
            "stop" \
            "" \
            '"Exit"' \
            "Exit" \
            "MDM Enrollment Tool"
        handleOutput \
            exit \
            "For local testing, edit & run Set-EnvVars-Toggle.command to set secrets `
            `env vars\n\n`
            `Exiting..." \
            1
    fi
}


# initializeVariables Function
#
# Initializes the rest of variables/constants, and global named pipes

function initializeVariables ()
{
    # Parameter format: none

    # shellcheck disable=2154
    dialogAppTitle="$organizationName MDM Enrollment Tool"
    mdmIsJamfPro=1   #Set this to 1 if your MDM is Jamf Pro
    iconOrganizationLogo="Pic-OrgLogo.icns"
    if [[ $mdmIsJamfPro -eq 1 ]]; then
        iconSelfService="Pic-SelfService.icns"
        selfServiceAppName="$organizationName Self Service"
    fi
    iconClock="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources`
              `/Clock.icns"
    if [[ ${macOSVersion%%.*} -ge 11 ]]; then
        iconDEP="/System/Library/CoreServices/ManagedClient.app/Contents/PlugIns`
                `/ConfigurationProfilesUI.bundle/Contents/Resources`
                `/SystemPrefApp.icns"
        iconCheckMark="Pic-Profiles.png"
    else
        iconDEP="/System/Library/PreferencePanes/Profiles.prefPane/Contents`
                `/Resources/Profiles.icns"
        iconCheckMark="$iconDEP"
    fi


    # Initialize global named pipes
    mkfifo /tmp/notInPrestage
    exec 4<> /tmp/notInPrestage
    unlink /tmp/notInPrestage

    mkfifo /tmp/dialogPID
    exec 5<> /tmp/dialogPID
    unlink /tmp/dialogPID

    mkfifo /tmp/enrollProblemButtonClicked
    exec 6<> /tmp/enrollProblemButtonClicked
    unlink /tmp/enrollProblemButtonClicked
}


# dialogOutput Function
#
# Displays an AppleScript dialog

function dialogOutput ()
{
    # Parameter format:    dialogOutput [dialogText] 
    #                        (optional: [iconName]) 
    #                        (optional: [fallbackIcon]) 
    #                        (optional: [buttonsList])   *** see below 
    #                        (optional: [defaultButton]) 
    #                        (optional: [dialogAppTitle]) 
    #                        (optional: [dialogTimeout]) 
    #                        (optional: [returnButtonClickedVarName]) 
    #                        (optional: [returnValuesViaPipes] {bool}) 
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
    

    # Check dialog icon resources & prepare icon path for dialog

    local dialogText="$1"
    local dialogIcon
    local iconPath

    if [[ -n "$2" ]]; then
        if [[ ("$2" != "note") && ("$2" != "caution") && ("$2" != "stop") ]]; then
            if [[ -f "${2}" ]]; then
                iconPath="${2}"
            elif [[ -f "$scriptDirectory"/"${2}" ]]; then
                iconPath="$scriptDirectory"/"${2}"
            elif [[ -f "$scriptDirectory"/Resources/"${2}" ]]; then
                iconPath="$scriptDirectory"/Resources/"${2}"
            elif [[ -f "$(dirname "$scriptDirectory")"/Resources/"${2}" ]]; then
                iconPath="$(dirname "$scriptDirectory")"/Resources/"${2}"
            fi

            if [[ -n "$iconPath" ]]; then
                dialogIcon="with icon alias POSIX file \"$iconPath\""
            elif [[ ("$3" == "note") || ("$3" == "caution") || ("$3" == "stop") ]]; then
                dialogIcon="with icon $3"
            else
                dialogIcon="with icon note"
            fi
        else
            dialogIcon="with icon $2"
        fi
    else
        dialogIcon=""
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
    local dialogPID
    local dialogReturned
    local buttonClicked
    
    mkfifo /tmp/dialogReturned
    exec 3<> /tmp/dialogReturned
    unlink /tmp/dialogReturned
    
    launchctl asuser "$currentUserAccountUID" osascript -e "$dialogContent" 1>&3 \
    & dialogPID=$!
    
    # Return dialog PID immediately, if requested
    if [[ -n "$9" ]]; then
        echo "$dialogPID" 1>&5
    fi
    read -r -u3 dialogReturned
    exec 3>&-
    
    buttonClicked="$(echo "$dialogReturned" \
                   | sed -E 's/^button returned:(, )?(.*)$/\2/')"
    
    # Return button clicked, if requested
    if [[ -n "$9" ]]; then
        echo "$buttonClicked" 1>&6
    elif [[ -n "$8" ]]; then
        export -n "${8}"="$buttonClicked"
    fi
}


# handleOutput Function
#
# Handles text output & exit codes

function handleOutput ()
{
    # Parameter format:    handleOutput [action] 
    #                        (optional: [messageString]) 
    #                        (optional: [exitCode]{int})
    #
    #     where [action] can be one of: 
    #            message        One-line message
    #            block          Multi-line message block, no blank lines in between
    #            endblock       Marks end of multi-line message block
    #            exit           Exit app with an optional message and exit code
    #
    #     Note: function parameters are positional. If skipping an optional 
    #     parameter, but not skipping the one that follows it, replace the 
    #     skipped parameter with an empty string (i.e. "")

    # Output leading newline separator
    if [[ ($startBlock -ne 1) && ("$1" != "endblock") && ("$1" != "exit") ]] \
    || [[ ("$1" == "exit") && (-n "${2:+empty}") ]]; then
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


# urlEncode Function
#
# URL-encodes strings, including extended Unicode characters

function urlEncode ()
{
    # Parameter format:    urlEncode [inputString]

    local string_length="${#1}"
    local loop
    local og_char
    local encoded_char

    for (( loop = 0; loop < string_length; loop++ )); do
        og_char="${1:loop:1}"
        case $og_char in
            ([a-zA-Z0-9.~_-]) 
                printf "%s" "$og_char"
                ;;
            (*)
                printf "%s" "$og_char" | xxd -p -c1 | while read -r encoded_char; do 
                    printf "%%%s" "$encoded_char"
                done
                ;;
        esac
    done
}


# buildQueryString Function
#
# Concatenates query string parameters

function buildQueryString ()
{
    # Parameter format:    buildQueryString [queryStringVarName] [parameterVarName]
    
    local queryStringVarName="${1}QueryString"
    local parameterVarName="$2"
    local queryStringValue="${!queryStringVarName}"
    local parameterValue="${!parameterVarName}"
    
    parameterValue="$(urlEncode "$parameterValue")"
    
    if [[ -n "$queryStringValue" ]]; then
        export -n "$queryStringVarName"+='&'; fi
    
    export -n "${queryStringVarName}"+="$parameterVarName"'='"$parameterValue"
}


# logWebook Function
#
# Logs results & errors to a webhook URL

function logWebhook ()
{
    # Parameter format:    logWebhook [webhookName]

    local webhookURLVarName="${1}URL"
    local queryStringVarName="${1}QueryString"
    local webhookURL="${!webhookURLVarName}"
    local queryString="${!queryStringVarName}"
    local fullQueryURL="$webhookURL"\?"$queryString"
    local webhookResult

    webhookResult=$(curl -s "$fullQueryURL" | sed -En 's/.*"status": "([^"]+)"}$/\1/p')

    if [[ "$webhookResult" == "success" ]]; then
        return 0
    else
        return 1
    fi
}


# versionCompare Function
#
# Converts a versions into a numerically comparable number

function versionCompare 
{ 
    # Parameter format:    versionCompare [version]

    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}


# checkInternet Function
#
# Checks basic internet connectivity (DNS & ICMP) & exits if none detected

function checkInternet ()
{
    # Parameter format:    none
    
    if ! ping -q -c 1 -W 1 google.com > /dev/null 2>&1; then
        
        dialogOutput \
            "\nLooks like you've got no Internet connectivity!\n\n\n`
            `Please check your connection and try running this app again.\n" \
            "caution" \
            "" \
            '"Exit"' \
            "Exit"
        
        handleOutput \
            exit \
            "You are not connected to the Internet!\n\n`
            `Exiting..." \
            2
    fi
}


# collectLoggingData Function
#
# Collects logging data and adds parameters to logging query string
#
# shellcheck disable=2034

function collectLoggingData ()
{
    # Parameter format:    none

    # Add earlier-determined parameters to logging query string
    buildQueryString logMainWebhook currentUserAccount
    buildQueryString logMainWebhook macOSVersion

    # Get full name of user
    currentUserFullName="$(dscl . -read /Users/"$currentUserAccount" RealName \
    | cut -d: -f2 | sed -e 's/^[ \t]*//' | grep -v "^$")"
    buildQueryString logMainWebhook currentUserFullName

    # Check if user is admin or standard
    if dseditgroup -o checkmember -m "$currentUserAccount" admin|grep -q -w ^yes; then
        currentUserAccountType="Admin"
    else
        currentUserAccountType="Standard"
    fi
    # TESTING
    #currentUserAccountType="Standard"
    buildQueryString logMainWebhook currentUserAccountType

    # Get computer name
    computerName="$(scutil --get ComputerName)"
    buildQueryString logMainWebhook computerName

    # Get serial number
    serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 \
    | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
    buildQueryString logMainWebhook serialNumber

    # Get external IP address
    externalIP="$(dig @resolver4.opendns.com myip.opendns.com +short | tail -n 1)"
    buildQueryString logMainWebhook externalIP

    # Determine whether machine is already MDM-enrolled
    enrolledInMDM="$(profiles status -type enrollment | grep -ci "enrollment: Yes")"
    enrolledInMDMviaDEP="$(profiles status -type enrollment | grep -ci "dep: Yes")"

    # Get timestamp
    timeStamp="$(date +"%Y-%m-%dT%H:%M:%S%z")"
    buildQueryString logMainWebhook timeStamp
    buildQueryString logUpdateWebhook timeStamp
}


# checkIfAlreadyEnrolled Function
#
# Checks whether Mac is already MDM-enrolled AND supervised, and exits if it is

function checkIfAlreadyEnrolled ()
{
    # Parameter format:    none
    
    # TESTING
    #enrolledInMDM=1
    
    if [[ $enrolledInMDM -eq 1 ]] \
    && [[ $enrolledInMDMviaDEP -eq 1 || ${macOSVersion%%.*} -ge 11 ]]; then

        if [[ -n "$logMainWebhookURL" ]]; then
            successfullyEnrolled="Yes"
            buildQueryString logMainWebhook successfullyEnrolled
            # shellcheck disable=2034
            enrollmentNote="Already MDM-enrolled"
            buildQueryString logMainWebhook enrollmentNote
            logWebhook logMainWebhook
        fi

        handleOutput block "Already enrolled in MDM."
        if [[ $enrolledInMDMviaDEP -eq 1 ]]; then
            handleOutput block "Enrolled via DEP."
        elif [[ ${macOSVersion%%.*} -ge 11 ]]; then
            handleOutput block "Not enrolled via DEP, but enrollment is `
                `supervised (Big Sur)."
        fi

        dialogOutput \
            "Good news!\n\n`
            `Looks you're already enrolled in MDM, so there's nothing for you `
            `to do.\n\n`
            `Have a great day!" \
            "$iconOrganizationLogo" \
            "caution" \
            '"Exit"' \
            "Exit"

        handleOutput exit "Exiting..." 0

    fi
}


# checkMacOSVersion Function
#
# Verifies that macOS version is compatible with tool

function checkMacOSVersion ()
{
    # Parameter format: none
    
    if [[ $(versionCompare "$macOSVersion") -lt $(versionCompare 10.13) ]]; then
        if [[ -n "$logMainWebhookURL" ]]; then
            successfullyEnrolled="No"
            buildQueryString logMainWebhook successfullyEnrolled
            enrollmentError="macOS version too old"
            buildQueryString logMainWebhook enrollmentError
            logWebhook logMainWebhook
        fi

        # shellcheck disable=2154
        dialogOutput \
            "Unfortunately, your macOS version is not supported by this `
            `enrollment tool.\n\n`
            `You need to be running macOS 10.13 High Sierra or higher, but you `
            `are currently running $macOSVersion instead.\n\n`
            `Please ontact $organizationName IT and let them know, and they'll `
            `be happy to supply you with alternate enrollment instructions." \
            "caution" \
            "" \
            '"Exit"'

        handleOutput exit "macOS version is too old\n\n`
            `Tool needs 10.13+, but running $macOSVersion\n\n`
            `Exiting..." 3

    fi
}


# logAndRetrieveCredentials Function
#
# Attempts to log credential access, retrieves credentials, & exits if logging failed

function logAndRetrieveCredentials ()
{
    # Parameter format: none

    if [[ -n "$logMainWebhookURL" ]]; then
        logWebhook logMainWebhook
        logWebhookResult=$?
    else
        logWebhookResult="skipped"
    fi

    # Retrieve and decrypt admin account credentials
    if [[ "$logWebhookResult" -eq 0 || "$logWebhookResult" == "skipped" ]]; then

        # shellcheck disable=2154
        adminCredentials=$(curl -s "$adminCredentialsURL" \
        | openssl enc -aes256 -d -a -A -salt -k "$adminCredentialsPassphrase")
        
        adminAccount="${adminCredentials%[[:space:]]*}"  # Discards \n and after
        adminAccountPass="${adminCredentials#*[[:space:]]}"  # Discards \n and before

    else

        dialogOutput \
        "Could not connect to logging server.\n\n`
        `If you are seeing this, that means that the IT monkeys at `
        `$organizationName have messed up miserably.\n\n`
        `Let them know their fellow nerdren are highly disappointed in them.\n\n" \
        "stop" \
        "" \
        '"Exit"'

        successfullyEnrolled="No"
        buildQueryString logMainWebhook successfullyEnrolled
        enrollmentError="Could not log credentials access"
        buildQueryString logMainWebhook enrollmentError
        logWebhook logMainWebhook  # This will probably fail too, but trying anyway

        handleOutput exit "Could not log credentials access, so credentials `
        `were not retrieved. \n\nExiting..." 4

    fi
}


# validateCredentials Function
#
# Verifies that retrieved admin account exists, and retrieved password is valid

function validateCredentials ()
{
    # Parameter format: none

    # TESTING
    #adminAccount=diwn93n
    if ! dscl . read /Users/"$adminAccount" > /dev/null 2>&1; then
        adminAccountNotFound=1
        if [[ -n "$logUpdateWebhookURL" ]]; then
            successfullyEnrolled="No"
            buildQueryString logUpdateWebhook successfullyEnrolled
            enrollmentError="Required admin account not found"
            buildQueryString logUpdateWebhook enrollmentError
            logWebhook logUpdateWebhook
        fi
    fi

    # TESTING
    #adminAccountPass=agf9nhl
    if ! dscl . authonly "$adminAccount" "$adminAccountPass" > /dev/null 2>&1; then
        if [[ ("$adminAccountNotFound" -ne 1) && (-n "$logUpdateWebhookURL") ]]; then
            successfullyEnrolled="No"
            buildQueryString logUpdateWebhook successfullyEnrolled
            enrollmentError="Admin password not valid"
            buildQueryString logUpdateWebhook enrollmentError
            logWebhook logUpdateWebhook
        fi

        dialogOutput \
            "The expected account credentials do not appear to be valid on this `
            `computer.\n\n`
            `Please contact $organizationName IT and let them know, and they'll `
            `be happy to supply you with alternate enrollment instructions." \
            "caution" \
            "" \
            '"Exit"'

        if [[ "$adminAccountNotFound" -eq 1 ]]; then
            handleOutput exit \
                "The required admin account ($adminAccount) is not on this `
                `computer.\n\n`
                `Exiting..." 5
        else
            handleOutput exit \
                "The password for the required admin account ($adminAccount) `
                `is no longer valid on this computer.\n\n`
                `Exiting..." 6
        fi
    fi
}


# displayIntroUI Function
#
# Displays introductory dialogs up to enrollment initiation
#
# shellcheck disable=2154

function displayIntroUI ()
{
    # Parameter format: none

    # Initialize first intro dialog's buttons labels
    if [[ -n "$moreInfoURL" ]]; then
        introDialogButtons='"What is MDM?","MDM FAQ","Continue"'
    else
        introDialogButtons='"What is MDM?","Continue"'; fi

    # Top-level intro dialogs navigation loop
    while [[ "$initiateEnrollmentButtonClicked" != 'Initiate enrollment' ]]; do

        while [[ "$introDialogButtonClicked" != 'Continue' ]]; do
            if [[ "$mdmInfoDialogButtonClicked" != 'MDM FAQ' ]]; then
                dialogOutput \
                    "This tool will enroll you into our MDM platform.\n\n`
                    `Enrolling into MDM will help keep your Mac protected and `
                    `up-to-date.\n\n" \
                    "$iconOrganizationLogo" \
                    "note" \
                    "$introDialogButtons" \
                    "Continue" \
                    "" \
                    "" \
                    "introDialogButtonClicked"
            fi

            unset mdmInfoDialogButtonClicked

            if [[ "$introDialogButtonClicked" == "What is MDM?" ]]; then
                dialogOutput \
                    "What is MDM?\n\n`
                    `MDM (Mobile Device Management) allows $organizationName to `
                    `configure, secure, and update your Mac, as well as install `
                    `software and device policies.\n\n`
                    `What MDM is NOT:\n\n`
                    `MDM is not a spying, monitoring, or content filtering `
                    `system. It does NOT allow $organizationName to monitor `
                    `your screen, keyboard, camera, or microphone.\n\n\n`
                    `Have more questions? Click \\\"MDM FAQ\\\" below.\n" \
                    "$iconSelfService" \
                    "note" \
                    '"MDM FAQ","Back"' \
                    "Back" \
                    "" \
                    "" \
                    "mdmInfoDialogButtonClicked"
            fi
            
            if [[ "$introDialogButtonClicked" == 'MDM FAQ' 
            || "$mdmInfoDialogButtonClicked" == 'MDM FAQ' ]]; then
                open -n "$moreInfoURL"; fi
        done

        unset introDialogButtonClicked

        dialogOutput \
            "After clicking \\\"Initiate enrollment\\\" below, you will receive `
            `a notification in the top-right corner of your screen.\n\n`
            `You will need to click that notification and follow the prompts to `
            `enroll.\n" \
            "$iconOrganizationLogo" \
            "caution" \
            '"Back","Initiate enrollment"' \
            "Initiate enrollment" \
            "" \
            "" \
            "initiateEnrollmentButtonClicked"

    done
}


# triggerEnrollmentNotification Function
#
# Handles privilege elevation and triggers enrollment notification
#
# shellcheck disable=1004,2016

function triggerEnrollmentNotification ()
{
    # Parameter format:    none

    local notInPrestage

    if [[ "$currentUserAccountType" == "Admin" ]]; then

        # Admin user workflow
        handleOutput message "User is an admin"

        # Trigger enrollment
        echo "$adminAccountPass" | expect -c '
        set adminAccountPass [gets stdin]
        log_user 0
        set timeout 10
        spawn su '"$adminAccount"'
        expect "Password:"
        send "$adminAccountPass\r"
        expect " % "
        send "sudo echo > /dev/null\r"
        expect "Password:"
        send "$adminAccountPass\r"
        expect " % "
        #
        send "sudo profiles show -type enrollment | head -n 2\r"
        expect " % "
        if {[string match "*Client is not DEP enabled*" $expect_out(buffer)]} {
            send "sudo profiles renew -type enrollment\r"
            expect " % "
            send "sudo profiles show -type enrollment | head -n 2\r"
            expect " % "
        }
        if {[string match "*(null)*" $expect_out(buffer)] \
        || [string match "*Client is not DEP enabled*" $expect_out(buffer)]} {
            sleep 1
            send "exit\r"
            exit 1
        }
        sleep 1
        send "exit\r"
        expect eof
        '

        notInPrestage=$?
        echo "$notInPrestage" 1>&4

    else

        # Standard user workflow
        handleOutput message "User is a standard user"

        # Promote, trigger enrollment, then demote
        echo "$adminAccountPass" | expect -c '
        set adminAccountPass [gets stdin]
        log_user 0
        set timeout 10
        spawn su '"$adminAccount"'
        expect "Password:"
        send "$adminAccountPass\r"
        expect " % "
        send "sudo echo > /dev/null\r"
        expect "Password:"
        send "$adminAccountPass\r"
        expect " % "
        #
        send "sudo dseditgroup -o edit -a '"$currentUserAccount"' -t user admin\r"
        expect " % "
        send "sudo profiles show -type enrollment | head -n 2\r"
        expect " % "
        if {[string match "*Client is not DEP enabled*" $expect_out(buffer)]} {
            send "sudo profiles renew -type enrollment\r"
            expect " % "
            send "sudo profiles show -type enrollment | head -n 2\r"
            expect " % "
        }
        if {[string match "*(null)*" $expect_out(buffer)] \
        || [string match "*Client is not DEP enabled*" $expect_out(buffer)]} {
            send "sudo dseditgroup -o edit -d '"$currentUserAccount"' -t user admin\r"
            expect " % "
            sleep 1
            send "exit\r"
            exit 1
        }
        sleep 45
        expect " % "
        send "sudo dseditgroup -o edit -d '"$currentUserAccount"' -t user admin\r"
        expect " % "
        #
        sleep 1
        send "exit\r"
        expect eof
        '
        
        notInPrestage=$?
        echo "$notInPrestage" 1>&4

        # Double-check that user has been successfully demoted
        handleOutput block "Double-checking demotion..."

        if dseditgroup -o checkmember -m "$currentUserAccount" admin \
        | grep -q -w ^yes; then
            
            handleOutput block "User is still an admin - attempting to fix..."

            # Demote user
            echo "$adminAccountPass" | expect -c '
            set adminAccountPass [gets stdin]
            log_user 0
            set timeout 10
            spawn su '"$adminAccount"'
            expect "Password:"
            send "$adminAccountPass\r"
            expect " % "
            send "sudo echo > /dev/null\r"
            expect "Password:"
            send "$adminAccountPass\r"
            expect " % "
            #
            send "sudo dseditgroup -o edit -d '"$currentUserAccount"' -t user admin\r"
            expect " % "
            #
            sleep 1
            send "exit\r"
            expect eof
            '

            # Triple-check that user has been successfully demoted
            handleOutput block "Triple-checking demotion..."

            if dseditgroup -o checkmember -m "$currentUserAccount" admin \
            | grep -q -w ^yes; then
                return 2  # User could NOT be demoted!
            else
                return 1  # Demoted on second attempt
            fi
        else
            return 0  # Demoted on first attempt
        fi

    fi

}


# displayEnrollmentUI Function
#
# Displays dialogs that present during enrollment

function displayEnrollmentUI ()
{
    # Parameter format: none

    dialogOutput "\n\nWaiting 5 seconds for enrollment notification...\n\n" \
        "$iconClock" \
        "" \
        '"Waiting..."' \
        "" \
        "" \
        5

    # Launch main enrollment instructions dialog in background process so it can 
    # be killed via its PID as soon as successful enrollment is detected

    dialogOutput \
        "Click on the DEVICE ENROLLMENT notification in the top-right corner of `
        `your screen.\n\n`
        `Then, click \\\"Allow\\\", and if asked, enter your Mac password.\n\n`
        `( Auto-detecting enrollment... )\n" \
        "$iconDEP" \
        "note" \
        '"Clicked \"Allow\", but nothing happened?","No notification?"' \
        "" \
        "" \
        53 \
        "enrollProblemButtonClicked" \
        "true" \
        & enrollmentInstructionsPID=$!

    read -r -u5 dialogPID
    exec 5>&-
}


# detectEnrollment Function
#
# Waits for successful MDM enrollment or times out

function detectEnrollment ()
{
    # Parameter format: none

    # It takes ~6 seconds between clicking Allow and the enrollment status changing
    
    local loop
    local isEnrolled
    local notInPrestage

    for ((loop = 0; loop < 52; loop++)); do
        isEnrolled="$(profiles status -type enrollment | grep -ci "enrollment: Yes")"
        if [[ $isEnrolled -eq 1 ]]; then
        # TESTING
        #if [[ $loop -eq 15 ]]; then
            # Must kill both processes to cancel enrollment instructions dialog
            kill "$dialogPID" > /dev/null 2>&1
            kill "$enrollmentInstructionsPID" > /dev/null 2>&1
            return 0
        elif [[ $notInPrestage -eq 1 ]]; then
            kill "$dialogPID" > /dev/null 2>&1
            kill "$enrollmentInstructionsPID" > /dev/null 2>&1
            exec 4>&-
            return 2
        else
            read -r -t 1 -u4 notInPrestage
        fi
    done
    return 1
}


# waitForEnrollmentResults Function
#
# Waits for enrollment results or a button click

function waitForEnrollmentResults ()
{
    # Parameter format: none

    wait "$enrollmentInstructionsPID" > /dev/null 2>&1

    read -r -t 1 -u6 enrollProblemButtonClicked
    exec 6>&-

    if [[ -n "$enrollProblemButtonClicked" ]] \
    && [[ "$enrollProblemButtonClicked" != "gave up:true" ]]; then
        enrollProblemButtonClicked=${enrollProblemButtonClicked//, gave up:false/}
        # Although assuming NOT enrolled in MDM, double-check just in case
        enrolledInMDM="$(profiles status -type enrollment | grep -ci "enrollment: Yes")"
    else
        wait "$detectEnrollmentPID"
        case $? in
            (0)
                enrolledInMDM=1
                ;;
            (2)
                notInPrestage=1
        esac
    fi
}


# displayEnrollmentResultsUI Function
#
# Displays enrollment results dialogs & exit dialogs
#
# shellcheck disable=2034

function displayEnrollmentResultsUI ()
{
    # Parameter format: none

    # Set startBlock, since last handleOutput use was inside a background process
    # (triggerEnrollmentNotification), where global vars don't update main process
    startBlock=1

    if [[ "$enrolledInMDM" -eq 1 ]]; then

        successfullyEnrolled="Yes"
        buildQueryString logUpdateWebhook successfullyEnrolled

        handleOutput message "Enrollment successful!"

        dialogOutput \
            "\nEnrollment successful!\n\n\n`
            `Closing in 3 seconds...\n" \
            "$iconCheckMark" \
            "" \
            '"Waiting..."' \
            "" \
            "" \
            3

        sleep 0.5  # Fading dialog transition, as the previous 'read' forces 1-sec pause

        if [[ "$mdmIsJamfPro" -eq 1 ]]; then
            dialogOutput \
                "Thanks for enrolling your Mac!\n\n`
                `You can go ahead and close the Profiles window. The enrollment `
                `process will complete in the background over the next 5 minutes.\n\n`
                `After that, you will find a new \\\"$selfServiceAppName\\\" app `
                `in your Applications folder (icon like the one on the left). `
                `You can use it to install any of the available apps - even if `
                `you aren't admin." \
                "$iconSelfService" \
                "note" \
                '"Exit"' \
                &
        else
            dialogOutput \
                "Thanks for enrolling your Mac!\n\n`
                `You can go ahead and close the Profiles window. The enrollment `
                `process will complete in the background over the next 5 minutes.\n\n" \
                "$iconOrganizationLogo" \
                "note" \
                '"Exit"' \
                &
        fi

    else

        successfullyEnrolled="No"
        buildQueryString logUpdateWebhook successfullyEnrolled

        handleOutput message "Enrollment did NOT succeed."

        if [[ "$notInPrestage" -eq 1 ]]; then

            enrollmentError="Computer not in prestage"
            buildQueryString logUpdateWebhook enrollmentError

            handleOutput message "Computer is NOT in prestage!"

            dialogOutput \
                "Looks like this computer has not been added to an MDM profile `
                `on the MDM server.\n\n`
                `Please contact $organizationName IT and let them know, and they'll `
                `be happy to get this fixed for you so you can try enrolling again." \
                "caution" \
                "" \
                '"Exit"' \
                &

        elif [[ -n "$enrollProblemButtonClicked" ]]; then

            if [[ "$enrollProblemButtonClicked" == "gave up:true" ]]; then

                enrollmentError="Enrollment timed out"
                buildQueryString logUpdateWebhook enrollmentError

                handleOutput message "Enrollment timed out."

                dialogOutput \
                    "Looks like enrollment did not complete in the time alloted.\n\n`
                    `If you needed more time to enroll, click \\\"Exit\\\" and `
                    `run this app again.\n\n`
                    `Otherwise, click one of the other two buttons below that `
                    `best describes your scenario.\n" \
                    "caution" \
                    "" \
                    '"Clicked \"Allow\", nothing happened","No notification","Exit"' \
                    "" \
                    "" \
                    "" \
                    "enrollProblemButtonClicked"
            fi

            if [[ "$enrollProblemButtonClicked" \
            =~ 'Clicked "Allow",'( but)?' nothing happened'.? ]]; then

                enrollmentError="Clicked allow, nothing happened"
                buildQueryString logUpdateWebhook enrollmentError

                dialogOutput \
                    "This can sometimes happen if something in the background `
                    `interrupts the enrollment process.\n\n`
                    `Please try closing System Preferences (if open), and run `
                    `this app again." \
                    "caution" \
                    "" \
                    '"Exit"' \
                    &
            fi

            if [[ "$enrollProblemButtonClicked" =~ 'No notification'.? ]]; then

                enrollmentError="No notification"
                buildQueryString logUpdateWebhook enrollmentError

                dialogOutput \
                    "Please try running this app again.\n\n\n`
                    `If you still don't get a DEVICE ENROLLMENT notification, `
                    `contact $organizationName IT and let them know.\n" \
                    "caution" \
                    "" \
                    '"Exit"' \
                    &
            fi

        else
            enrollmentError="Unknown enrollment error"
            buildQueryString logUpdateWebhook enrollmentError

            handleOutput message "Unknown enrollment error!"

            dialogOutput \
                    "Unknown enrollment error.\n\n\n`
                    `Please contact $organizationName IT and let them know.\n" \
                    "stop" \
                    "" \
                    '"Exit"' \
                    &
        fi  
            
    fi
}


# waitForDemotionResults Function
#
# Waits for demotion results if user is standard
#
# shellcheck disable=2034

function waitForDemotionResults ()
{
    # Parameter format: none

    if [[ "$currentUserAccountType" == "Standard" ]]; then
        handleOutput block "Waiting for demotion results..."
        wait "$triggerEnrollmentNotificationPID"
        demotionFailed=$?

        case "$demotionFailed" in
            (0)
                handleOutput message "User was demoted on first attempt."
                ;;
            (1)
                demotionNote="Demoted on second attempt"
                buildQueryString logUpdateWebhook demotionNote
                handleOutput message "User was demoted on second attempt."
                ;;
            (2)
                demotionError="User NOT demoted"
                buildQueryString logUpdateWebhook demotionError
                handleOutput message "User is STILL an admin! \n`
                    `Demotion error logged."
                ;;
        esac
    fi
}


# logAndExit Function
#
# Updates log with enrollment results and exits with appropriate exit code

function logAndExit ()
{
    # Parameter format: none

    # Update log with enrollment results 
    if [[ -n "$logUpdateWebhookURL" ]]; then
        logWebhook logUpdateWebhook; fi

    # Exit with appropriate error code
    if [[ "$enrolledInMDM" -ne 1 ]]; then
        if [[ "$notInPrestage" -eq 1 ]]; then
            exit 7
        elif [[ -n "$enrollProblemButtonClicked" ]]; then
            if [[ "$enrollProblemButtonClicked" == "gave up:true" ]]; then
                exit 8
            else
                exit 9
            fi
        else
            exit 10
        fi
    fi

    if [[ "$demotionFailed" -eq 2 ]]; then
        exit 11; fi

    exit 0
}


# Main Function
#
###############

function main ()
{
    # Parameter format: MDM-Enroll.command (optional:[scriptDirectory])
    #
    # Note: when embedded in a binary via bashapp and executed from within an 
    #       .app bundle, the binary will pass its parent directory as the 
    #       first positional argument to this script (this is already handled 
    #       here - no action required). The parent directory is needed in order
    #       to be able to reference icon files included within the .app bundle.
    #       For this to work, you must use the forked bashapp available at
    #       https://github.com/hey-tommy/bashapp when packaging for deployment.


    # Initialize variables/constants that are needed early
    initializeEarlyVariables "$1"
    
    # Initialize secrets (needed early for $organizationName)
    initializeSecrets

    # Initialize rest of variables/constants
    initializeVariables

    # Verify internet connectivity
    checkInternet

    # Collect logging data
    collectLoggingData

    # Verify that Mac isn't already MDM-enrolled, or if enrolled, isn't supervised
    checkIfAlreadyEnrolled

    # Verify that Mac is running a supported macOS version
    checkMacOSVersion

    # Log admin credentials access & retrieve credentials
    logAndRetrieveCredentials

    # Validate retrieved credentials
    validateCredentials

    # Display intro UI
    displayIntroUI

    # Trigger device enrollment notification (in background process)
    triggerEnrollmentNotification \
    & triggerEnrollmentNotificationPID=$!

    # Display enrollment UI
    displayEnrollmentUI

    # Detect successful enrollment (in background process)
    detectEnrollment \
    & detectEnrollmentPID=$!

    # Wait for enrollment results
    waitForEnrollmentResults

    # Display enrollment results UI
    displayEnrollmentResultsUI

    # Wait for demotion results
    waitForDemotionResults

    # Update log and exit
    logAndExit

}

main "$@"
