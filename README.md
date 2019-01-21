# DNAQuery

## Pre-requisites

1. You must have internet access. DNAQuery uses the Google Charts library which is only available via the web. If you do not have internet access when you run DNAQuery, charts may not display correctly if at all.
2. Google Chrome must be installed, and chrome.exe must exist in the location %LOCALAPPDATA%\Google\Chrome\Application\chrome.exe
3. Microsoft Excel 2010 or higher must be installed
4. If you are using a language other than English, install the Multilingual User Interface Pack for your version of Office.

## Installation Instructions

1. Make a copy of "env.ps1.example" and rename it to "env.ps1"
2. Edit "env.ps1" and enter your details, and those of the client you are preparing the report for. Make sure the input location for the DNA reports is correctly specified.

## Running DNAQuery

When you have completed the configuration process:

1. Run DNAQuery:
    a. browse to the folder containing the DNA Query tool
    b. right click v2-dnaquery.ps1 and select 'Run with Powershell'
    c. the script will open and run in a new PowerShell instance
    NOTE: do not run the script from within an existing PowerShell instance. SQLite is very finicky with regard to file paths and these can be broken if the script is not run as described.
2. The script may take anywhere from 30 seconds to 60 minutes to complete, depending on the size of the DNA results files.
3. Upon completion, the script will notify the user that the report building process has been completed.

## Known Issues

1. The PDF version of the report does not include the first chart in the Overall Account Health - Compliant And Non-Compliant Accounts. Workaround: open the HTML report and manually print from the browser.
2.
