resource "aws_lambda_layer_version" "ffmpeg_layer" {
  filename         = "${path.module}/lambda/ffmpeg/ffmpeg-layer.zip"
  layer_name       = "ffmpeg"
  description      = "FFMPEG layer for lambda video processing"
  license_info     = "MIT"
  source_code_hash = filebase64sha256("${path.module}/lambda/ffmpeg/ffmpeg-layer.zip")

  compatible_runtimes = ["python3.12"]

  compatible_architectures = ["x86_64"]
}

resource "aws_lambda_layer_version" "psycopg_layer" {
  filename         = "${path.module}/lambda/psycopg/psycopg-layer.zip"
  layer_name       = "psycopg"
  description      = "Psycopg layer for lambda db usage"
  license_info     = "MIT"
  source_code_hash = filebase64sha256("${path.module}/lambda/psycopg/psycopg-layer.zip")

  compatible_runtimes = ["python3.12"]

  compatible_architectures = ["x86_64"]
}
