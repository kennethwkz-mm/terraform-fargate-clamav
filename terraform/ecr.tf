resource "aws_ecr_repository" "image_repository" {
  name = "mmt/clamav_fargate"
}

data "template_file" "repo_policy_file" {
  template = file("./templates/ecr_policy.tpl.json")

  vars = {
    numberOfImages = 5
  }
}

# keep the last 5 images
resource "aws_ecr_lifecycle_policy" "repo_policy" {
  repository = aws_ecr_repository.image_repository.name
  policy     = data.template_file.repo_policy_file.rendered
}
