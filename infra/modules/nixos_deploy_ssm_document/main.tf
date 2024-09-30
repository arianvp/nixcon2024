resource "aws_ssm_document" "nixos_deploy" {
  name          = "NixOS-Deploy"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy to NixOS"
    parameters = {
      action = {
        type          = "String"
        description   = "Whether to switch or reboot to deploy."
        allowedValues = ["switch", "test", "boot", "reboot", "dry-activate"]
        default       = "switch"
      }
      profile = {
        type    = "String"
        default = "/nix/var/nix/profiles/system"
      }
      installable = {
        type        = "String"
        description = <<-EOF
        The configuration to deploy.
        Either a nix flake attribute or a nix store path.
        When a flake attribute is provided, the flake is evaluated on the
        machine. This might run out of memory on small instances. 
        If a store path is provided, the path is substituted
        from a substituter.
        EOF

      }
      substituters = {
        type        = "String"
        description = "The substituters to use."
        default     = ""
      }
      trustedPublicKeys = {
        type        = "String"
        description = "The key with which to verify the substituters."
        default     = ""
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "deploy"
        inputs = { runCommand = [file("${path.module}/deploy.sh")] }
      }
    ]
  })
}

output "name" {
  value = aws_ssm_document.nixos_deploy.name
}

output "arn" {
  value = aws_ssm_document.nixos_deploy.arn
}
