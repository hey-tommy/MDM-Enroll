# MDM-Enroll v2.4

Triggers a macOS device enrollment prompt and allows a user to easily enroll 
into the MDM.

This tool utilizes Automated Device Enrollment, formerly (and better) known
as DEP (Device Enrollment Progam), to trigger a device enrollment 
notification, which the user can then use to initiate MDM enrollment.
 
Because the tool uses DEP, the user's Mac must be present in Apple Business 
Manager and assigned to an MDM server. And in that MDM, the Mac must also have 
an enrollment settings profile assigned to it (what Jamf Pro calls a PreStage 
Enrollment). If all of these requirements aren't met, enrollment will not be 
possible, and this tool will notify the user accordingly (see 
displayEnrollmentResultsUI for dialog text).

NOTE 1: While this script can run stand-alone during testing, it is intended 
to be launched by end users as a standard macOS app. This can be built using a 
modified fork of bashapp, which also obfuscates the script by encrypting it 
via XOR cipher & embedding it, along with the key, inside an executable binary 
within the .app bundle (fork available at https://github.com/hey-tommy/bashapp)

NOTE 2: For local testing, edit and run Set-EnvVars-Toggle.command to set 
secrets environment variables

WARNING: Be absolutely sure to NOT commit or push this file if you embed your 
secrets inside it (which you should only be doing right prior to deployment)
