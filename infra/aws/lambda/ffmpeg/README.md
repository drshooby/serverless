# How to Create the FFMPEG ZIP for Your Lambda Layer

### Follow this tutorial:

[Building FFMPEG Layer for a Lambda Function](https://virkud-sarvesh.medium.com/building-ffmpeg-layer-for-a-lambda-function-a206f36d3edc)

> **NOTE:** The tutorial may reference an older version of FFMPEG. Update the version in the commands to work with the latest release.

I'd include the zip in the repo, but it’s about **28 MB**, so it’s better to build it locally following the tutorial above.

Lastly, check `infra/aws/ffmpeg_lambda_layer.tf` to see how to use the file.
