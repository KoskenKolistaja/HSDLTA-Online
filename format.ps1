# Get all .gd files recursively in the current directory
$gdFiles = Get-ChildItem -Path "." -Filter "*.gd" -Recurse

# Loop through each .gd file
foreach ($file in $gdFiles) {
  try {
    # Format the file using gdformat.  Adjust the path if needed.
    & "gdformat" $file.FullName  # Or & "C:\path\to\gdformat.exe" $file.FullName if not in PATH

    # Check the exit code.  $LastExitCode is automatically set.
    if ($LastExitCode -ne 0) {
      Write-Error "Error formatting $($file.FullName): Exit code $($LastExitCode)"
    } else {
        Write-Host "Formatted: $($file.FullName)" # Optional: Confirmation message
    }

  } catch {
    Write-Error "An exception occurred: $_"
  }
}

Write-Host "Formatting complete."