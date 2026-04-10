# Description
I want you to debug an issue where tinyxml is not building on the build server.  Please use skills at D:\ai\opencode-common\.opencode\skills to do this.

# Development Loop
1. Kick off the ThirdParty-Packages-vcpkg Preconfigured Packages pipeline for the tinyxml package
2. Monitor it until it is complete or runs into an error
3. If it completes successfully, we are done!
4. If it runs into error, download the logs
5. Parse the downloaded logs to extract errors
6. Analyze the extracted errors to determine what went wrong
7. Make changes to files in this repo to fix it on this branch
8. Push changes, using atomic commits and descriptive messages
9. Start over at step 1