{ lib, config, ... }:

let
  Image = lib.types.submodule {
    options = {
      Architecture = lib.mkOption {
        type = lib.types.enum [
          "x86_64"
          "arm64"
        ];
        description = "The architecture of the AMI.";
        default = config.nixpkgs.hostPlatform.linuxArch;
      };
      BillingProduct = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = ''
          The billing product codes. Your account must be authorized to specify billing
          product codes.
        '';
      };
      BlockDeviceMapping = lib.mkOption {
        type = lib.types.listOf BlockDeviceMapping;
        default = [
          {
            DeviceName = "/dev/xvda";
            Ebs = {
              VolumeType = "gp3";
              SnapshotId = "@snapshotId@";
            };
          }
        ];
        description = ''
          The block device mapping entries.

          If you specify an Amazon EBS volume using the ID of an Amazon EBS snapshot, you
          can't specify the encryption state of the volume.
        '';
      };
      BootMode = lib.mkOption {
        type = lib.types.enum [
          "legacy-bios"
          "uefi"
          "uefi-preferred"
        ];
        # TODO: What isa good default
        description = ''
          The boot mode of the AMI. A value of uefi-preferred indicates that the AMI
          supports both UEFI and Legacy BIOS.
        '';
      };
      Description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "A description for your AMI.";
      };
      EnaSupport = lib.mkOption {
        type = lib.types.bool;
        description = "Set to true to enable enhanced networking with ENA for the AMI and any instances that you launch from the AMI.";
      };
      ImdsSupport = lib.mkOption {
        type = lib.types.enum [ "v2.0" ];
        description = ''
          Set to v2.0 to indicate that IMDSv2 is specified in the AMI. Instances
          launched from this AMI will have HttpTokens automatically set to
          required so that, by default, the instance requires that IMDSv2 is used
          when requesting instance metadata. In addition, HttpPutResponseHopLimit
          is set to 2. For more information, see Configure the AMI in the Amazon
          EC2 User Guide.
        '';
      };
      Name = lib.mkOption {
        type = lib.types.str;
        description = ''
          A name for your AMI.

          Constraints: 3-128 alphanumeric characters, parentheses (()), square brackets ([]), spaces ( ), periods (.), slashes (/), dashes (-), single quotes ('), at-signs (@), or underscores(_)
        '';
      };
      RootDeviceName = lib.mkOption {
        type = lib.types.str;
        description = "The root device name (e.g., /dev/sda1 or /dev/xvda).";
      };
      SriovNetSupport = lib.mkOption {
        type = lib.types.enum [ "simple" ];
        description = "Specifies whether enhanced networking with SR-IOV is enabled.";
      };
      TagSpecification = lib.mkOption {
        type = lib.types.listOf TagSpecification;
        description = "The tags to apply to the AMI.";
      };
      TpmSupport = lib.mkOption {
        type = lib.types.enum [ "v2.0" ];
        description = "Indicates whether the image supports TPM (trusted platform module).";
      };

      # TODO: this should be a derivation
      UefiData = lib.mkOption {
        type = lib.types.str;
        description = ''
          Base64 representation of the non-volatile UEFI variable store. To retrieve the
          UEFI data, use the GetInstanceUefiData command. You can inspect and modify the
          UEFI data by using the python-uefivars tool on GitHub. For more information, see
          UEFI Secure Boot in the Amazon EC2 User Guide.
        '';
      };
      VirtualizationType = lib.mkOption {
        type = lib.types.enum [ "hvm" ];
        readOnly = true;
        description = "The virtualization type of the image. NixOS only supports \"hvm\".";
      };
    };
  };

  EbsBlockDevice = lib.types.submodule {
    options = {
      DeleteOnTermination = lib.mkOption {
        type = lib.types.bool;
        description = ''
          Indicates whether the EBS volume is deleted on instance termination. For
          more information, see Preserving Amazon EBS volumes on instance
          termination in the Amazon EC2 User Guide.
        '';
      };
      Encrypted = lib.mkOption {
        type = lib.types.bnool;
        description = ''
          Indicates whether the encryption state of an EBS volume is changed
          while being restored from a backing snapshot. The effect of setting
          the encryption state to true depends on the volume origin (new or from
          a snapshot), starting encryption state, ownership, and whether
          encryption by default is enabled. For more information, see Amazon EBS
          encryption in the Amazon EBS User Guide.

          In no case can you remove encryption from an encrypted volume.

          Encrypted volumes can only be attached to instances that support Amazon EBS
          encryption. For more information, see Supported instance types.

          This parameter is not returned by DescribeImageAttribute.

          Whether you can include this parameter, and the allowed values differ
          depending on the type of block device mapping you are creating.

          - If you are creating a block device mapping for a new (empty) volume,
          you can include this parameter, and specify either true for an
          encrypted volume, or false for an unencrypted volume. If you omit this
          parameter, it defaults to false (unencrypted).
          - If you are creating a block device mapping from an existing
          encrypted or unencrypted snapshot, you must omit this parameter. If
          you include this parameter, the request will fail, regardless of the
          value that you specify.
        '';
      };
      Iops = lib.mkOption {
        type = lib.types.int;
        description = ''
          The number of I/O operations per second (IOPS). For gp3, io1, and io2
          volumes, this represents the number of IOPS that are provisioned for
          the volume. For gp2 volumes, this represents the baseline performance
          of the volume and the rate at which the volume accumulates I/O credits
          for bursting.

          The following are the supported values for each volume type:

          - gp3: 3,000 - 16,000 IOPS
          - io1: 100 - 64,000 IOPS
          - io2: 100 - 256,000 IOPS

          For io2 volumes, you can achieve up to 256,000 IOPS on instances built
          on the Nitro System. On other instances, you can achieve performance
          up to 32,000 IOPS.

          This parameter is required for io1 and io2 volumes. The default for
          gp3 volumes is 3,000 IOPS.
        '';
      };
      SnapshotId = lib.mkOption {
        type = lib.types.str;
        description = "The ID of the snapshot";
      };
      Throughput = lib.mkOption {
        type = lib.types.int;
        description = ''
          The throughput that the volume supports, in MiB/s.

          This parameter is valid only for gp3 volumes.

          Valid Range: Minimum value of 125. Maximum value of 1000.
        '';
      };
      VolumeSize = lib.mkOption {
        type = lib.types.int;
        description = ''
          The size of the volume, in GiBs. You must specify either a snapshot ID
          or a volume size. If you specify a snapshot, the default is the
          snapshot size. You can specify a volume size that is equal to or
          larger than the snapshot size.

          The following are the supported sizes for each volume type:

          - gp2 and gp3: 1 - 16,384 GiB
          - io1: 4 - 16,384 GiB
          - io2: 4 - 65,536 GiB
          - st1 and sc1: 125 - 16,384 GiB
          - standard: 1 - 1024 GiB
        '';
      };
      VolumeType = lib.mkOption {
        type = lib.types.enum [
          "standard"
          "io1"
          "io2"
          "gp2"
          "sc1"
          "st1"
          "gp3"
        ];
        description = ''
          The volume type. For more information, see Amazon EBS volume types in the Amazon
          EBS User Guide.
        '';
      };
    };
  };
  BlockDeviceMapping = lib.types.submodule {
    DeviceName = lib.mkOption {
      type = lib.types.str;
      description = ''
        The device name (e.g., /dev/sdh or xvdh).
      '';
    };
    Ebs = lib.mkOption {
      type = EbsBlockDevice;
      description = "Parameters used to automatically set up EBS volumes when the instance is launched.";
    };
    VirtualName = lib.mkOption {
      type = lib.types.str;
      description = ''
        The virtual device name (ephemeralN). Instance store volumes are
        numbered starting from 0. An instance type with 2 available instance
        store volumes can specify mappings for ephemeral0 and ephemeral1. The
        number of available instance store volumes depends on the instance type.
        After you connect to the instance, you must mount the volume.

        NVMe instance store volumes are automatically enumerated and assigned a
        device name. Including them in your block device mapping has no effect.

        Constraints: For M3 instances, you must specify instance store volumes
        in the block device mapping for the instance. When you launch an M3
        instance, we ignore any instance store volumes specified in the block
        device mapping for the AMI.
      '';
    };
  };
  TagSpecification = lib.types.submodule {
    options = {
      ResourceType = lib.mkOption {
        type = lib.types.enum [ "image" ];
        default = "image";
      };
      Tag.Key = lib.mkOption {
        type = lib.types.str;
        description = ''
          The key of the tag.

          Constraints: Tag keys are case-sensitive and accept a maximum of 127
          Unicode characters. May not begin with aws:.
        '';
      };
      Tag.Value = lib.mkOption {
        type = lib.types.str;
        description = ''
          The value of the tag.

          Constraints: Tag values are case-sensitive and accept a maximum of 256
          Unicode characters.
        '';
      };

    };
  };
in

{
  options.ec2 = {
    # https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RegisterImage.html

    Image = lib.mkOption {
      type = Image;
      description = "The image to register.";
    };

  };
}
